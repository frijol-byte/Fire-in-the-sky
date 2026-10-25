extends GdUnitTestSuite
## `TargetHud`'s pure helpers: bracket size, stance colours and the panel's bars.


func test_bracket_size_follows_the_target_but_stays_readable() -> void:
	assert_float(TargetHud.bracket_half_size(0.0)).is_equal(TargetHud.MIN_BRACKET)
	assert_float(TargetHud.bracket_half_size(1.0)).is_equal(TargetHud.MIN_BRACKET)
	assert_float(TargetHud.bracket_half_size(50.0)).is_equal_approx(
		50.0 * TargetHud.BRACKET_PADDING, 0.0001
	)
	assert_float(TargetHud.bracket_half_size(5000.0)).is_equal(TargetHud.MAX_BRACKET)


func test_each_stance_has_its_own_colour() -> void:
	var colors: Array[Color] = []
	for stance: int in Targeting.Stance.values():
		colors.append(TargetHud.stance_color(stance as Targeting.Stance))
	assert_bool(colors[0] == colors[1]).is_false()
	assert_bool(colors[1] == colors[2]).is_false()
	assert_bool(colors[0] == colors[2]).is_false()
	# Hostile reads as red, friendly as green.
	assert_float(colors[Targeting.Stance.HOSTILE].r).is_greater(colors[Targeting.Stance.HOSTILE].g)
	assert_float(colors[Targeting.Stance.FRIENDLY].g).is_greater(
		colors[Targeting.Stance.FRIENDLY].r
	)


func test_health_fractions_come_from_the_durability_layers() -> void:
	var durability: Durability = auto_free(Durability.new())
	durability.configure_layers(Vector3(100, 80, 60), 0.0, 4.0)
	durability.restore()
	assert_vector(TargetHud.health_fractions(durability)).is_equal(Vector3.ONE)
	durability.shield = 50.0
	durability.armor = 20.0
	durability.hull = 15.0
	assert_vector(TargetHud.health_fractions(durability)).is_equal_approx(
		Vector3(0.5, 0.25, 0.25), Vector3.ONE * 0.0001
	)
