class_name MissileManager
extends Node3D
## Flies every missile, rocket and flare in the scene. Rounds are pooled `Missile` records moved
## each physics tick: a homing missile steers with proportional navigation (`MissileGuidance`) at
## its target or at a flare that fooled it, a rocket flies straight, and both are swept through the
## physics world with a `SweepCaster` so a fast round cannot skip past a target. A round blows up on
## contact, or - for a missile with a proximity fuse - when its path passes close enough to its
## target; the blast hurts everything around it through `Durability.apply`, like any other hit.
##
## `SecondarySystem` and `DeviceSystem` find the manager of their scene through the `GROUP` group.
## Each scene that has secondaries adds one; it adds its own `CombatFx`.
##
## Flares: `deploy_flares` throws a handful of them and rolls once for every missile that is
## tracking the ship and close enough; a missile that fails the roll is fooled and steers at one
## of the flares. When the flare burns out (or the target is gone) the missile loses guidance and
## flies on straight until it self-destructs. The rolls use a seeded generator (`seed_rolls`) so
## sims are repeatable.
##
## The pools never grow. When one is full, the oldest entry is reused.

## A round's blast hurt `collider`: `info` is the damage handed to its `Durability` and `result`
## what it did.
signal damaged(missile: Missile, collider: Object, info: DamageInfo, result: DamageResult)
## A round was launched.
signal launched(missile: Missile)
## A round blew up at `point`. `harmless` rounds (self-destructed, or fooled by a flare) did no damage.
signal exploded(missile: Missile, point: Vector3, harmless: bool)
## A missile's seeker was fooled by `flare`.
signal decoyed(missile: Missile, flare: Flare)

## Group every manager joins, for `for_node`.
const GROUP: StringName = &"missile_manager"
const DEFAULT_CAPACITY: int = 48
const DEFAULT_FLARE_CAPACITY: int = 64
## Fixed seed of the decoy rolls.
const ROLL_SEED: int = 31337
## Extra streak instances per missile: the bright body and the long faint exhaust.
const STREAKS_PER_MISSILE: int = 2
## Exhaust length and width compared with the body streak.
const EXHAUST_LENGTH_FACTOR: float = 2.6
const EXHAUST_WIDTH_FACTOR: float = 0.5
const EXHAUST_COLOR_FACTOR: float = 0.45
## Flares leave sideways and a little backwards: this fraction of the eject speed along the ship's tail.
const FLARE_BACKWARD_FRACTION: float = 0.15
## A round that self-destructs or goes off at a flare makes a blast this much of its radius.
const HARMLESS_BLAST_FACTOR: float = 0.3

var capacity: int = DEFAULT_CAPACITY
var flare_capacity: int = DEFAULT_FLARE_CAPACITY
## Rounds launched over the manager's life (the pool reuse test counts these).
var launched_total: int = 0
var fx: CombatFx = null

var _pool: Array[Missile] = []
var _flares: Array[Flare] = []
var _free: PackedInt32Array = []
var _active_count: int = 0
var _serial: int = 0
var _flare_serial: int = 0
var _next_flare: int = 0
var _caster: SweepCaster = SweepCaster.new(PhysicsLayers.PROJECTILE_MASK)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _streaks: MultiMeshInstance3D = null
var _multimesh: MultiMesh = null


## The manager of the scene `node` is in, or null.
static func for_node(node: Node) -> MissileManager:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as MissileManager


func _ready() -> void:
	add_to_group(GROUP)
	_rng.seed = ROLL_SEED
	for index: int in capacity:
		var round_record: Missile = Missile.new()
		round_record.index = index
		_pool.append(round_record)
	for index: int in range(capacity - 1, -1, -1):
		_free.append(index)
	for index: int in flare_capacity:
		var flare: Flare = Flare.new()
		flare.index = index
		_flares.append(flare)
	_streaks = ProjectileManager.make_streaks(capacity * STREAKS_PER_MISSILE + flare_capacity)
	_multimesh = _streaks.multimesh
	add_child(_streaks)
	if fx == null:
		fx = CombatFx.new()
		fx.name = "CombatFx"
		add_child(fx)


func _physics_process(delta: float) -> void:
	step(delta)


func _process(_delta: float) -> void:
	draw_streaks(Engine.get_physics_interpolation_fraction())


## Seeds the decoy rolls, for repeatable sims.
func seed_rolls(seed_value: int) -> void:
	_rng.seed = seed_value


## Number of rounds in flight.
func active_count() -> int:
	return _active_count


## Size of the missile pool (constant for the manager's life).
func pool_size() -> int:
	return _pool.size()


## The active rounds, oldest first (a copy, for tests and tools).
func active_missiles() -> Array[Missile]:
	var result: Array[Missile] = []
	for round_record: Missile in _pool:
		if round_record.active:
			result.append(round_record)
	result.sort_custom(func(a: Missile, b: Missile) -> bool: return a.serial < b.serial)
	return result


## The flares burning now.
func active_flares() -> Array[Flare]:
	var result: Array[Flare] = []
	for flare: Flare in _flares:
		if flare.active:
			result.append(flare)
	return result


## The homing missiles steering at `ship` itself right now (a missile fooled by a flare no longer
## counts). The incoming-missile warning and the AI's flare decision read this.
func incoming_for(ship: Node) -> Array[Missile]:
	var result: Array[Missile] = []
	for round_record: Missile in _pool:
		if round_record.is_tracking(ship):
			result.append(round_record)
	return result


## Launches a round of `def` from `origin` with `start_velocity`. A `target` makes a homing
## missile of it (a rocket ignores it). A full pool gives up its oldest round.
func launch(
	def: SecondaryDef,
	shooter: Node,
	origin: Vector3,
	start_velocity: Vector3,
	target: Node3D = null
) -> Missile:
	var slot: Missile = _take_slot()
	_serial += 1
	launched_total += 1
	slot.launch(def, shooter, origin, start_velocity, target, _serial)
	_active_count += 1
	launched.emit(slot)
	return slot


## Throws `def.flare_count` flares from `source` and rolls once for each missile that is tracking
## it and within `def.decoy_range_m`: with chance `def.decoy_chance` the missile chases one of the
## flares. Returns how many missiles were fooled.
func deploy_flares(source: Node3D, def: DeviceDef) -> int:
	var basis: Basis = source.global_basis.orthonormalized()
	var drift: Vector3 = _velocity_of(source) * 0.6
	var thrown: Array[Flare] = []
	for index: int in def.flare_count:
		var angle: float = TAU * (float(index) + _rng.randf()) / float(def.flare_count)
		var out: Vector3 = (basis.x * cos(angle) + basis.y * sin(angle)) * def.eject_speed
		var velocity: Vector3 = drift + out + basis.z * def.eject_speed * FLARE_BACKWARD_FRACTION
		var flare: Flare = _take_flare()
		_flare_serial += 1
		flare.start(def, source, source.global_position + basis.z * 4.0, velocity, _flare_serial)
		thrown.append(flare)
	if fx != null:
		fx.flash(source.global_position + basis.z * 4.0, def.color, def.flash_size, 0.18)
		if not def.use_sfx.is_empty():
			fx.play(fx.load_sound(def.use_sfx), source.global_position, def.use_sfx_db)
	var fooled: int = 0
	for round_record: Missile in _pool:
		if not round_record.is_tracking(source):
			continue
		if round_record.position.distance_to(source.global_position) > def.decoy_range_m:
			continue
		if _rng.randf() >= def.decoy_chance:
			continue
		var chosen: Flare = thrown[_rng.randi() % thrown.size()]
		round_record.decoy = chosen
		round_record.decoy_serial = chosen.serial
		fooled += 1
		decoyed.emit(round_record, chosen)
	return fooled


## Moves every flare and round by `delta` seconds: guidance, a sweep along the path, the fuse,
## and the blast. `_physics_process` calls it; sims may too.
func step(delta: float) -> void:
	for flare: Flare in _flares:
		if flare.active:
			_advance_flare(flare, delta)
	for round_record: Missile in _pool:
		if round_record.active:
			_advance(round_record, delta)


## Writes the streaks of the active rounds and flares, drawn `fraction` of the way between their
## last two physics positions. `_process` calls it every frame.
func draw_streaks(fraction: float) -> void:
	if _multimesh == null:
		return
	var drawn: int = 0
	for round_record: Missile in _pool:
		if not round_record.active:
			continue
		var def: SecondaryDef = round_record.def
		var direction: Vector3 = round_record.heading()
		var head: Vector3 = round_record.drawn_position(fraction)
		_multimesh.set_instance_transform(
			drawn, ProjectileManager.streak_at(head, direction, def.streak_length, def.streak_width)
		)
		_multimesh.set_instance_color(drawn, def.color)
		_multimesh.set_instance_transform(
			drawn + 1,
			ProjectileManager.streak_at(
				head,
				direction,
				def.streak_length * EXHAUST_LENGTH_FACTOR,
				def.streak_width * EXHAUST_WIDTH_FACTOR
			)
		)
		_multimesh.set_instance_color(drawn + 1, def.color * EXHAUST_COLOR_FACTOR)
		drawn += STREAKS_PER_MISSILE
	for flare: Flare in _flares:
		if not flare.active:
			continue
		var heading: Vector3 = flare.velocity.normalized()
		if heading.length_squared() < 0.5:
			heading = Vector3.UP
		var flicker: float = 0.75 + 0.25 * sin(flare.left * 37.0 + float(flare.index))
		var color: Color = flare.def.color * (flare.brightness() * flicker)
		color.a = 1.0
		_multimesh.set_instance_transform(
			drawn,
			ProjectileManager.streak_at(
				flare.drawn_position(fraction),
				heading,
				flare.def.streak_length,
				flare.def.streak_width
			)
		)
		_multimesh.set_instance_color(drawn, color)
		drawn += 1
	_multimesh.visible_instance_count = drawn


## What `source` is moving at, for anything that reports a velocity.
static func _velocity_of(source: Node) -> Vector3:
	if source.has_method(&"target_velocity"):
		return source.call(&"target_velocity") as Vector3
	return Vector3.ZERO


func _take_slot() -> Missile:
	if not _free.is_empty():
		var index: int = _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
		return _pool[index]
	var oldest: Missile = null
	for round_record: Missile in _pool:
		if oldest == null or round_record.serial < oldest.serial:
			oldest = round_record
	_active_count -= 1
	oldest.retire()
	return oldest


func _take_flare() -> Flare:
	for step_index: int in _flares.size():
		var flare: Flare = _flares[(_next_flare + step_index) % _flares.size()]
		if not flare.active:
			_next_flare = (flare.index + 1) % _flares.size()
			return flare
	# All burning: reuse the next slot round the ring (the oldest).
	var oldest: Flare = _flares[_next_flare]
	_next_flare = (_next_flare + 1) % _flares.size()
	return oldest


func _retire(round_record: Missile) -> void:
	round_record.retire()
	_free.append(round_record.index)
	_active_count -= 1


func _advance_flare(flare: Flare, delta: float) -> void:
	flare.previous = flare.position
	flare.position += flare.velocity * delta
	flare.left -= delta
	if flare.left <= 0.0:
		flare.retire()


## What the round steers at this tick: the decoy flare if it was fooled, else the target. Sets
## `guided` false when there is nothing left to follow. Returns {position, velocity} or {}.
func _aim_of(round_record: Missile) -> Dictionary:
	if not round_record.guided:
		return {}
	if round_record.decoy != null:
		var flare: Flare = round_record.decoy
		if flare.active and flare.serial == round_record.decoy_serial:
			return {"position": flare.position, "velocity": flare.velocity}
		round_record.guided = false
		return {}
	var target: Node3D = round_record.target
	if not is_instance_valid(target) or not target.is_inside_tree() or _is_dead(target):
		round_record.guided = false
		return {}
	return {"position": target.global_position, "velocity": _velocity_of(target)}


static func _is_dead(node: Node) -> bool:
	var durability: Durability = ProjectileManager.durability_of(node)
	return durability != null and durability.is_destroyed()


func _advance(round_record: Missile, delta: float) -> void:
	var def: SecondaryDef = round_record.def
	round_record.previous = round_record.position
	round_record.age += delta
	if round_record.age >= def.lifetime:
		_blow_up(round_record, round_record.position, true)
		return
	var aim: Dictionary = _aim_of(round_record)
	var heading: Vector3 = round_record.heading()
	if not aim.is_empty():
		var to_aim: Vector3 = (aim["position"] as Vector3) - round_record.position
		if not MissileGuidance.in_seeker_view(heading, to_aim, def.seeker_cone_rad()):
			# The target is behind the seeker: it has been passed, or has dodged out of view.
			round_record.guided = false
			aim = {}
	if not aim.is_empty() and round_record.age >= def.ignite_delay:
		heading = MissileGuidance.steer(
			heading,
			round_record.position,
			round_record.velocity,
			aim["position"] as Vector3,
			aim["velocity"] as Vector3,
			def.nav_gain,
			def.turn_rate_rad(),
			delta
		)
	var speed: float = MissileGuidance.next_speed(
		round_record.speed(), def.acceleration, def.max_speed, delta
	)
	round_record.velocity = heading * speed
	var motion: Vector3 = round_record.velocity * delta
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var contact: Dictionary = _caster.cast(
		space, round_record.position, motion, def.radius, round_record.exclude
	)
	var contact_fraction: float = INF
	if not contact.is_empty():
		contact_fraction = (
			(contact["position"] as Vector3).distance_to(round_record.position) / motion.length()
		)
	var fuse_fraction: float = _fuse_fraction(round_record, aim, motion, delta)
	if fuse_fraction < contact_fraction:
		var point: Vector3 = round_record.position + motion * fuse_fraction
		round_record.position = point
		# A flare is not a ship: the missile goes off at it harmlessly.
		_blow_up(round_record, point, round_record.decoy != null)
		return
	if not contact.is_empty():
		round_record.position = contact["position"] as Vector3
		_blow_up(round_record, round_record.position, false)
		return
	round_record.position += motion
	round_record.travelled += motion.length()


## The fraction (0..1) of this tick's motion at which the proximity fuse fires, or INF.
func _fuse_fraction(round_record: Missile, aim: Dictionary, motion: Vector3, delta: float) -> float:
	var def: SecondaryDef = round_record.def
	if aim.is_empty() or def.fuse_radius_m <= 0.0 or round_record.travelled < def.arm_distance_m:
		return INF
	var target_pos: Vector3 = aim["position"] as Vector3
	var target_motion: Vector3 = (aim["velocity"] as Vector3) * delta
	var fraction: float = MissileGuidance.closest_fraction(
		round_record.position, motion, target_pos, target_motion
	)
	var gap: float = MissileGuidance.separation_at(
		round_record.position, motion, target_pos, target_motion, fraction
	)
	return fraction if gap <= def.fuse_radius_m else INF


## Blows the round up at `point`. A `harmless` blast only looks and sounds like one.
func _blow_up(round_record: Missile, point: Vector3, harmless: bool) -> void:
	var def: SecondaryDef = round_record.def
	if not harmless:
		_splash(round_record, point)
	if fx != null:
		var size: float = def.splash_radius_m * (HARMLESS_BLAST_FACTOR if harmless else 1.0)
		fx.explosion(point, size, def.blast_color)
	exploded.emit(round_record, point, harmless)
	_retire(round_record)


## Hurts everything with a `Durability` within the blast radius, except the ship that fired.
func _splash(round_record: Missile, point: Vector3) -> void:
	var def: SecondaryDef = round_record.def
	var source: Node = round_record.shooter if is_instance_valid(round_record.shooter) else null
	for node: Node in get_tree().get_nodes_in_group(Targeting.GROUP):
		if node == source or not node is Node3D:
			continue
		var durability: Durability = ProjectileManager.durability_of(node)
		if durability == null or durability.is_destroyed():
			continue
		var body: Node3D = node as Node3D
		var radius: float = body.call(&"target_radius") as float
		var from_centre: float = point.distance_to(body.global_position)
		var amount: float = MissileGuidance.splash_amount(
			def.damage,
			def.splash_radius_m,
			def.splash_edge_fraction,
			maxf(from_centre - radius, 0.0)
		)
		if amount <= 0.0:
			continue
		var toward: Vector3 = (point - body.global_position).normalized()
		var info: DamageInfo = DamageInfo.make(
			amount, def.damage_type, source, body.global_position + toward * radius
		)
		damaged.emit(round_record, node, info, durability.apply(info))
