extends GdUnitTestSuite
## AI against AI: every duel must end with a winner in under three minutes of fight time, with no
## errors (the engine log counts: gdUnit fails a test that pushes one) and no ship leaving the
## arena. Each duel is its own test, so one slow fight cannot starve the next of its time.

## The longest a duel may last.
const DUEL_LIMIT: float = 180.0
const TICK: float = SimHelper.TICK
const START_APART: float = 300.0
## A ship that gets this far from the middle has flown off, not fought.
const ARENA_LIMIT: float = 6000.0


## Both ships start `START_APART` metres from the middle on the x axis, nose to nose. `a` is hostile
## and `b` friendly (so they are enemies). Returns {winner: "a", "b" or "", seconds, a, b}.
func _duel(
	a_id: StringName,
	a_profile: StringName,
	b_id: StringName,
	b_profile: StringName,
	seed_value: int
) -> Dictionary:
	auto_free(CombatSim.spawn_manager(self))
	auto_free(CombatSim.spawn_missile_manager(self))
	var left: Vector3 = Vector3(-START_APART, 0.0, 0.0)
	var right: Vector3 = Vector3(START_APART, 0.0, 0.0)
	var a: Ship = auto_free(
		CombatSim.spawn_ai(self, a_id, left, right, Targeting.Stance.HOSTILE, a_profile, seed_value)
	)
	var b: Ship = auto_free(
		CombatSim.spawn_ai(
			self, b_id, right, left, Targeting.Stance.FRIENDLY, b_profile, seed_value + 100
		)
	)
	var winner: String = ""
	var ticks: int = 0
	var flew_off: bool = false
	while ticks < roundi(DUEL_LIMIT / TICK):
		await get_tree().physics_frame
		ticks += 1
		flew_off = (
			flew_off
			or a.global_position.length() > ARENA_LIMIT
			or b.global_position.length() > ARENA_LIMIT
			or not a.global_position.is_finite()
			or not b.global_position.is_finite()
		)
		if a.durability().is_destroyed():
			winner = "b"
			break
		if b.durability().is_destroyed():
			winner = "a"
			break
	return {"winner": winner, "seconds": ticks * TICK, "flew_off": flew_off}


func _assert_decisive(result: Dictionary) -> void:
	assert_bool(result["flew_off"] as bool).override_failure_message("a ship flew off").is_false()
	(
		assert_str(result["winner"] as String)
		. override_failure_message("no winner in %.0f s" % DUEL_LIMIT)
		. is_not_empty()
	)
	assert_float(result["seconds"] as float).is_less(DUEL_LIMIT)


func test_kestrel_mirror_duel_seed_1() -> void:
	_assert_decisive(await _duel(&"kestrel", &"standard", &"kestrel", &"standard", 1))


func test_kestrel_mirror_duel_seed_2() -> void:
	_assert_decisive(await _duel(&"kestrel", &"standard", &"kestrel", &"standard", 2))


func test_kestrel_mirror_duel_seed_3() -> void:
	_assert_decisive(await _duel(&"kestrel", &"standard", &"kestrel", &"standard", 3))


func test_kestrel_mirror_duel_seed_4() -> void:
	_assert_decisive(await _duel(&"kestrel", &"standard", &"kestrel", &"standard", 4))


func test_kestrel_against_bulwark() -> void:
	_assert_decisive(await _duel(&"kestrel", &"standard", &"bulwark", &"standard", 1))


func test_bulwark_against_drayman() -> void:
	_assert_decisive(await _duel(&"bulwark", &"standard", &"drayman", &"standard", 1))


func test_drayman_against_kestrel() -> void:
	_assert_decisive(await _duel(&"drayman", &"standard", &"kestrel", &"standard", 1))


func test_drayman_mirror_duel() -> void:
	_assert_decisive(await _duel(&"drayman", &"standard", &"drayman", &"standard", 2))


func test_ace_against_ace() -> void:
	_assert_decisive(await _duel(&"kestrel", &"ace", &"kestrel", &"ace", 3))


func test_rookie_against_ace() -> void:
	_assert_decisive(await _duel(&"kestrel", &"rookie", &"kestrel", &"ace", 1))


func test_the_ace_beats_the_rookie_most_of_the_time() -> void:
	var ace_wins: int = 0
	var rookie_wins: int = 0
	for seed_value: int in [1, 2, 3]:
		var result: Dictionary = await _duel(&"kestrel", &"rookie", &"kestrel", &"ace", seed_value)
		match result["winner"]:
			"a":
				rookie_wins += 1
			"b":
				ace_wins += 1
		# Clean up this duel's ships before the next one.
		for child: Node in get_children():
			if child is Ship or child is ProjectileManager or child is MissileManager:
				remove_child(child)
				child.free()
	assert_int(ace_wins).is_greater(rookie_wins)
