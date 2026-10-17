extends GdUnitTestSuite
## `ShotDirector`'s static helpers (screenshot harness, M0-T5).


func _shot(label: String, frame: int) -> ShotDef:
	var shot: ShotDef = ShotDef.new()
	shot.label = label
	shot.frame = frame
	return shot


func test_manifest_path_is_read_from_user_args() -> void:
	var args: PackedStringArray = ["--other", "--shot-manifest=/tmp/m.json", "--x=1"]
	assert_str(ShotDirector.manifest_path_from_args(args)).is_equal("/tmp/m.json")


func test_manifest_path_is_empty_without_the_argument() -> void:
	assert_str(ShotDirector.manifest_path_from_args(PackedStringArray())).is_empty()
	assert_str(ShotDirector.manifest_path_from_args(["--shot-manifest"])).is_empty()


func test_shots_on_frame_returns_only_matching_shots() -> void:
	var shots: Array[ShotDef] = [_shot("a", 3), _shot("b", 5), _shot("c", 3)]
	var found: Array[ShotDef] = ShotDirector.shots_on_frame(shots, 3)
	assert_array(found).has_size(2)
	assert_str(found[0].label).is_equal("a")
	assert_str(found[1].label).is_equal("c")
	assert_array(ShotDirector.shots_on_frame(shots, 4)).is_empty()


func test_last_frame_is_the_highest_frame_or_zero() -> void:
	var shots: Array[ShotDef] = [_shot("a", 3), _shot("b", 9), _shot("c", 5)]
	assert_int(ShotDirector.last_frame(shots)).is_equal(9)
	assert_int(ShotDirector.last_frame([] as Array[ShotDef])).is_equal(0)


func test_manifest_json_lists_label_and_frame() -> void:
	var shots: Array[ShotDef] = [_shot("a", 3), _shot("b", 9)]
	var parsed: Dictionary = JSON.parse_string(ShotDirector.manifest_json(shots)) as Dictionary
	assert_that(parsed["shots"]).is_equal(
		[{"label": "a", "frame": 3.0}, {"label": "b", "frame": 9.0}]
	)
