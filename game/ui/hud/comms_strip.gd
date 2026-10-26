class_name CommsStrip
extends Control
## The comms strip (M2-T7): the last few radio lines, at the left of the HUD under the arena
## readout, newest at the bottom. Each line shows the speaker's callsign and the words, stays for
## `BarkDef.line_seconds` and fades over its last second. Text only. A child of `FlightHud`;
## whoever hears a bark calls `push` (the arenas connect `BarkDirector.barked`).

const LEFT: float = 56.0
const TOP: float = 430.0
const LINE_HEIGHT: float = 30.0
const FONT_SIZE: int = 22
const FADE_SECONDS: float = 1.0
const COLOR_SPEAKER: Color = Color(1.0, 0.62, 0.35, 1.0)
const COLOR_TEXT: Color = Color(0.92, 0.96, 1.0, 1.0)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.7)

## The lines on the strip, oldest first: {speaker, text, age}.
var _lines: Array[Dictionary] = []
var _max_lines: int = 3
var _line_seconds: float = 5.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var def: BarkDef = Content.barks()
	if def != null:
		_max_lines = def.strip_lines
		_line_seconds = def.line_seconds


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


## Adds a line; the oldest drops off when the strip is full.
func push(speaker: String, text: String) -> void:
	_lines.append({"speaker": speaker, "text": text, "age": 0.0})
	while _lines.size() > _max_lines:
		_lines.remove_at(0)


## Ages the lines by `delta` seconds and drops the ones that have run out.
func advance(delta: float) -> void:
	for line: Dictionary in _lines:
		line["age"] = (line["age"] as float) + delta
	while not _lines.is_empty() and (_lines[0]["age"] as float) >= _line_seconds:
		_lines.remove_at(0)


## How many lines are on the strip.
func line_count() -> int:
	return _lines.size()


## The text of line `index` (0 = oldest) as "SPEAKER: words".
func line_text(index: int) -> String:
	var line: Dictionary = _lines[index]
	return "%s: %s" % [line["speaker"], line["text"]]


## Opacity of a line that has been up for `age` seconds, `line_seconds` long in all.
static func line_alpha(age: float, line_seconds: float) -> float:
	var left: float = line_seconds - age
	if left <= 0.0:
		return 0.0
	return clampf(left / FADE_SECONDS, 0.0, 1.0)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	for index: int in _lines.size():
		var line: Dictionary = _lines[index]
		var alpha: float = line_alpha(line["age"] as float, _line_seconds)
		var speaker: String = "%s: " % line["speaker"]
		var speaker_width: float = (
			font.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		)
		var base: Vector2 = Vector2(LEFT, TOP + LINE_HEIGHT * index)
		for pass_index: int in 2:
			var shadow: bool = pass_index == 0
			var offset: Vector2 = Vector2(2.0, 2.0) if shadow else Vector2.ZERO
			draw_string(
				font,
				base + offset,
				speaker,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				FONT_SIZE,
				(
					Color(COLOR_OUTLINE, COLOR_OUTLINE.a * alpha)
					if shadow
					else Color(COLOR_SPEAKER, alpha)
				)
			)
			draw_string(
				font,
				base + Vector2(speaker_width, 0.0) + offset,
				line["text"] as String,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				FONT_SIZE,
				(
					Color(COLOR_OUTLINE, COLOR_OUTLINE.a * alpha)
					if shadow
					else Color(COLOR_TEXT, alpha)
				)
			)
