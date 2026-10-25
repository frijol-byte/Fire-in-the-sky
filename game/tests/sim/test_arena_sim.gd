extends GdUnitTestSuite
## The flight arena's physical parts with a real `Ship`: bouncing off rocks (including the pool of
## solid rocks that follows the ship), flying through ring gates, and the whole arena scene
## running for a while.

const FLIGHT_TEST: ArenaDef = preload("res://data/arenas/flight_test.tres")
const GATE_SCENE: PackedScene = preload("res://world/props/ring_gate.tscn")
const ARENA_SCENE: PackedScene = preload("res://world/arenas/flight_test.tscn")
## A little above the Kestrel's boost top speed (320 m/s).
const FLIGHT_TEST_BOOST_TOP: float = 330.0

var _nodes: Array[Node] = []


func before_test() -> void:
	# The first physics frame of a suite is not a full tick for a freshly added body.
	await get_tree().physics_frame


func after_test() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	_nodes.clear()
	Settings.values.clear()
	Input.flush_buffered_events()
	for action: String in InputRouter.ACTIONS:
		Input.action_release(action)


func _track(node: Node) -> Node:
	_nodes.append(node)
	return node


## A ship at `start` with its nose towards `target`.
func _ship_aimed_at(start: Vector3, target: Vector3) -> Ship:
	var ship: Ship = FlightSim.spawn(self)
	_track(ship)
	ship.global_transform = Transform3D(Basis.looking_at(target - start, Vector3.UP), start)
	return ship


## One rock of the arena's real shape and scale, with the colliders pool following `ship`.
func _single_rock_field(scale: float) -> Dictionary:
	var arena: ArenaDef = FLIGHT_TEST.duplicate() as ArenaDef
	arena.field_rock_count = 1
	arena.field_min_scale = scale
	arena.field_max_scale = scale
	arena.field_inner_radius = 400.0
	arena.field_outer_radius = 800.0
	arena.field_vertical_scale = 1.0
	var variant: Dictionary = AsteroidField.load_variant(AsteroidField.VARIANT_PATHS[0])
	var field: RockField = RockField.generate(
		arena, PackedFloat32Array([variant["radius"] as float])
	)
	var colliders: RockColliders = RockColliders.new()
	_track(colliders)
	add_child(colliders)
	var shapes: Array[Shape3D] = [variant["shape"] as Shape3D]
	colliders.setup(field, shapes, arena)
	return {"field": field, "colliders": colliders}


func test_a_ship_bounces_off_a_rock_instead_of_passing_through_it() -> void:
	var rock: Dictionary = _single_rock_field(3.0)
	var field: RockField = rock["field"]
	var colliders: RockColliders = rock["colliders"]
	var centre: Vector3 = field.transforms[0].origin
	var start: Vector3 = centre + Vector3(0.0, 0.0, 240.0)
	var ship: Ship = _ship_aimed_at(start, centre)
	colliders.set_target(ship)
	ship.controls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	var closest: float = INF
	var best_rebound: float = 0.0
	var reached_rock: bool = false
	for _tick: int in 360:
		await get_tree().physics_frame
		var to_centre: Vector3 = centre - ship.global_position
		closest = minf(closest, to_centre.length())
		var away: float = -ship.linear_velocity.dot(to_centre.normalized())
		if closest < field.radii[0] + 12.0:
			reached_rock = true
		if reached_rock:
			best_rebound = maxf(best_rebound, away)
	assert_bool(reached_rock).override_failure_message("the ship never reached the rock").is_true()
	# It did not tunnel into the middle of the rock...
	assert_float(closest).is_greater(field.radii[0] * 0.35)
	# ...and it was thrown back from it.
	assert_float(best_rebound).override_failure_message("no rebound").is_greater(3.0)
	assert_bool(is_finite(ship.global_position.length())).is_true()


func test_the_solid_rocks_follow_a_moving_ship() -> void:
	var arena: ArenaDef = FLIGHT_TEST.duplicate() as ArenaDef
	arena.field_rock_count = 1500
	var field: RockField = RockField.generate(arena, PackedFloat32Array([5.0, 5.0, 5.0, 5.0]))
	var colliders: RockColliders = RockColliders.new()
	_track(colliders)
	add_child(colliders)
	var shapes: Array[Shape3D] = []
	for _variant: int in 4:
		shapes.append(BoxShape3D.new())
	colliders.setup(field, shapes, arena)
	var ship: Ship = FlightSim.spawn(self)
	_track(ship)
	colliders.set_target(ship)
	ship.controls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	await SimHelper.step_physics(get_tree(), 5)
	var first: PackedInt32Array = colliders.active_rocks()
	assert_int(first.size()).is_greater(0)
	# Fly 300 ticks (5 s) away: the pool must now stand on rocks near the new position.
	await SimHelper.step_physics(get_tree(), 300)
	var now: PackedInt32Array = colliders.active_rocks()
	for rock: int in now:
		var gap: float = (
			field.transforms[rock].origin.distance_to(ship.global_position) - field.radii[rock]
		)
		assert_float(gap).is_less_equal(arena.collider_radius + 10.0)


func test_a_ship_flying_through_a_ring_gate_passes_it_once() -> void:
	var gate: RingGate = GATE_SCENE.instantiate() as RingGate
	_track(gate)
	add_child(gate)
	gate.position = Vector3(0.0, 0.0, -300.0)
	var passes: Array[int] = [0]
	gate.passed.connect(func(_ship: Ship) -> void: passes[0] += 1)
	var ship: Ship = FlightSim.spawn(self)
	_track(ship)
	ship.controls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	await SimHelper.step_physics(get_tree(), 330)
	assert_int(passes[0]).is_equal(1)
	assert_int(gate.pass_count).is_equal(1)
	# The ship came out the other side, and the rim flashed.
	assert_float(ship.global_position.z).is_less(-300.0)


func test_a_ship_flying_past_the_gate_does_not_pass_it() -> void:
	var gate: RingGate = GATE_SCENE.instantiate() as RingGate
	_track(gate)
	add_child(gate)
	gate.position = Vector3(0.0, 0.0, -300.0)
	var ship: Ship = FlightSim.spawn(self)
	_track(ship)
	ship.global_position = Vector3(60.0, 0.0, 0.0)
	ship.controls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	await SimHelper.step_physics(get_tree(), 330)
	assert_int(gate.pass_count).is_equal(0)
	assert_float(ship.global_position.z).is_less(-300.0)


func test_the_gate_flash_fades_out() -> void:
	var gate: RingGate = GATE_SCENE.instantiate() as RingGate
	_track(gate)
	add_child(gate)
	gate.position = Vector3(0.0, 0.0, -300.0)
	var ship: Ship = FlightSim.spawn(self)
	_track(ship)
	ship.controls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	await SimHelper.step_physics(get_tree(), 250)
	assert_float(gate.flash_amount()).is_greater(0.0)
	# The flash is driven by `_process`; step a few frames to let it run down.
	await SimHelper.step_physics(get_tree(), int(RingGate.FLASH_TIME * 60.0) + 120)
	assert_float(gate.flash_amount()).is_equal(0.0)


func test_the_arena_scene_runs_with_the_player_flying_and_boosting() -> void:
	var arena: FlightTest = ARENA_SCENE.instantiate() as FlightTest
	_track(arena)
	add_child(arena)
	await SimHelper.step_physics(get_tree(), 2)
	assert_object(arena.ship).is_not_null()
	var hud: FlightHud = arena.get_node("Hud/FlightHud") as FlightHud
	assert_object(hud.ship).is_same(arena.ship)
	assert_object(arena.get_node("PauseMenu")).is_instanceof(PauseMenu)
	assert_object(arena.get_node("DevTools")).is_instanceof(DevTools)
	# The player's pilot would overwrite the scripted controls every tick.
	for child: Node in arena.ship.get_children():
		if child is PlayerPilot:
			child.free()
	assert_int(arena.get_node("Gates").get_child_count()).is_equal(
		FLIGHT_TEST.gate_transforms.size()
	)
	var field: AsteroidField = arena.get_node("AsteroidField") as AsteroidField
	assert_int(field.field.count()).is_equal(FLIGHT_TEST.field_rock_count)
	var controls: ShipControls = FlightSim.controls(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.1, 0.0))
	controls.boost = true
	var most_solid: int = 0
	var top_speed: float = 0.0
	for _tick: int in 600:
		arena.ship.controls = controls
		await get_tree().physics_frame
		most_solid = maxi(most_solid, field.colliders.active_count())
		top_speed = maxf(top_speed, arena.ship.linear_velocity.length())
	assert_bool(is_finite(arena.ship.global_position.length())).is_true()
	assert_int(most_solid).is_greater(0)
	assert_float(top_speed).is_less_equal(FLIGHT_TEST_BOOST_TOP)
	assert_float(top_speed).is_greater(100.0)


func test_the_arena_has_its_target_dummies_and_a_projectile_manager() -> void:
	var arena: FlightTest = ARENA_SCENE.instantiate() as FlightTest
	_track(arena)
	add_child(arena)
	await SimHelper.step_physics(get_tree(), 2)
	var dummies: Node = arena.get_node("Dummies")
	assert_int(dummies.get_child_count()).is_equal(FLIGHT_TEST.dummy_ids.size())
	for dummy: Node in dummies.get_children():
		assert_object(dummy).is_instanceof(TargetDummy)
	assert_object(ProjectileManager.for_node(arena)).is_same(arena.get_node("ProjectileManager"))


func test_the_player_shoots_the_dummy_ahead_in_the_arena() -> void:
	var arena: FlightTest = ARENA_SCENE.instantiate() as FlightTest
	_track(arena)
	add_child(arena)
	await SimHelper.step_physics(get_tree(), 2)
	for child: Node in arena.ship.get_children():
		if child is PlayerPilot:
			child.free()
	var first: TargetDummy = arena.get_node("Dummies").get_child(0) as TargetDummy
	var held: ShipControls = ShipControls.new()
	held.fire_primary = true
	for _tick: int in 150:
		arena.ship.controls = held
		await get_tree().physics_frame
	var durability: Durability = first.durability()
	# The first dummy stands dead ahead of the start: some of its shield is gone.
	assert_float(durability.shield + durability.armor + durability.hull).is_less(
		first.def.shield_capacity + first.def.armor_capacity + first.def.hull_capacity
	)


func test_respawning_moves_the_hud_to_the_new_ship() -> void:
	var arena: FlightTest = ARENA_SCENE.instantiate() as FlightTest
	_track(arena)
	add_child(arena)
	await SimHelper.step_physics(get_tree(), 2)
	var first: Ship = arena.ship
	var second: Ship = arena.spawn_player(FLIGHT_TEST.spawn_ship_id)
	await SimHelper.step_physics(get_tree(), 2)
	assert_object(second).is_not_same(first)
	assert_object((arena.get_node("Hud/FlightHud") as FlightHud).ship).is_same(second)


func _press_slot(slot: int) -> void:
	var action: String = "device_%d" % slot
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func test_the_device_slots_switch_the_player_ship() -> void:
	var arena: FlightTest = ARENA_SCENE.instantiate() as FlightTest
	_track(arena)
	add_child(arena)
	await SimHelper.step_physics(get_tree(), 2)
	assert_str(arena.ship.def.id).is_equal("kestrel")
	for pair: Array in [[2, &"bulwark"], [3, &"drayman"], [1, &"kestrel"]]:
		var before: Ship = arena.ship
		await _press_slot(pair[0] as int)
		assert_str(arena.ship.def.id).is_equal(String(pair[1] as StringName))
		assert_object(arena.ship).is_not_same(before)
		# The old ship is gone at once, the new one stands at the start with the HUD bound.
		assert_bool(is_instance_valid(before) and before.is_inside_tree()).is_false()
		assert_vector(arena.ship.global_position).is_equal_approx(
			FLIGHT_TEST.spawn_position, Vector3.ONE * 5.0
		)
		assert_object((arena.get_node("Hud/FlightHud") as FlightHud).ship).is_same(arena.ship)
		assert_object(arena.get_node("CameraRig").get("ship")).is_same(arena.ship)


func test_pressing_the_current_ships_slot_keeps_the_ship() -> void:
	var arena: FlightTest = ARENA_SCENE.instantiate() as FlightTest
	_track(arena)
	add_child(arena)
	await SimHelper.step_physics(get_tree(), 2)
	var first: Ship = arena.ship
	await _press_slot(1)
	assert_object(arena.ship).is_same(first)
