extends GdUnitTestSuite
## `Targeting`'s pure rules: which candidate a tap or double-tap picks, the cycle, and the lock state
## and the time before a lost lock is dropped.

const CONE: float = deg_to_rad(15.0)
const ORIGIN: Vector3 = Vector3.ZERO
const FORWARD: Vector3 = Vector3(0, 0, -1)


func _at(
	offset: Vector3, stance: Targeting.Stance = Targeting.Stance.HOSTILE
) -> Targeting.Candidate:
	return Targeting.Candidate.make(offset, stance, ORIGIN, FORWARD)


func _list(items: Array[Targeting.Candidate]) -> Array[Targeting.Candidate]:
	return items


func test_nothing_to_pick_gives_null() -> void:
	var none: Array[Targeting.Candidate] = []
	assert_object(Targeting.choose(none, null, Targeting.Pick.HOSTILE, CONE)).is_null()
	assert_object(Targeting.choose(none, null, Targeting.Pick.ANY, CONE)).is_null()


func test_a_tap_prefers_a_hostile_in_the_reticle_cone_over_a_nearer_one_outside_it() -> void:
	var near_side: Targeting.Candidate = _at(Vector3(-200, 0, -50))
	var far_ahead: Targeting.Candidate = _at(Vector3(5, 0, -600))
	var picked: Targeting.Candidate = Targeting.choose(
		_list([near_side, far_ahead]), null, Targeting.Pick.HOSTILE, CONE
	)
	assert_object(picked).is_same(far_ahead)


func test_a_tap_takes_the_nearest_of_several_in_the_cone() -> void:
	var farther: Targeting.Candidate = _at(Vector3(0, 0, -500))
	var nearer: Targeting.Candidate = _at(Vector3(10, 0, -300))
	var picked: Targeting.Candidate = Targeting.choose(
		_list([farther, nearer]), null, Targeting.Pick.HOSTILE, CONE
	)
	assert_object(picked).is_same(nearer)


func test_a_tap_with_nothing_in_the_cone_takes_the_nearest_hostile() -> void:
	var far: Targeting.Candidate = _at(Vector3(900, 0, 0))
	var near: Targeting.Candidate = _at(Vector3(-300, 0, 100))
	var picked: Targeting.Candidate = Targeting.choose(
		_list([far, near]), null, Targeting.Pick.HOSTILE, CONE
	)
	assert_object(picked).is_same(near)


func test_a_tap_ignores_neutral_and_friendly_targets() -> void:
	var friend: Targeting.Candidate = _at(Vector3(0, 0, -100), Targeting.Stance.FRIENDLY)
	var neutral: Targeting.Candidate = _at(Vector3(0, 0, -150), Targeting.Stance.NEUTRAL)
	var enemy: Targeting.Candidate = _at(Vector3(0, 0, -800))
	var picked: Targeting.Candidate = Targeting.choose(
		_list([friend, neutral, enemy]), null, Targeting.Pick.HOSTILE, CONE
	)
	assert_object(picked).is_same(enemy)
	(
		assert_object(
			Targeting.choose(_list([friend, neutral]), null, Targeting.Pick.HOSTILE, CONE)
		)
		. is_null()
	)


func test_a_double_tap_takes_the_nearest_target_of_any_side() -> void:
	var friend: Targeting.Candidate = _at(Vector3(0, 0, -100), Targeting.Stance.FRIENDLY)
	var enemy: Targeting.Candidate = _at(Vector3(0, 0, -300))
	var picked: Targeting.Candidate = Targeting.choose(
		_list([enemy, friend]), enemy.node, Targeting.Pick.ANY, CONE
	)
	assert_object(picked).is_same(friend)


func test_tapping_again_cycles_through_the_hostiles_by_distance_and_wraps() -> void:
	var a: Targeting.Candidate = _at(Vector3(0, 0, -200))
	var b: Targeting.Candidate = _at(Vector3(0, 0, -400))
	var c: Targeting.Candidate = _at(Vector3(0, 0, -700))
	var all: Array[Targeting.Candidate] = _list([c, a, b])
	# Candidates here are plain data, so each one stands for its own "node": use distinct nodes.
	var nodes: Array[Node3D] = []
	for candidate: Targeting.Candidate in all:
		var node: Node3D = auto_free(Node3D.new())
		candidate.node = node
		nodes.append(node)
	var first: Targeting.Candidate = Targeting.choose(all, null, Targeting.Pick.HOSTILE, CONE)
	assert_object(first).is_same(a)
	var second: Targeting.Candidate = Targeting.choose(
		all, first.node, Targeting.Pick.HOSTILE, CONE
	)
	assert_object(second).is_same(b)
	var third: Targeting.Candidate = Targeting.choose(
		all, second.node, Targeting.Pick.HOSTILE, CONE
	)
	assert_object(third).is_same(c)
	var wrapped: Targeting.Candidate = Targeting.choose(
		all, third.node, Targeting.Pick.HOSTILE, CONE
	)
	assert_object(wrapped).is_same(a)


func test_cycling_with_a_single_hostile_keeps_it() -> void:
	var only: Targeting.Candidate = _at(Vector3(0, 0, -200))
	only.node = auto_free(Node3D.new())
	var picked: Targeting.Candidate = Targeting.choose(
		_list([only]), only.node, Targeting.Pick.HOSTILE, CONE
	)
	assert_object(picked).is_same(only)


func test_candidates_know_distance_and_angle_from_the_nose() -> void:
	var candidate: Targeting.Candidate = _at(Vector3(300, 0, -300))
	assert_float(candidate.distance).is_equal_approx(424.264, 0.01)
	assert_float(candidate.angle).is_equal_approx(deg_to_rad(45.0), 0.0001)
	assert_float(_at(Vector3.ZERO).angle).is_equal(0.0)


func test_lock_status_is_range_first_then_line_of_sight() -> void:
	assert_int(Targeting.lock_status(500.0, 1500.0, false)).is_equal(Targeting.Lock.LOCKED)
	assert_int(Targeting.lock_status(1500.0, 1500.0, false)).is_equal(Targeting.Lock.LOCKED)
	assert_int(Targeting.lock_status(1501.0, 1500.0, false)).is_equal(Targeting.Lock.OUT_OF_RANGE)
	assert_int(Targeting.lock_status(500.0, 1500.0, true)).is_equal(Targeting.Lock.OCCLUDED)
	assert_int(Targeting.lock_status(2000.0, 1500.0, true)).is_equal(Targeting.Lock.OUT_OF_RANGE)


func test_the_lost_lock_timer_counts_up_and_resets() -> void:
	var lost: float = 0.0
	for _i: int in 3:
		lost = Targeting.lost_time_step(lost, false, 0.5)
	assert_float(lost).is_equal_approx(1.5, 0.0001)
	assert_float(Targeting.lost_time_step(lost, true, 0.5)).is_equal(0.0)
	assert_bool(Targeting.lock_expired(1.99, 2.0)).is_false()
	assert_bool(Targeting.lock_expired(2.0, 2.0)).is_true()
