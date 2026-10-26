extends GdUnitTestSuite
## The combat test's waves against a stand-in for the player (M2-T7 balance check): the arena's
## own Kestrel flown by an AI pilot, in the real arena with the real wave director. A skilled pilot
## (the "ace" profile) must clear waves 1 and 2 within `WAVE_LIMIT`. The results (seconds, shield and
## hull left) are printed, and wave 3 (1v3) is only reported: the numbers are what the owner's
## playtest checks against.

const TICK: float = SimHelper.TICK
const ARENA_SCENE: PackedScene = preload("res://world/arenas/combat_test.tscn")
## The longest a wave may take.
const WAVE_LIMIT: float = 150.0

var _arena: CombatTest = null


func before_test() -> void:
	GameState.reset()
	_arena = ARENA_SCENE.instantiate() as CombatTest
	add_child(_arena)
	await SimHelper.step_physics(get_tree(), 3)


func after_test() -> void:
	if is_instance_valid(_arena):
		remove_child(_arena)
		_arena.free()
	GameState.reset()
	Settings.values.clear()
	Input.flush_buffered_events()
	for action: String in InputRouter.ACTIONS:
		Input.action_release(action)
	for _frame: int in 3:
		await get_tree().process_frame


## Hands the arena's Kestrel to an AI pilot of `profile_id`, starts wave `index` and flies until it
## is cleared, the player dies or the limit passes. Returns {cleared, died, seconds, shield, hull}.
func _fight(index: int, profile_id: StringName, seed_value: int) -> Dictionary:
	for child: Node in _arena.ship.get_children():
		if child is PlayerPilot:
			child.queue_free()
	_arena.ship.stance = Targeting.Stance.FRIENDLY
	var pilot: AIPilot = AIPilot.new()
	pilot.name = "AIPilot"
	pilot.profile = Content.ai_profile(profile_id)
	_arena.ship.add_child(pilot)
	pilot.seed_rolls(seed_value)
	# A lambda copies plain variables, so the flag lives in a dictionary.
	var flags: Dictionary = {"cleared": false}
	_arena.director.wave_cleared.connect(func(_wave: int) -> void: flags["cleared"] = true)
	_arena.director.restart_wave(index, 0.0)
	var taken: Dictionary = {}
	Events.ship_damaged.connect(
		func(node: Node, info: DamageInfo, result: DamageResult) -> void:
			if node == _arena.ship:
				taken[info.type] = (taken.get(info.type, 0.0) as float) + result.total()
	)
	var ticks: int = 0
	var died: bool = false
	while ticks < roundi(WAVE_LIMIT / TICK) and not (flags["cleared"] as bool) and not died:
		await get_tree().physics_frame
		ticks += 1
		# The stand-in hunts the nearest pirate (the pilot's own sight range is shorter than the
		# distance the pirates appear at).
		if (
			not is_instance_valid(pilot.forced_target)
			or not _arena.director.pirates.has(pilot.forced_target)
		):
			pilot.forced_target = _nearest_pirate()
		died = _arena.ship.durability().is_destroyed()
	var cleared: bool = flags["cleared"] as bool
	prints("damage taken by type:", taken)
	var durability: Durability = _arena.ship.durability()
	var result: Dictionary = {
		"cleared": cleared,
		"died": died,
		"seconds": ticks * TICK,
		"shield": durability.shield_fraction(),
		"hull": durability.hull_fraction(),
	}
	prints(
		(
			"wave %d vs %s: cleared %s, died %s, %.0f s, shield %.0f%%, armor %.0f%%, hull %.0f%%"
			% [
				index + 1,
				profile_id,
				cleared,
				died,
				result["seconds"],
				durability.shield_fraction() * 100.0,
				durability.armor_fraction() * 100.0,
				durability.hull_fraction() * 100.0
			]
		)
	)
	return result


func _nearest_pirate() -> Node3D:
	var nearest: Node3D = null
	var best: float = INF
	for pirate: Ship in _arena.director.pirates:
		var distance: float = pirate.global_position.distance_squared_to(
			_arena.ship.global_position
		)
		if distance < best:
			best = distance
			nearest = pirate
	return nearest


func _assert_won(result: Dictionary) -> void:
	assert_bool(result["died"] as bool).override_failure_message("the pilot died").is_false()
	assert_bool(result["cleared"] as bool).override_failure_message("wave not cleared").is_true()
	assert_float(result["seconds"] as float).is_less(WAVE_LIMIT)


func test_an_ace_clears_wave_1() -> void:
	_assert_won(await _fight(0, &"ace", 3))


func test_an_ace_clears_wave_2() -> void:
	_assert_won(await _fight(1, &"ace", 3))


func test_wave_3_is_a_real_threat_to_the_stand_in() -> void:
	# The AI stand-in fights one target at a time and has no aim assist, flares for missiles or
	# judgement, so it loses 1v3 where a person is meant to win it narrowly. The result is printed
	# for the playtest; what is checked is that the fight resolves and costs health.
	var result: Dictionary = await _fight(2, &"ace", 3)
	assert_bool((result["cleared"] as bool) or (result["died"] as bool)).is_true()
	assert_float(result["hull"] as float).is_less(1.0)
