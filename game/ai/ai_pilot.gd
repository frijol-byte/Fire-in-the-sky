class_name AIPilot
extends Node
## An AI pilot (GDD 8, architecture 5.3). It is a child of the `Ship` it flies and does exactly what
## `PlayerPilot` does: writes `ship.controls` each physics tick, which the flight, weapon and
## device code read like they read the player's. It never touches velocities, and it gets no aim
## assist: it aims with `Lead.solve` and a little profile-driven error.
##
## A utility selector (`AIUtility`) picks one behavior from what the pilot knows:
## - PURSUE: close the distance, turn round after an overshoot.
## - ATTACK_RUN: fly at the lead point, fire when it lines up, use the secondary weapon.
## - BREAK_OFF: too close (or hurt): peel away sideways to open the range, then come back round.
## - EVADE: dodge sideways on the thrusters with the guns still on the enemy, or, with a chaser behind
##   or a missile coming, jink across the line; sometimes flip with flight assist off to face a chaser.
## - USE_DEVICE: flares, when a missile is steering at the ship, then evade.
## Threats are noticed only after the profile's reaction time. Everything about the ship (speeds,
## turn rates, boost) comes from its `ShipDef`; everything about the pilot from its `AIProfileDef`.
##
## It also keeps clear of rocks: rays ahead along the velocity, and a swerve round whatever they hit.

## The pilot changed behavior.
signal behavior_changed(new_behavior: AIUtility.Behavior)

## The seed of the pilot's dice; each new pilot gets the next one, so a run is repeatable.
const BASE_SEED: int = 9301
## An enemy this close to dead ahead of the pilot, within `SIGHTS_RANGE_M`, has it in its sights.
const SIGHTS_CONE: float = deg_to_rad(10.0)
const SIGHTS_RANGE_M: float = 600.0
## "Under fire" lasts this long after a hit.
const UNDER_FIRE_SECONDS: float = 1.0
## A flip is done when the nose is this close to the target.
const FLIP_DONE_ANGLE: float = deg_to_rad(8.0)
## Within this angle of the missile line a rocket salvo is worth firing, and inside this range.
const ROCKET_CONE: float = deg_to_rad(3.0)
const ROCKET_RANGE_M: float = 380.0
## Below this speed the pilot looks along the nose for rocks instead of along the velocity.
const MIN_SCAN_SPEED: float = 5.0
## Seconds the secondary decision (use it this run or not) is kept.
const SECONDARY_REROLL: float = 4.0
## An attack run holds station at this multiple of the break-off range once it has caught up.
const HOLD_FACTOR: float = 1.1
## Ships that will pass within this multiple of their sizes, inside `COLLISION_HORIZON` seconds, are
## on a collision course.
const CONTACT_MARGIN: float = 2.0
const COLLISION_HORIZON: float = 2.0
## The guns rest when the capacitor is below the first fraction, and fire again above the second.
const FIRE_ENERGY_LOW: float = 0.12
const FIRE_ENERGY_HIGH: float = 0.5
## Seconds the pilot keeps swerving after a rock has left its look-ahead rays.
const AVOID_HOLD: float = 0.6
## Forward throttle while dodging sideways with the enemy ahead.
const EVADE_THROTTLE: float = 0.7
## Least distance of the rock look-ahead rays, in metres.
const MIN_SCAN_REACH: float = 60.0

static var _spawned: int = 0

## Who to fight, set before the pilot enters the tree. Null picks the nearest enemy in sight.
var forced_target: Node3D = null
var profile: AIProfileDef = null
var behavior: AIUtility.Behavior = AIUtility.Behavior.PURSUE
## Seconds the pilot has been in `behavior`.
var behavior_time: float = 0.0
var target: Node3D = null
## What the selector scored on the last tick, by behavior (for the debug overlay and tests).
var last_scores: Dictionary[int, float] = {}
## True while a rock is being steered round.
var avoiding: bool = false

var _ship: Ship = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _retarget_left: float = 0.0
var _seen_missile: float = 0.0
var _seen_lock: float = 0.0
var _since_damage: float = INF
var _aim_error: Vector3 = Vector3.ZERO
var _aim_error_goal: Vector3 = Vector3.ZERO
var _aim_error_left: float = 0.0
var _jink_left: float = 0.0
var _jink_direction: Vector3 = Vector3.UP
var _peel_direction: Vector3 = Vector3.UP
var _flip_left: float = 0.0
var _secondary_wanted: bool = false
var _secondary_reroll_left: float = 0.0
var _missile_manager: MissileManager = null
var _last_heading: Vector3 = Vector3.ZERO
var _hold_fire: bool = false
var _evade_cooldown_left: float = 0.0
var _avoid_heading: Vector3 = Vector3.ZERO
var _avoid_left: float = 0.0


## What a behavior asks of the ship this tick, before the rock check and the stick maths.
class Plan:
	extends RefCounted
	## World direction to point the nose at; zero holds the heading.
	var heading: Vector3 = Vector3.ZERO
	var throttle: float = 0.0
	## Sideways and up/down thrust (x, y), -1..1.
	var strafe: Vector2 = Vector2.ZERO
	var boost: bool = false
	var fa_off: bool = false


func _ready() -> void:
	_ship = get_parent() as Ship
	if profile == null:
		profile = Content.ai_profile(&"standard")
	_rng.seed = BASE_SEED + _spawned
	_spawned += 1
	_secondary_wanted = _rng.randf() < (profile.secondary_use if profile != null else 0.0)
	Events.ship_damaged.connect(_on_ship_damaged)


func _exit_tree() -> void:
	if Events.ship_damaged.is_connected(_on_ship_damaged):
		Events.ship_damaged.disconnect(_on_ship_damaged)


func _physics_process(delta: float) -> void:
	tick(delta)


## Gives the pilot's dice another seed (sims use it to try other fights).
func seed_rolls(seed_value: int) -> void:
	_rng.seed = seed_value
	_secondary_wanted = _rng.randf() < profile.secondary_use


## True when a ship on side `mine` fights one on side `theirs`: hostile and friendly fight each
## other, neutral ships take no side.
static func is_enemy(mine: Targeting.Stance, theirs: Targeting.Stance) -> bool:
	return (
		(mine == Targeting.Stance.HOSTILE and theirs == Targeting.Stance.FRIENDLY)
		or (mine == Targeting.Stance.FRIENDLY and theirs == Targeting.Stance.HOSTILE)
	)


## Decides this tick's controls and writes them to the ship. `_physics_process` calls it; sims and
## unit tests may too.
func tick(delta: float) -> void:
	if _ship == null or profile == null or not _ship.is_inside_tree():
		return
	var controls: ShipControls = ShipControls.new()
	_ship.controls = controls
	if _ship.durability().is_destroyed():
		return
	_since_damage += delta
	_update_dice(delta)
	_update_target(delta)
	var situation: AIUtility.Situation = _observe(delta)
	_choose_behavior(situation, delta)
	var plan: Plan = _plan_for(behavior, situation, delta)
	if behavior == AIUtility.Behavior.USE_DEVICE:
		controls.device = _flares_slot()
	_avoid_rocks(plan, delta)
	_apply(plan, controls, delta)
	_fire(controls, situation)


func _on_ship_damaged(ship: Node, _info: DamageInfo, result: DamageResult) -> void:
	if ship == _ship and result.total() > 0.0:
		_since_damage = 0.0


# --- Looking -----------------------------------------------------------------------------------


func _update_dice(delta: float) -> void:
	_aim_error_left -= delta
	if _aim_error_left <= 0.0:
		_aim_error_left = profile.aim_error_period
		_aim_error_goal = AIMath.random_in_ball(_rng.randf(), _rng.randf(), _rng.randf())
	_aim_error = _aim_error.lerp(
		_aim_error_goal, clampf(delta * 3.0 / profile.aim_error_period, 0.0, 1.0)
	)
	_jink_left -= delta
	_secondary_reroll_left -= delta
	if _secondary_reroll_left <= 0.0:
		_secondary_reroll_left = SECONDARY_REROLL
		_secondary_wanted = _rng.randf() < profile.secondary_use


func _update_target(delta: float) -> void:
	_retarget_left -= delta
	var lost: bool = target != null and not Targeting.Candidate.is_valid_node(target)
	if forced_target != null and is_instance_valid(forced_target):
		target = forced_target if Targeting.Candidate.is_valid_node(forced_target) else null
	elif lost or _retarget_left <= 0.0:
		_retarget_left = profile.retarget_interval
		target = _nearest_enemy(target)
	if target != null and _ship.targeting().target != target:
		_ship.targeting().select(target)
	elif target == null and _ship.targeting().target != null:
		_ship.targeting().clear()


## The nearest enemy in sight. `current` stays unless the new one is at least a fifth closer.
func _nearest_enemy(current: Node3D) -> Node3D:
	var origin: Vector3 = _ship.global_position
	var best: Node3D = null
	var best_distance: float = profile.sight_range_m
	for node: Node in get_tree().get_nodes_in_group(Targeting.GROUP):
		if node == _ship or not Targeting.Candidate.is_valid_node(node):
			continue
		if not is_enemy(_ship.stance, node.call(&"target_stance") as Targeting.Stance):
			continue
		var distance: float = origin.distance_to((node as Node3D).global_position)
		if distance < best_distance:
			best = node as Node3D
			best_distance = distance
	if best != null and current != null and Targeting.Candidate.is_valid_node(current):
		var current_distance: float = origin.distance_to(current.global_position)
		if best_distance > current_distance * 0.8:
			return current
	return best


## Gathers what the selector needs. Threats count only after the reaction time.
func _observe(delta: float) -> AIUtility.Situation:
	var s: AIUtility.Situation = AIUtility.Situation.new()
	var def: ShipDef = _ship.def
	s.break_range = AIMath.break_off_range(profile, def)
	s.engage_range = maxf(profile.preferred_range_m, s.break_range * 2.0)
	s.aggression = profile.aggression
	s.shield_fraction = _ship.durability().shield_fraction()
	s.flares_ready = profile.use_flares and _flares_slot() > 0
	var incoming: bool = not _incoming_missiles().is_empty()
	_seen_missile = AIMath.seen_time(_seen_missile, incoming, delta)
	s.incoming_missile = AIMath.has_reacted(_seen_missile, profile.reaction_time)
	_seen_lock = AIMath.seen_time(_seen_lock, _enemy_locking(), delta)
	s.locked_on = AIMath.has_reacted(_seen_lock, profile.reaction_time)
	# Gunfire only makes the pilot dodge when it is not still catching its breath from the last dodge.
	var may_dodge: bool = _evade_cooldown_left <= 0.0
	s.under_fire = _since_damage < UNDER_FIRE_SECONDS and may_dodge
	if target == null:
		return s
	s.has_target = true
	var target_durability: Durability = ProjectileManager.durability_of(target)
	if target_durability != null:
		s.target_hull_fraction = target_durability.hull_fraction()
	var offset: Vector3 = target.global_position - _ship.global_position
	s.distance = offset.length()
	s.angle = AIMath.angle_off_nose(_ship.global_basis, offset)
	var relative: Vector3 = _velocity_of(target) - _ship.linear_velocity
	s.closing = -relative.dot(offset.normalized()) if s.distance > 0.001 else 0.0
	s.in_sights = _in_sights(offset) and may_dodge
	var contact: float = (_ship.target_radius() + _radius_of(target)) * CONTACT_MARGIN
	s.collision_course = AIMath.is_collision_course(offset, relative, contact, COLLISION_HORIZON)
	return s


func _choose_behavior(situation: AIUtility.Situation, delta: float) -> void:
	behavior_time += delta
	_evade_cooldown_left = maxf(_evade_cooldown_left - delta, 0.0)
	last_scores = AIUtility.scores(situation)
	var chosen: AIUtility.Behavior = AIUtility.select(
		last_scores, behavior, behavior_time, _min_time(behavior)
	)
	if chosen == behavior:
		return
	if behavior == AIUtility.Behavior.EVADE:
		_evade_cooldown_left = profile.evade_cooldown
	behavior = chosen
	behavior_time = 0.0
	_on_enter(chosen, situation)
	behavior_changed.emit(chosen)
	Events.ai_behavior_changed.emit(_ship, chosen)


func _min_time(of: AIUtility.Behavior) -> float:
	match of:
		AIUtility.Behavior.BREAK_OFF:
			return profile.break_off_seconds
		AIUtility.Behavior.EVADE:
			return profile.evade_seconds
		AIUtility.Behavior.USE_DEVICE:
			return 0.0
	return profile.min_behavior_seconds


func _on_enter(entered: AIUtility.Behavior, situation: AIUtility.Situation) -> void:
	match entered:
		AIUtility.Behavior.BREAK_OFF:
			_peel_direction = _peel_away(situation)
		AIUtility.Behavior.EVADE:
			_jink_left = 0.0
			var behind: bool = situation.has_target and situation.angle > AIMath.BEHIND_ANGLE
			var chasing: bool = behind and not situation.incoming_missile
			_flip_left = (
				profile.flip_seconds if chasing and _rng.randf() < profile.flip_chance else 0.0
			)


## Homing missiles steering at this ship.
func _incoming_missiles() -> Array[Missile]:
	if _missile_manager == null or not is_instance_valid(_missile_manager):
		_missile_manager = MissileManager.for_node(_ship)
	if _missile_manager == null:
		return []
	return _missile_manager.incoming_for(_ship)


## True when an enemy ship is building or holding a missile lock on this one.
func _enemy_locking() -> bool:
	for node: Node in get_tree().get_nodes_in_group(Targeting.GROUP):
		var other: Ship = node as Ship
		if other == null or other == _ship or not is_enemy(_ship.stance, other.stance):
			continue
		var secondary: SecondarySystem = other.secondaries()
		if secondary.lock_target == _ship and secondary.lock.state != MissileLock.State.IDLE:
			return true
	return false


func _in_sights(offset: Vector3) -> bool:
	var enemy: Ship = target as Ship
	if enemy == null or offset.length() > SIGHTS_RANGE_M:
		return false
	return AIMath.angle_off_nose(enemy.global_basis, -offset) <= SIGHTS_CONE


## The device slot (1 to 3) of a ready flares device, or 0.
func _flares_slot() -> int:
	var devices: DeviceSystem = _ship.devices()
	for slot: int in range(1, devices.count() + 1):
		var def: DeviceDef = devices.device_in(slot)
		if def != null and def.effect == DeviceDef.Effect.FLARES and devices.is_ready(slot):
			return slot
	return 0


# --- Steering ----------------------------------------------------------------------------------


func _plan_for(which: AIUtility.Behavior, situation: AIUtility.Situation, delta: float) -> Plan:
	var plan: Plan = Plan.new()
	if not situation.has_target and not situation.incoming_missile:
		return plan
	match which:
		AIUtility.Behavior.PURSUE:
			_plan_pursue(plan, situation)
		AIUtility.Behavior.ATTACK_RUN:
			_plan_attack(plan, situation)
		AIUtility.Behavior.BREAK_OFF:
			_plan_break_off(plan)
		AIUtility.Behavior.EVADE, AIUtility.Behavior.USE_DEVICE:
			_plan_evade(plan, situation, delta)
	return plan


func _plan_pursue(plan: Plan, s: AIUtility.Situation) -> void:
	plan.heading = _aim_point() - _ship.global_position
	plan.throttle = 1.0
	plan.boost = s.distance > s.engage_range * 1.5 and s.angle < deg_to_rad(30.0)
	_chase_boost(plan, s)


func _plan_attack(plan: Plan, s: AIUtility.Situation) -> void:
	plan.heading = _aim_point() - _ship.global_position
	var line: Vector3 = (target.global_position - _ship.global_position).normalized()
	var along: float = _velocity_of(target).dot(line)
	plan.throttle = AIMath.matched_throttle(
		s.distance, s.break_range * HOLD_FACTOR, along, _ship.def.max_speed
	)
	_chase_boost(plan, s)


## Boosts to catch a target that is pulling away faster than the ship's own top speed.
func _chase_boost(plan: Plan, s: AIUtility.Situation) -> void:
	var line: Vector3 = (target.global_position - _ship.global_position).normalized()
	var runs_away: bool = _velocity_of(target).dot(line) > _ship.def.max_speed * 0.8
	if runs_away and s.distance > s.break_range * HOLD_FACTOR * 2.0 and s.angle < deg_to_rad(20.0):
		plan.boost = true


func _plan_break_off(plan: Plan) -> void:
	plan.heading = _peel_direction
	plan.throttle = 1.0
	plan.boost = true


func _plan_evade(plan: Plan, s: AIUtility.Situation, delta: float) -> void:
	if _flip_left > 0.0 and target != null:
		_flip_left -= delta
		var to_target: Vector3 = _aim_point() - _ship.global_position
		if s.has_target and s.angle > FLIP_DONE_ANGLE:
			plan.heading = to_target
			plan.fa_off = true
			return
		_flip_left = 0.0
	var threat: Vector3 = _threat_point()
	var line: Vector3 = threat - _ship.global_position
	if _jink_left <= 0.0:
		_jink_left = profile.jink_period
		_jink_direction = AIMath.jink_direction(
			line, _ship.global_basis.orthonormalized().y, _rng.randf() * TAU
		)
	var local: Vector3 = AIMath.to_local(_ship.global_basis, _jink_direction)
	plan.strafe = Vector2(local.x, local.y)
	if s.has_target and s.angle < AIMath.BEHIND_ANGLE and not s.incoming_missile:
		# The enemy is ahead: dodge sideways with the thrusters and keep the guns on it.
		plan.heading = _aim_point() - _ship.global_position
		plan.throttle = EVADE_THROTTLE
		return
	plan.heading = (_jink_direction * 0.9 - line.normalized() * 0.35).normalized()
	plan.throttle = 1.0
	# Outrunning a missile is worth the energy; outrunning a gun (which ends the fight) is not.
	plan.boost = s.incoming_missile


## Where the danger comes from: the nearest missile steering at the ship, else the target.
func _threat_point() -> Vector3:
	var best: Vector3 = target.global_position if target != null else _ship.global_position
	var best_distance: float = INF
	for round_record: Missile in _incoming_missiles():
		var distance: float = round_record.position.distance_to(_ship.global_position)
		if distance < best_distance:
			best = round_record.position
			best_distance = distance
	if best.is_equal_approx(_ship.global_position):
		best = _ship.global_position - _ship.global_basis.orthonormalized().z * 100.0
	return best


## A direction that opens the range sideways: across the line to the target, rolled at random, with
## a little away from it. A hurt ship (low shield) runs straight away instead.
func _peel_away(s: AIUtility.Situation) -> Vector3:
	var origin: Vector3 = _ship.global_position
	var line: Vector3 = target.global_position - origin if target != null else -_ship.global_basis.z
	var away: Vector3 = -line.normalized()
	if s.shield_fraction < 0.3 and s.distance > s.break_range:
		return away
	var across: Vector3 = AIMath.jink_direction(
		line, _ship.global_basis.orthonormalized().y, _rng.randf() * TAU
	)
	return (across + away * 0.4).normalized()


## Where to point the nose: the lead point of the primary weapon on the target, plus the pilot's
## aim error.
func _aim_point() -> Vector3:
	if target == null:
		return _ship.global_position - _ship.global_basis.orthonormalized().z * 100.0
	var weapon: WeaponDef = _ship.weapons().weapon_for(WeaponSystem.GROUP_PRIMARY)
	var speed: float = weapon.projectile_speed if weapon != null else 0.0
	var lead: Vector3 = Lead.solve(
		_ship.global_position,
		_ship.linear_velocity,
		target.global_position,
		_velocity_of(target),
		speed
	)
	return AIMath.aim_point(_ship.global_position, lead, _aim_error, profile.aim_error_deg)


## Checks the way ahead for rocks and, when one is in the way, swerves round it: the plan's heading
## becomes the avoid heading, flight assist comes back on and boost goes off.
func _avoid_rocks(plan: Plan, delta: float) -> void:
	avoiding = false
	var basis: Basis = _ship.global_basis.orthonormalized()
	var speed: float = _ship.linear_velocity.length()
	var travel: Vector3 = _ship.linear_velocity / speed if speed > MIN_SCAN_SPEED else -basis.z
	var origin: Vector3 = _ship.global_position
	var reach: float = maxf(speed * profile.rock_look_ahead, MIN_SCAN_REACH)
	var radius: float = _ship.target_radius() + profile.rock_margin_m
	var space: PhysicsDirectSpaceState3D = _ship.get_world_3d().direct_space_state
	var nearest: Dictionary = {}
	var nearest_along: float = INF
	for offset: Vector3 in [
		Vector3.ZERO, basis.x * radius, -basis.x * radius, basis.y * radius, -basis.y * radius
	]:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin + offset,
			origin + offset + travel * reach,
			PhysicsLayers.WORLD,
			[_ship.get_rid()]
		)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var along: float = ((hit["position"] as Vector3) - origin).dot(travel)
		if along < nearest_along:
			nearest = hit
			nearest_along = along
	if nearest.is_empty():
		# Keep swerving for a moment after the rock is out of the rays, or the nose swings straight
		# back to the target and grazes it.
		if _avoid_left > 0.0:
			_avoid_left -= delta
			_apply_avoidance(plan, _avoid_heading)
		return
	var collider: Node3D = nearest["collider"] as Node3D
	var centre: Vector3 = collider.global_position if collider != null else nearest["position"]
	var hit_point: Vector3 = nearest["position"]
	_avoid_heading = AIMath.avoid_heading(
		origin, travel, centre, maxf(centre.distance_to(hit_point), 1.0), radius, basis.y
	)
	_avoid_left = AVOID_HOLD
	_apply_avoidance(plan, _avoid_heading)


func _apply_avoidance(plan: Plan, heading: Vector3) -> void:
	avoiding = true
	plan.heading = heading
	plan.fa_off = false
	plan.boost = false
	plan.throttle = maxf(plan.throttle, 0.6)
	plan.strafe = Vector2.ZERO


## Turns a plan into the stick values: the nose towards the heading, throttle, strafe, boost.
func _apply(plan: Plan, controls: ShipControls, delta: float) -> void:
	var def: ShipDef = _ship.def
	if plan.heading.length_squared() > 0.0001:
		var rates: Vector3 = def.max_angular_rate_rad()
		var local: Vector3 = AIMath.to_local(_ship.global_basis, plan.heading)
		var direction: Vector3 = plan.heading.normalized()
		var swing: Vector2 = AIMath.swing_rate(_last_heading, direction, _ship.global_basis, delta)
		var turn: Vector2 = AIMath.turn_command(
			local, Vector2(rates.x, rates.y), profile.turn_gain, swing
		)
		controls.rotate = Vector3(turn.x, turn.y, 0.0)
		_last_heading = direction
	else:
		_last_heading = Vector3.ZERO
	controls.thrust = Vector3(plan.strafe.x, plan.strafe.y, plan.throttle)
	controls.boost = plan.boost and _can_boost()
	controls.fa_off = plan.fa_off


func _can_boost() -> bool:
	if not profile.use_boost:
		return false
	var power: PowerSystem = _ship.power()
	return power.energy > power.capacity * profile.boost_reserve


# --- Shooting ----------------------------------------------------------------------------------


func _fire(controls: ShipControls, s: AIUtility.Situation) -> void:
	if target == null or avoiding or behavior == AIUtility.Behavior.USE_DEVICE:
		return
	var weapon: WeaponDef = _ship.weapons().weapon_for(WeaponSystem.GROUP_PRIMARY)
	if weapon == null:
		return
	var aim: Vector3 = _aim_point() - _ship.global_position
	var angle: float = AIMath.angle_off_nose(_ship.global_basis, aim)
	var cone: float = AIMath.fire_cone(profile.fire_cone_deg, _radius_of(target), s.distance)
	var reach: float = minf(profile.preferred_range_m, weapon.range_m * 0.95)
	controls.fire_primary = AIMath.should_fire(angle, s.distance, cone, reach)
	if weapon.energy_cost > 0.0:
		var power: PowerSystem = _ship.power()
		_hold_fire = AIMath.hold_fire(
			power.energy / power.capacity, _hold_fire, FIRE_ENERGY_LOW, FIRE_ENERGY_HIGH
		)
		controls.fire_primary = controls.fire_primary and not _hold_fire
	_use_secondary(controls, s, angle)


## Holds the trigger to lock and launch a missile, or presses it to fire rockets, on attack runs.
func _use_secondary(controls: ShipControls, s: AIUtility.Situation, angle: float) -> void:
	var secondary: SecondarySystem = _ship.secondaries()
	if secondary.def == null or secondary.ammo <= 0 or not _secondary_wanted:
		return
	if behavior != AIUtility.Behavior.ATTACK_RUN and behavior != AIUtility.Behavior.PURSUE:
		return
	if secondary.def.is_homing():
		if not secondary.can_lock_on(target):
			return
		# Hold while the lock builds; let go the tick it is full, which launches.
		controls.fire_secondary = not secondary.lock.is_locked()
	elif s.distance <= ROCKET_RANGE_M and angle <= ROCKET_CONE:
		controls.fire_secondary = true


static func _velocity_of(node: Node) -> Vector3:
	return (
		node.call(&"target_velocity") as Vector3
		if node.has_method(&"target_velocity")
		else Vector3.ZERO
	)


static func _radius_of(node: Node) -> float:
	return node.call(&"target_radius") as float if node.has_method(&"target_radius") else 0.0
