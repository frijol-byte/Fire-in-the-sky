extends GdUnitTestSuite
## `DeviceDef` content: the flares load and validate, and bad values are caught.

const FLARES: DeviceDef = preload("res://data/devices/flares.tres")


func _copy() -> DeviceDef:
	return FLARES.duplicate() as DeviceDef


func test_the_flares_are_registered_and_valid() -> void:
	var def: DeviceDef = Content.device(&"flares")
	assert_object(def).is_not_null()
	assert_array(def.problems()).is_empty()
	assert_int(def.effect).is_equal(DeviceDef.Effect.FLARES)
	assert_str(tr(def.display_name_key)).is_not_equal(def.display_name_key)
	assert_bool(ResourceLoader.exists(def.use_sfx)).is_true()


func test_the_flares_are_a_gamble_with_a_cooldown() -> void:
	# A decoy chance, not a certainty (GDD 7.2: flares defeat missiles), and a real cooldown.
	assert_float(FLARES.decoy_chance).is_between(0.3, 0.9)
	assert_float(FLARES.cooldown).is_greater(FLARES.flare_lifetime)


func test_problems_flags_bad_values() -> void:
	var cases: Dictionary[String, Callable] = {
		"no cooldown": func(d: DeviceDef) -> void: d.cooldown = 0.0,
		"negative energy": func(d: DeviceDef) -> void: d.energy_cost = -1.0,
		"no flares": func(d: DeviceDef) -> void: d.flare_count = 0,
		"no burn time": func(d: DeviceDef) -> void: d.flare_lifetime = 0.0,
		"no range": func(d: DeviceDef) -> void: d.decoy_range_m = 0.0,
		"missing sound": func(d: DeviceDef) -> void: d.use_sfx = "res://nope.wav",
		"no name": func(d: DeviceDef) -> void: d.display_name_key = "",
		"no id": func(d: DeviceDef) -> void: d.id = &"",
	}
	for label: String in cases:
		var def: DeviceDef = _copy()
		cases[label].call(def)
		(
			assert_array(def.problems())
			. override_failure_message("'%s' was not caught" % label)
			. is_not_empty()
		)


func test_a_ship_def_rejects_more_devices_than_slots() -> void:
	var ship_def: ShipDef = Content.ship(&"kestrel").duplicate() as ShipDef
	ship_def.device_ids = [&"flares", &"flares"]
	assert_array(ship_def.problems()).is_not_empty()
	ship_def.device_slots = 2
	# Two of the same device is still refused.
	assert_array(ship_def.problems()).is_not_empty()
	ship_def.device_ids = [&"flares"]
	assert_array(ship_def.problems()).is_empty()
