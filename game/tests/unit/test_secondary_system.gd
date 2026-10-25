extends GdUnitTestSuite
## The pure rules of `SecondarySystem`, and what a ship carries.

const CONE: float = deg_to_rad(20.0)


func test_the_lock_envelope_is_a_cone_and_a_range() -> void:
	(
		assert_bool(
			SecondarySystem.in_lock_envelope(Vector3.FORWARD, Vector3(0, 0, -500), CONE, 1200.0)
		)
		. is_true()
	)
	# 10 degrees off: in. 30 degrees off: out.
	var inside: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(10.0)) * 500.0
	var outside: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(30.0)) * 500.0
	assert_bool(SecondarySystem.in_lock_envelope(Vector3.FORWARD, inside, CONE, 1200.0)).is_true()
	assert_bool(SecondarySystem.in_lock_envelope(Vector3.FORWARD, outside, CONE, 1200.0)).is_false()
	# Too far, dead ahead.
	(
		assert_bool(
			SecondarySystem.in_lock_envelope(Vector3.FORWARD, Vector3(0, 0, -1300), CONE, 1200.0)
		)
		. is_false()
	)
	# Behind: out. On top of the ship: in (no direction to speak of).
	(
		assert_bool(
			SecondarySystem.in_lock_envelope(Vector3.FORWARD, Vector3(0, 0, 500), CONE, 1200.0)
		)
		. is_false()
	)
	(
		assert_bool(SecondarySystem.in_lock_envelope(Vector3.FORWARD, Vector3.ZERO, CONE, 1200.0))
		. is_true()
	)


func test_every_ship_starts_with_a_full_magazine_and_its_devices() -> void:
	for ship_id: StringName in FlightSim.SHIP_IDS:
		var ship: Ship = auto_free(FlightSim.spawn(self, ship_id))
		var secondaries: SecondarySystem = ship.secondaries()
		assert_object(secondaries.def).is_not_null()
		assert_int(secondaries.ammo).is_equal(secondaries.def.ammo)
		assert_bool(secondaries.is_ready()).is_true()
		assert_int(ship.devices().count()).is_equal(ship.def.device_ids.size())
		assert_bool(ship.devices().is_ready(1)).is_true()


func test_add_ammo_stops_at_a_full_magazine() -> void:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	var secondaries: SecondarySystem = ship.secondaries()
	secondaries.ammo = 2
	assert_int(secondaries.add_ammo(3)).is_equal(3)
	assert_int(secondaries.ammo).is_equal(5)
	assert_int(secondaries.add_ammo(10)).is_equal(secondaries.def.ammo - 5)
	assert_int(secondaries.ammo).is_equal(secondaries.def.ammo)
	assert_int(secondaries.add_ammo(-4)).is_equal(0)
	assert_int(secondaries.ammo).is_equal(secondaries.def.ammo)


func test_a_ship_without_a_secondary_does_nothing() -> void:
	var ship_def: ShipDef = Content.ship(&"kestrel").duplicate() as ShipDef
	ship_def.secondary_weapon = &""
	var ship: Ship = FlightSim.SHIP_SCENE.instantiate() as Ship
	ship.def = ship_def
	add_child(ship)
	auto_free(ship)
	assert_object(ship.secondaries().def).is_null()
	assert_int(ship.secondaries().ammo).is_equal(0)
	assert_bool(ship.secondaries().is_ready()).is_false()
	assert_int(ship.secondaries().add_ammo(5)).is_equal(0)
	ship.secondaries().tick(0.1)
	(
		assert_str(FlightHud.secondary_text(null, 0, ship.secondaries().lock, 0.0, false, false))
		. is_empty()
	)


func test_a_ship_def_can_hold_up_to_three_distinct_devices() -> void:
	var ship_def: ShipDef = Content.ship(&"kestrel").duplicate() as ShipDef
	ship_def.device_slots = 3
	ship_def.device_ids = [&"flares", &"flares_2", &"flares_3"]
	assert_array(ship_def.problems()).is_empty()
	ship_def.device_ids = [&"flares", &"flares_2", &"flares_3", &"flares_4"]
	assert_array(ship_def.problems()).is_not_empty()
