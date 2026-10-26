class_name BarkDef
extends ContentDef
## Radio barks (GDD 8.2, M2-T7): the lines AI pilots call out when they change behavior, shown as
## text on the comms strip. Each behavior has `line_count` lines whose `strings.csv` keys are
## `<key_prefix><BEHAVIOR>_<n>` (e.g. `BARK_BREAK_OFF_1`). Whether a pilot speaks at all is a dice
## roll per behavior, and `BarkMath` keeps the radio from turning into a wall of chatter.

## Which behaviors bark, as `AIUtility.Behavior` names in lower case (`&"break_off"`), and the
## chance (0..1) that entering each one makes the pilot speak. Same length.
@export var behaviors: Array[StringName] = []
@export var chances: Array[float] = []
## Lines per behavior and the start of their keys.
@export var line_count: int = 5
@export var key_prefix: String = "BARK_"
## The least time (seconds) between two barks on the radio, and between two from the same pilot.
@export var min_gap_seconds: float = 1.6
@export var min_pilot_gap_seconds: float = 5.0
## How many lines the comms strip shows, and for how long each stays.
@export var strip_lines: int = 3
@export var line_seconds: float = 5.0
## Pilots' callsigns (`strings.csv` keys), handed out in order by whoever spawns pirates.
@export var callsign_keys: Array[StringName] = []


func kind() -> StringName:
	return &"bark"


## The `strings.csv` key of line `line` (0-based) of `behavior_name`.
func key_for(behavior_name: StringName, line: int) -> String:
	return "%s%s_%d" % [key_prefix, String(behavior_name).to_upper(), line + 1]


## The chance that entering `behavior_name` makes a pilot speak; 0 for a behavior without barks.
func chance_for(behavior_name: StringName) -> float:
	var index: int = behaviors.find(behavior_name)
	return chances[index] if index >= 0 and index < chances.size() else 0.0


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if behaviors.size() != chances.size():
		result.append("behaviors and chances must have the same length")
	var known: Array = AIUtility.Behavior.keys()
	for behavior_name: StringName in behaviors:
		if not known.has(String(behavior_name).to_upper()):
			result.append("unknown behavior '%s'" % behavior_name)
	for chance: float in chances:
		if chance < 0.0 or chance > 1.0:
			result.append("chances must be between 0 and 1")
			break
	if line_count < 2:
		result.append("line_count must be at least 2 (so a pilot can avoid repeating itself)")
	if key_prefix.is_empty():
		result.append("key_prefix is empty")
	if min_gap_seconds < 0.0 or min_pilot_gap_seconds < 0.0:
		result.append("bark gaps must not be negative")
	if strip_lines < 1 or line_seconds <= 0.0:
		result.append("the strip needs at least one line and a positive line_seconds")
	return result
