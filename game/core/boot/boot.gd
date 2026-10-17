extends Control
## Boot scene: dark background, game title and a version label.

const VERSION_PATH: String = "res://version.txt"
const DEV_VERSION: String = "dev"

@onready var _title: Label = %Title
@onready var _version: Label = %Version


func _ready() -> void:
	_title.text = tr("GAME_TITLE")
	_version.text = tr("BOOT_VERSION") % read_version()
	Log.info("boot", "boot scene ready, version %s" % read_version())


## Returns the contents of `res://version.txt`, or "dev" if the file is missing or empty.
static func read_version() -> String:
	if not FileAccess.file_exists(VERSION_PATH):
		return DEV_VERSION
	var text: String = FileAccess.get_file_as_string(VERSION_PATH).strip_edges()
	return text if not text.is_empty() else DEV_VERSION
