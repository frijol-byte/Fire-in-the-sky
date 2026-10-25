extends GdUnitTestSuite
## A flying `Ship` owns a `Durability`, ticks it in the physics step and reports it in bug dumps.


func test_every_ship_spawns_with_full_layers(
	ship_id: StringName, _test_parameters := FlightSim.ship_params()
) -> void:
	var ship: Ship = auto_free(FlightSim.spawn(self, ship_id))
	var durability: Durability = ship.durability()
	assert_float(durability.shield).is_equal(ship.def.shield_capacity)
	assert_float(durability.armor).is_equal(ship.def.armor_capacity)
	assert_float(durability.hull).is_equal(ship.def.hull_capacity)


func test_the_shield_regenerates_while_the_ship_flies() -> void:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	var durability: Durability = ship.durability()
	durability.apply(DamageInfo.make(40.0, DamageInfo.Type.EXPLOSIVE))
	var after_hit: float = durability.shield
	await FlightSim.fly(get_tree(), ship, FlightSim.controls(), 60)
	assert_float(durability.shield).is_equal(after_hit)
	var wait: int = roundi((ship.def.shield_regen_delay + 2.0) * 60.0)
	await FlightSim.fly(get_tree(), ship, FlightSim.controls(), wait)
	assert_float(durability.shield).is_greater(after_hit)


func test_the_ion_status_runs_down_in_flight() -> void:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	ship.durability().apply(DamageInfo.make(5.0, DamageInfo.Type.ION))
	assert_bool(ship.durability().devices_disabled()).is_true()
	var ticks: int = roundi((Content.damage_table().ion_disable_seconds + 0.5) * 60.0)
	await FlightSim.fly(get_tree(), ship, FlightSim.controls(), ticks)
	assert_bool(ship.durability().devices_disabled()).is_false()


func test_events_carry_the_ship_that_was_hit() -> void:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	var hit: Array = []
	var listener: Callable = func(who: Node, _info: DamageInfo, _result: DamageResult) -> void:
		hit.append(who)
	Events.ship_damaged.connect(listener)
	ship.durability().apply(DamageInfo.make(5.0, DamageInfo.Type.ENERGY))
	Events.ship_damaged.disconnect(listener)
	assert_array(hit).has_size(1)
	assert_object(hit[0]).is_same(ship)


func test_bumping_a_rock_still_hurts_nothing() -> void:
	# Collision damage is not designed yet (M1-T5): a ship that hits a wall keeps its health.
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	var wall: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200, 200, 2)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = Vector3(0, 0, -60)
	await FlightSim.fly(get_tree(), ship, FlightSim.controls(Vector3(0, 0, -1)), 240)
	assert_float(ship.durability().hull).is_equal(ship.def.hull_capacity)
	assert_float(ship.durability().shield).is_equal(ship.def.shield_capacity)
