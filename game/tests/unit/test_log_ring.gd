extends GdUnitTestSuite
## `LogRing` keeps the newest lines; `Log.recent_lines` is what bug reports attach.


func test_keeps_lines_in_order_below_capacity() -> void:
	var ring: LogRing = LogRing.new(5)
	ring.push("a")
	ring.push("b")
	assert_array(ring.lines()).is_equal(["a", "b"])
	assert_int(ring.size()).is_equal(2)


func test_drops_the_oldest_lines_beyond_capacity() -> void:
	var ring: LogRing = LogRing.new(3)
	for index: int in 10:
		ring.push("line %d" % index)
	assert_int(ring.size()).is_equal(3)
	assert_array(ring.lines()).is_equal(["line 7", "line 8", "line 9"])


func test_lines_with_a_count_returns_only_the_newest() -> void:
	var ring: LogRing = LogRing.new(10)
	for index: int in 6:
		ring.push(str(index))
	assert_array(ring.lines(2)).is_equal(["4", "5"])
	assert_array(ring.lines(100)).has_size(6)
	assert_array(ring.lines(0)).has_size(6)


func test_lines_returns_a_copy() -> void:
	var ring: LogRing = LogRing.new(3)
	ring.push("x")
	var copy: PackedStringArray = ring.lines()
	copy.append("y")
	assert_int(ring.size()).is_equal(1)


func test_capacity_is_at_least_one() -> void:
	var ring: LogRing = LogRing.new(0)
	ring.push("a")
	ring.push("b")
	assert_array(ring.lines()).is_equal(["b"])


func test_log_keeps_the_last_200_lines() -> void:
	for index: int in Log.RING_LINES + 25:
		Log.info(&"test", "ring probe %d" % index)
	var lines: PackedStringArray = Log.recent_lines()
	assert_int(lines.size()).is_equal(Log.RING_LINES)
	assert_str(lines[lines.size() - 1]).contains("ring probe %d" % (Log.RING_LINES + 24))
	assert_array(Log.recent_lines(3)).has_size(3)
