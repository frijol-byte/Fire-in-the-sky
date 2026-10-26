class_name BarkMath
extends RefCounted
## The rules of radio barks (GDD 8.2): which line a pilot says and when the radio is free. Pure and
## unit tested; `BarkDirector` rolls the dice and keeps the clock.


## The `BarkDef` name of an `AIUtility.Behavior` value, e.g. `&"break_off"`.
static func behavior_name(behavior: int) -> StringName:
	var names: Array = AIUtility.Behavior.keys()
	if behavior < 0 or behavior >= names.size():
		return &""
	return StringName((names[behavior] as String).to_lower())


## Picks a line out of `count`, never `last` (-1 for none), from `roll` (0 up to but not including
## 1): the lines other than `last` are equally likely.
static func pick_line(count: int, last: int, roll: float) -> int:
	if count <= 1:
		return 0
	var choices: int = count - 1 if last >= 0 and last < count else count
	var index: int = clampi(int(roll * choices), 0, choices - 1)
	if last >= 0 and last < count and index >= last:
		index += 1
	return index


## True when a pilot may speak at `now` (seconds): the radio has been quiet for `min_gap_seconds`
## and this pilot for `min_pilot_gap_seconds`. A time of `-INF` means "never spoke".
static func can_speak(now: float, last_any: float, last_pilot: float, def: BarkDef) -> bool:
	return now - last_any >= def.min_gap_seconds and now - last_pilot >= def.min_pilot_gap_seconds
