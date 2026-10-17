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
