class_name BarkDirector
extends Node
## Radio barks v0 (GDD 8.2, M2-T7): when an AI pilot changes behavior it sometimes calls it out
## ("Breaking left!", "He's on me!"). The director listens to `Events.ai_behavior_changed`, rolls the
## dice per behavior, picks one of the behavior's lines (never the same one twice running for a
## pilot) and emits `barked` with the finished text. `CommsStrip` shows it. Text only: voices come
## with the audio pass. The lines are `strings.csv` keys named by `BarkDef`; `BarkMath` has the rules.

## A pilot spoke. `speaker` is the callsign (or the ship's name), `line` the translated words.
signal barked(ship: Node, speaker: String, line: String)

var def: BarkDef = null
## How many barks went out, for tests and the debug readout.
var barks_total: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock: float = 0.0
var _last_any: float = -INF
## Ship instance id -> time of its last bark / index of its last line.
var _last_by_pilot: Dictionary[int, float] = {}
var _last_line: Dictionary[int, int] = {}


func _ready() -> void:
	if def == null:
		def = Content.barks()
	_rng.seed = 31337
	Events.ai_behavior_changed.connect(_on_behavior_changed)


func _exit_tree() -> void:
	if Events.ai_behavior_changed.is_connected(_on_behavior_changed):
		Events.ai_behavior_changed.disconnect(_on_behavior_changed)


func _process(delta: float) -> void:
	_clock += delta


## Seeds the dice (tests use it for repeatable chatter).
func seed_rolls(seed_value: int) -> void:
	_rng.seed = seed_value


## Makes `ship` call out `behavior_name` now, ignoring the dice and the radio gaps. Returns the text.
func bark(ship: Node, behavior_name: StringName) -> String:
	var id: int = ship.get_instance_id()
	var line: int = BarkMath.pick_line(def.line_count, _last_line.get(id, -1), _rng.randf())
	_last_line[id] = line
	_last_by_pilot[id] = _clock
	_last_any = _clock
	barks_total += 1
	var text: String = tr(def.key_for(behavior_name, line))
	barked.emit(ship, speaker_of(ship), text)
	return text


## The name shown before a pilot's line: its callsign if it has one, else the ship's name.
static func speaker_of(ship: Node) -> String:
	if ship.has_meta(&"callsign") and not String(ship.get_meta(&"callsign")).is_empty():
		return ship.get_meta(&"callsign") as String
	if ship.has_method(&"target_name"):
		return ship.call(&"target_name") as String
	return ship.name


func _on_behavior_changed(ship: Node, behavior: int) -> void:
	if def == null or ship == null or not is_instance_valid(ship):
		return
	if ship is Ship and (ship as Ship).is_wrecked():
		return
	var behavior_name: StringName = BarkMath.behavior_name(behavior)
	var chance: float = def.chance_for(behavior_name)
	if chance <= 0.0:
		return
	var id: int = ship.get_instance_id()
	if not BarkMath.can_speak(_clock, _last_any, _last_by_pilot.get(id, -INF), def):
		return
	# The dice are rolled last, after the cheap checks, so a quiet radio is not decided by luck.
	if _rng.randf() >= chance:
		return
	bark(ship, behavior_name)
