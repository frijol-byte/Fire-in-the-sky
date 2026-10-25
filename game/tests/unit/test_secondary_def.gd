extends GdUnitTestSuite
## `SecondaryDef` content: both secondaries load and validate, bad values are caught, and every
## ship's secondary exists.

const MISSILE: SecondaryDef = preload("res://data/secondaries/homing_missile.tres")
const ROCKETS: SecondaryDef = preload("res://data/secondaries/rocket_pod.tres")


func _copy(source: SecondaryDef = MISSILE) -> SecondaryDef:
	return source.duplicate() as SecondaryDef


func test_both_secondaries_are_registered_and_valid() -> void:
	for id: StringName in [&"homing_missile", &"rocket_pod"]:
		var def: SecondaryDef = Content.secondary(id)
		assert_object(def).is_not_null()
		assert_str(def.id).is_equal(id)
		assert_array(def.problems()).is_empty()
		assert_str(tr(def.display_name_key)).is_not_equal(def.display_name_key)
		assert_bool(ResourceLoader.exists(def.launch_sfx)).is_true()


func test_the_missile_homes_and_the_pod_does_not() -> void:
	# GDD 7.2: Homing Missile = hold to lock (1.2 s), tracks the target; Rocket Pod = dumb-fire salvo.
	assert_bool(MISSILE.is_homing()).is_true()
	assert_float(MISSILE.lock_time).is_equal(1.2)
	assert_int(MISSILE.salvo_count).is_equal(1)
	assert_bool(ROCKETS.is_homing()).is_false()
	assert_int(ROCKETS.salvo_count).is_greater(1)
	assert_float(ROCKETS.spread_deg).is_greater(0.0)


func test_both_do_explosive_damage_with_splash() -> void:
	for def: SecondaryDef in [MISSILE, ROCKETS]:
		assert_int(def.damage_type).is_equal(DamageInfo.Type.EXPLOSIVE)
		assert_float(def.splash_radius_m).is_greater(0.0)
		assert_float(def.damage).is_greater(0.0)
	# One missile is a heavy hit, one rocket a light one.
	assert_float(MISSILE.damage).is_greater(ROCKETS.damage * 2.0)


func test_a_homing_missile_can_be_outrun_by_the_kestrels_boost() -> void:
	# The GDD's counter: boost away. The missile must top out below the Kestrel's boost speed. The
	# slower ships cannot flee, so they have the flares (and the Bulwark carries rockets, not missiles).
	assert_float(MISSILE.max_speed).is_less(Content.ship(&"kestrel").boost_max_speed)
	# ... yet it flies far enough in its lifetime to reach anything inside its lock range.
	assert_float(MISSILE.lifetime * MISSILE.max_speed).is_greater(MISSILE.lock_range_m)


func test_every_ship_is_fitted_with_an_existing_secondary_and_devices() -> void:
	for id: StringName in Content.ids(&"ship"):
		var ship_def: ShipDef = Content.ship(id)
		assert_object(Content.secondary(ship_def.secondary_weapon)).is_not_null()
		assert_array(ship_def.device_ids).is_not_empty()
		for device_id: StringName in ship_def.device_ids:
			assert_object(Content.device(device_id)).is_not_null()


func test_problems_flags_bad_values() -> void:
	var cases: Dictionary[String, Callable] = {
		"zero damage": func(d: SecondaryDef) -> void: d.damage = 0.0,
		"no splash": func(d: SecondaryDef) -> void: d.splash_radius_m = 0.0,
		"no ammo": func(d: SecondaryDef) -> void: d.ammo = 0,
		"salvo bigger than the magazine": func(d: SecondaryDef) -> void: d.salvo_count = 99,
		"launch faster than the top speed": func(d: SecondaryDef) -> void: d.launch_speed = 999.0,
		"no lifetime": func(d: SecondaryDef) -> void: d.lifetime = 0.0,
		"no lock time": func(d: SecondaryDef) -> void: d.lock_time = 0.0,
		"no turn rate": func(d: SecondaryDef) -> void: d.turn_rate_deg = 0.0,
		"salvo of homing missiles": func(d: SecondaryDef) -> void: d.salvo_count = 2,
		"negative fuse": func(d: SecondaryDef) -> void: d.fuse_radius_m = -1.0,
		"missing sound": func(d: SecondaryDef) -> void: d.launch_sfx = "res://nope.wav",
		"no name": func(d: SecondaryDef) -> void: d.display_name_key = "",
		"no id": func(d: SecondaryDef) -> void: d.id = &"",
	}
	for label: String in cases:
		var def: SecondaryDef = _copy()
		cases[label].call(def)
		(
			assert_array(def.problems())
			. override_failure_message("'%s' was not caught" % label)
			. is_not_empty()
		)


func test_a_rocket_pod_ignores_the_guidance_numbers() -> void:
	var rockets: SecondaryDef = _copy(ROCKETS)
	rockets.lock_time = 0.0
	rockets.turn_rate_deg = 0.0
	assert_array(rockets.problems()).is_empty()


func test_derived_values() -> void:
	assert_float(MISSILE.turn_rate_rad()).is_equal_approx(deg_to_rad(MISSILE.turn_rate_deg), 0.0001)
	assert_float(MISSILE.lock_cone_rad()).is_equal_approx(deg_to_rad(MISSILE.lock_cone_deg), 0.0001)
