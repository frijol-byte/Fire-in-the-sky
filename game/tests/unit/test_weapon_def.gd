extends GdUnitTestSuite
## `WeaponDef` content: both primaries load and validate, bad values are caught, and every ship's
## weapon exists.

const PULSE: WeaponDef = preload("res://data/weapons/pulse_laser.tres")
const CANNON: WeaponDef = preload("res://data/weapons/autocannon.tres")


func _copy(source: WeaponDef = PULSE) -> WeaponDef:
	return source.duplicate() as WeaponDef


func test_both_weapons_are_registered_and_valid() -> void:
	for id: StringName in [&"pulse_laser", &"autocannon"]:
		var weapon: WeaponDef = Content.weapon(id)
		assert_object(weapon).is_not_null()
		assert_str(weapon.id).is_equal(id)
		assert_array(weapon.problems()).is_empty()
		assert_str(tr(weapon.display_name_key)).is_not_equal(weapon.display_name_key)
		assert_bool(ResourceLoader.exists(weapon.fire_sfx)).is_true()


func test_the_laser_is_energy_and_the_autocannon_is_kinetic() -> void:
	# GDD 7.2: Pulse Laser = energy, uses energy; Autocannon = kinetic, high rate, spread, heat.
	assert_int(PULSE.damage_type).is_equal(DamageInfo.Type.ENERGY)
	assert_float(PULSE.energy_cost).is_greater(0.0)
	assert_float(PULSE.heat_per_shot).is_equal(0.0)
	assert_int(CANNON.damage_type).is_equal(DamageInfo.Type.KINETIC)
	assert_float(CANNON.heat_per_shot).is_greater(0.0)
	assert_float(CANNON.spread_deg).is_greater(0.0)
	assert_float(CANNON.fire_rate).is_greater(PULSE.fire_rate)
	assert_float(PULSE.projectile_speed).is_greater(CANNON.projectile_speed)


func test_every_ship_is_fitted_with_an_existing_primary_weapon() -> void:
	for id: StringName in Content.ids(&"ship"):
		var weapon: WeaponDef = Content.weapon(Content.ship(id).primary_weapon)
		assert_object(weapon).is_not_null()
		assert_str(weapon.slot).is_equal("primary")


func test_derived_values() -> void:
	assert_float(PULSE.interval()).is_equal_approx(0.25, 0.0001)
	assert_float(PULSE.lifetime()).is_equal_approx(900.0 / 520.0, 0.0001)
	assert_float(CANNON.resume_heat()).is_equal_approx(40.0, 0.0001)


func test_problems_flags_bad_values() -> void:
	var cases: Dictionary[String, Callable] = {
		"zero damage": func(w: WeaponDef) -> void: w.damage = 0.0,
		"zero rate": func(w: WeaponDef) -> void: w.fire_rate = 0.0,
		"rate above one a tick": func(w: WeaponDef) -> void: w.fire_rate = 61.0,
		"no speed": func(w: WeaponDef) -> void: w.projectile_speed = 0.0,
		"negative energy": func(w: WeaponDef) -> void: w.energy_cost = -1.0,
		"gimbal above 3 degrees": func(w: WeaponDef) -> void: w.gimbal_deg = 3.5,
		"a shot hotter than the line": func(w: WeaponDef) -> void: w.heat_per_shot = 200.0,
		"missing sound": func(w: WeaponDef) -> void: w.fire_sfx = "res://nope.wav",
		"bad slot": func(w: WeaponDef) -> void: w.slot = &"turret",
		"no name": func(w: WeaponDef) -> void: w.display_name_key = "",
		"no id": func(w: WeaponDef) -> void: w.id = &"",
	}
	for label: String in cases:
		var weapon: WeaponDef = _copy()
		cases[label].call(weapon)
		(
			assert_array(weapon.problems())
			. override_failure_message("'%s' was not flagged" % label)
			. is_not_empty()
		)


func test_the_gimbal_limit_is_three_degrees() -> void:
	assert_float(WeaponDef.MAX_GIMBAL_DEG).is_equal(3.0)
	assert_float(PULSE.gimbal_deg).is_less_equal(3.0)
	assert_float(CANNON.gimbal_deg).is_less_equal(3.0)
