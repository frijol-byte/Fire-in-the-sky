extends GdUnitTestSuite
## `Boot.read_version()` falls back to "dev" when `res://version.txt` is absent or empty.

const BootScript: GDScript = preload("res://core/boot/boot.gd")


func test_read_version_returns_non_empty_string() -> void:
	assert_str(BootScript.read_version()).is_not_empty()


func test_read_version_defaults_to_dev_without_version_file() -> void:
	# version.txt is only written by CI exports, so a checkout has none.
	if FileAccess.file_exists(BootScript.VERSION_PATH):
		return
	assert_str(BootScript.read_version()).is_equal(BootScript.DEV_VERSION)


func test_next_tier_steps_through_all_tiers_and_wraps() -> void:
	var seen: Array[int] = []
	var tier: int = 0
	for step: int in ShipModel.MAX_TIER + 2:
		seen.append(tier)
		tier = BootScript.next_tier(tier)
	assert_array(seen).is_equal([0, 1, 2, 3, 0])


func test_every_tier_has_a_translated_name() -> void:
	for tier: int in ShipModel.MAX_TIER + 1:
		var key: StringName = BootScript.tier_name_key(tier)
		assert_str(tr(key)).override_failure_message("missing key %s" % key).is_not_equal(key)
	assert_that(BootScript.tier_name_key(99)).is_equal(BootScript.tier_name_key(3))
