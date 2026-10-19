class_name LogRing
extends RefCounted
## Keeps the most recent `capacity` lines of text in memory, oldest dropped first. `Log` feeds
## it so a bug report can attach the end of the session log without re-reading the file.

var capacity: int

var _lines: PackedStringArray = PackedStringArray()


func _init(max_lines: int = 200) -> void:
	capacity = maxi(max_lines, 1)


## Adds a line, dropping the oldest one when the buffer is full.
func push(line: String) -> void:
	_lines.append(line)
	if _lines.size() > capacity:
		_lines = _lines.slice(_lines.size() - capacity)


## The stored lines, oldest first. With `count` above 0, only the last `count` lines.
func lines(count: int = 0) -> PackedStringArray:
	if count <= 0 or count >= _lines.size():
		return _lines.duplicate()
	return _lines.slice(_lines.size() - count)


func size() -> int:
	return _lines.size()
