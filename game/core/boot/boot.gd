extends Control
## Boot scene: the test Kestrel turning slowly against a dark-blue sky, stepping through its
## upgrade tiers, with the title, the tier name and the version label on top.

const VERSION_PATH: String = "res://version.txt"
const DEV_VERSION: String = "dev"

## Seconds between tier changes.
const TIER_INTERVAL: float = 3.0
## Turntable speed in radians per second.
const TURN_SPEED: float = 0.45
const TIER_NAME_KEYS: Array[StringName] = [
	&"TIER_NAME_0", &"TIER_NAME_1", &"TIER_NAME_2", &"TIER_NAME_3"
]

var _tier: int = 0
var _elapsed_in_tier: float = 0.0

@onready var _title: Label = %Title
@onready var _version: Label = %Version
@onready var _tier_name: Label = %TierName
@onready var _pivot: Node3D = %Pivot
@onready var _ship: ShipModel = %Ship


func _ready() -> void:
	_title.text = tr("GAME_TITLE")
	_version.text = tr("BOOT_VERSION") % read_version()
	_show_tier(0)
	Log.info("boot", "boot scene ready, version %s" % read_version())


func _process(delta: float) -> void:
	_pivot.rotate_y(TURN_SPEED * delta)
	_elapsed_in_tier += delta
	if _elapsed_in_tier >= TIER_INTERVAL:
		_elapsed_in_tier -= TIER_INTERVAL
		_show_tier(next_tier(_tier))


## Returns the tier that follows `tier`, wrapping from the highest back to 0.
static func next_tier(tier: int) -> int:
	return (tier + 1) % (ShipModel.MAX_TIER + 1)


## Returns the translation key of the name of `tier` (clamped to the known tiers).
static func tier_name_key(tier: int) -> StringName:
	return TIER_NAME_KEYS[clampi(tier, 0, TIER_NAME_KEYS.size() - 1)]


## Returns the contents of `res://version.txt`, or "dev" if the file is missing or empty.
static func read_version() -> String:
	if not FileAccess.file_exists(VERSION_PATH):
		return DEV_VERSION
	var text: String = FileAccess.get_file_as_string(VERSION_PATH).strip_edges()
	return text if not text.is_empty() else DEV_VERSION


func _show_tier(tier: int) -> void:
	_tier = tier
	_ship.set_tier(tier)
	_tier_name.text = tr("BOOT_TIER") % [tier, tr(tier_name_key(tier))]
