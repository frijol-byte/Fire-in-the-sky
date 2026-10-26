class_name FeedbackHud
extends Control
## The combat feedback layer of the flight HUD (GDD 7.4, M2-T7): hit markers where the nose points
## (a different look for a shield, armor, hull hit and a kill), damage-direction indicators on a ring
## around the screen (where the shot came from, coloured by the layer it hurt), the ship's own
## shield / armor / hull bars, the low-shield alarm, the kill banner and a banner line for the
## scene ("WAVE 2"). It is a child of `FlightHud`; `HitFeedback` plays the sounds and the shake.
## `FeedbackMath` decides, this draws. Numbers are in `data/combat/feedback_default.tres`.

const EDGE_MARGIN: float = 56.0
const BAR_LEFT: float = 56.0
const BAR_BOTTOM: float = 270.0
const BAR_WIDTH: float = 230.0
const BAR_HEIGHT: float = 10.0
const BAR_SPACING: float = 30.0
const LABEL_FONT_SIZE: int = 17
const BANNER_FONT_SIZE: int = 38
const KILL_FONT_SIZE: int = 30
const ALARM_FONT_SIZE: int = 30
const BANNER_TOP: float = 300.0
const BANNER_FADE_SECONDS: float = 0.6
## Hit marker geometry: distance of the ticks from the centre, then length and thickness per kind.
const MARKER_GAP: float = 13.0
const MARKER_GROW: float = 9.0
const MARKER_LENGTH: Array[float] = [8.0, 12.0, 16.0, 24.0]
const MARKER_WIDTH: Array[float] = [2.0, 3.0, 4.5, 5.0]
const COLOR_MARKER: Array[Color] = [
	Color(0.45, 0.9, 1.0), Color(1.0, 0.78, 0.3), Color(1.0, 0.95, 0.9), Color(1.0, 0.25, 0.2)
]
## Damage indicator ring: radius as a fraction of the shorter screen side, arc width and thickness.
const RING_FRACTION: float = 0.31
const RING_HALF_ARC: float = 0.32
const RING_THICKNESS: float = 12.0
const COLOR_LAYER: Array[Color] = [
	Color(0.4, 0.85, 1.0), Color(1.0, 0.75, 0.3), Color(1.0, 0.3, 0.25)
]
const COLOR_TEXT: Color = Color(0.92, 0.96, 1.0, 0.95)
const COLOR_WARN: Color = Color(1.0, 0.3, 0.22, 1.0)
const COLOR_KILL: Color = Color(1.0, 0.35, 0.28, 1.0)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.6)
const COLOR_BAR_BACK: Color = Color(1.0, 1.0, 1.0, 0.18)
const COLOR_HULL: Color = Color(0.95, 0.95, 0.95, 0.95)
const ALARM_FLASH_HZ: float = 2.5
const VIGNETTE_WIDTH: float = 22.0

var ship: Ship = null
var def: FeedbackDef = null

## Hit markers: {kind, age}. Indicators: {direction (world), layer, age}.
var _markers: Array[Dictionary] = []
var _indicators: Array[Dictionary] = []
var _kill_text: String = ""
var _kill_age: float = INF
var _banner_text: String = ""
var _banner_age: float = INF
var _banner_seconds: float = 0.0
var _alarm: bool = false
var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	def = Content.feedback()
	Events.ship_damaged.connect(_on_ship_damaged)
	Events.ship_destroyed.connect(_on_ship_destroyed)


func _exit_tree() -> void:
	if Events.ship_damaged.is_connected(_on_ship_damaged):
		Events.ship_damaged.disconnect(_on_ship_damaged)
	if Events.ship_destroyed.is_connected(_on_ship_destroyed):
		Events.ship_destroyed.disconnect(_on_ship_destroyed)


## Shows the status and feedback of `new_ship`. Old markers and indicators are forgotten.
func bind(new_ship: Ship) -> void:
	ship = new_ship
	_markers.clear()
	_indicators.clear()
	_kill_age = INF
	_alarm = false


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


## Ages everything by `delta` seconds and re-checks the alarm. `_process` calls it; tests too.
func advance(delta: float) -> void:
	_clock += delta
	_kill_age += delta
	_banner_age += delta
	_age_list(_markers, delta, def.kill_marker_seconds)
	_age_list(_indicators, delta, def.indicator_seconds)
	if ship != null and is_instance_valid(ship):
		var durability: Durability = ship.durability()
		_alarm = (
			not durability.is_destroyed()
			and FeedbackMath.alarm_on(
				_alarm, durability.shield_fraction(), durability.shield_capacity, def
			)
		)
	else:
		_alarm = false


## Puts a line of text up at the top of the view for `seconds` ("WAVE 2: 2 pirates").
func show_banner(text: String, seconds: float) -> void:
	_banner_text = text
	_banner_seconds = seconds
	_banner_age = 0.0


func marker_count() -> int:
	return _markers.size()


## The `FeedbackMath.Marker` of the newest hit marker, or -1.
func last_marker() -> int:
	return -1 if _markers.is_empty() else _markers[-1]["kind"] as int


func indicator_count() -> int:
	return _indicators.size()


func is_alarming() -> bool:
	return _alarm


func banner_text() -> String:
	return _banner_text if _banner_age < _banner_seconds else ""


## The kill banner's text while it is up, else empty.
func kill_text() -> String:
	return _kill_text if _kill_age < def.kill_banner_seconds else ""


func _age_list(list: Array[Dictionary], delta: float, lifetime: float) -> void:
	for entry: Dictionary in list:
		entry["age"] = (entry["age"] as float) + delta
	var keep: Array[Dictionary] = []
	for entry: Dictionary in list:
		var limit: float = lifetime
		if entry.has("kind") and (entry["kind"] as int) != FeedbackMath.Marker.KILL:
			limit = def.hit_marker_seconds
		if (entry["age"] as float) < limit:
			keep.append(entry)
	list.assign(keep)


func _on_ship_damaged(node: Node, info: DamageInfo, result: DamageResult) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	if node == ship:
		var direction: Vector3 = FeedbackMath.attacker_direction(ship.global_position, info)
		if direction != Vector3.ZERO:
			_indicators.append(
				{"direction": direction, "layer": maxi(result.deepest_layer(), 0), "age": 0.0}
			)
			while _indicators.size() > def.max_indicators:
				_indicators.remove_at(0)
	elif info.source == ship:
		_markers.append({"kind": FeedbackMath.marker_for(result), "age": 0.0})
		while _markers.size() > 4:
			_markers.remove_at(0)


func _on_ship_destroyed(node: Node, info: DamageInfo) -> void:
	if ship == null or node == ship or info.source != ship:
		return
	var killed: String = node.name
	if node.has_method(&"target_name"):
		killed = node.call(&"target_name") as String
	_kill_text = tr("HUD_KILL") % killed
	_kill_age = 0.0


func _draw() -> void:
	if ship == null or not is_instance_valid(ship) or not ship.is_inside_tree():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	_draw_status_bars()
	if camera == null:
		return
	_draw_indicators(camera)
	_draw_markers(camera)
	_draw_alarm()
	_draw_banners()


func _draw_status_bars() -> void:
	var durability: Durability = ship.durability()
	var rows: Array = [
		[
			"HUD_SHIELD",
			durability.shield_fraction(),
			COLOR_LAYER[0],
			durability.shield_capacity > 0.0
		],
		["HUD_ARMOR", durability.armor_fraction(), COLOR_LAYER[1], durability.armor_capacity > 0.0],
		["HUD_HULL", durability.hull_fraction(), COLOR_HULL, true],
	]
	var font: Font = get_theme_default_font()
	var top: float = size.y - BAR_BOTTOM
	var row: int = 0
	for entry: Array in rows:
		if not (entry[3] as bool):
			continue
		var y: float = top + BAR_SPACING * row
		row += 1
		var fraction: float = clampf(entry[1] as float, 0.0, 1.0)
		var color: Color = entry[2] as Color
		if entry[0] == "HUD_HULL" and fraction < 0.25:
			color = COLOR_WARN
		if entry[0] == "HUD_SHIELD" and _alarm and fmod(_clock * ALARM_FLASH_HZ, 1.0) < 0.5:
			color = COLOR_WARN
		draw_string(
			font,
			Vector2(BAR_LEFT, y + BAR_HEIGHT),
			tr(entry[0] as String),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			LABEL_FONT_SIZE,
			COLOR_TEXT
		)
		var left: float = BAR_LEFT + 82.0
		draw_rect(Rect2(left, y, BAR_WIDTH, BAR_HEIGHT), COLOR_BAR_BACK)
		draw_rect(Rect2(left, y, BAR_WIDTH * fraction, BAR_HEIGHT), color)


func _draw_markers(camera: Camera3D) -> void:
	var drawn: Transform3D = ship.get_global_transform_interpolated()
	var nose: HudMath.Marker = HudMath.marker_for(
		camera, drawn.origin, -drawn.basis.z, size, EDGE_MARGIN
	)
	var center: Vector2 = nose.position if nose.on_screen else size * 0.5
	for entry: Dictionary in _markers:
		var kind: int = entry["kind"] as int
		var lifetime: float = (
			def.kill_marker_seconds if kind == FeedbackMath.Marker.KILL else def.hit_marker_seconds
		)
		var strength: float = FeedbackMath.fade(entry["age"] as float, lifetime)
		var color: Color = COLOR_MARKER[kind]
		color.a = strength
		var shade: Color = Color(COLOR_OUTLINE, COLOR_OUTLINE.a * strength)
		var gap: float = MARKER_GAP + MARKER_GROW * (1.0 - strength)
		var length: float = MARKER_LENGTH[kind]
		var width: float = MARKER_WIDTH[kind]
		var directions: Array[Vector2] = [
			Vector2(1, 1).normalized(),
			Vector2(-1, 1).normalized(),
			Vector2(1, -1).normalized(),
			Vector2(-1, -1).normalized()
		]
		if kind == FeedbackMath.Marker.KILL:
			directions.append_array([Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN])
		for direction: Vector2 in directions:
			var start: Vector2 = center + direction * gap
			var end: Vector2 = center + direction * (gap + length)
			draw_line(start, end, shade, width + 3.0)
			draw_line(start, end, color, width)
		if kind == FeedbackMath.Marker.HULL:
			draw_circle(center, 2.5, color)


func _draw_indicators(camera: Camera3D) -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * RING_FRACTION
	var inverse: Basis = camera.global_basis.orthonormalized().inverse()
	for entry: Dictionary in _indicators:
		var strength: float = FeedbackMath.fade(entry["age"] as float, def.indicator_seconds)
		var angle: float = FeedbackMath.direction_angle(inverse * (entry["direction"] as Vector3))
		var color: Color = COLOR_LAYER[entry["layer"] as int]
		color.a = strength
		# `angle` is 0 at the top and clockwise; Godot's arcs start at +X and also run clockwise.
		var start: float = angle - PI * 0.5
		draw_arc(
			center,
			radius,
			start - RING_HALF_ARC,
			start + RING_HALF_ARC,
			16,
			Color(COLOR_OUTLINE, COLOR_OUTLINE.a * strength),
			RING_THICKNESS + 4.0,
			true
		)
		draw_arc(
			center,
			radius,
			start - RING_HALF_ARC,
			start + RING_HALF_ARC,
			16,
			color,
			RING_THICKNESS,
			true
		)
		# A chevron on the ring pointing at where the shot came from.
		var tip: Vector2 = center + Vector2.from_angle(start) * (radius + RING_THICKNESS + 14.0)
		var back: Vector2 = Vector2.from_angle(start) * 14.0
		var side: Vector2 = Vector2.from_angle(start + PI * 0.5) * 9.0
		draw_colored_polygon(PackedVector2Array([tip, tip - back + side, tip - back - side]), color)


func _draw_alarm() -> void:
	if not _alarm:
		return
	var lit: bool = fmod(_clock * ALARM_FLASH_HZ, 1.0) < 0.5
	var edge: Color = Color(COLOR_WARN, 0.32 if lit else 0.12)
	draw_rect(Rect2(0.0, 0.0, size.x, VIGNETTE_WIDTH), edge)
	draw_rect(Rect2(0.0, size.y - VIGNETTE_WIDTH, size.x, VIGNETTE_WIDTH), edge)
	draw_rect(Rect2(0.0, 0.0, VIGNETTE_WIDTH, size.y), edge)
	draw_rect(Rect2(size.x - VIGNETTE_WIDTH, 0.0, VIGNETTE_WIDTH, size.y), edge)
	var font: Font = get_theme_default_font()
	var color: Color = COLOR_WARN if lit else Color(COLOR_WARN, 0.5)
	var warning: String = tr("HUD_LOW_SHIELD")
	var base: Vector2 = Vector2(BAR_LEFT, size.y - BAR_BOTTOM - 14.0)
	draw_string(
		font,
		base + Vector2(2.0, 2.0),
		warning,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		ALARM_FONT_SIZE,
		COLOR_OUTLINE
	)
	draw_string(font, base, warning, HORIZONTAL_ALIGNMENT_LEFT, -1, ALARM_FONT_SIZE, color)


func _draw_banners() -> void:
	if _banner_age < _banner_seconds:
		var fade: float = clampf((_banner_seconds - _banner_age) / BANNER_FADE_SECONDS, 0.0, 1.0)
		_draw_centered(_banner_text, BANNER_TOP, BANNER_FONT_SIZE, Color(COLOR_TEXT, fade))
	if _kill_age < def.kill_banner_seconds:
		var fade: float = FeedbackMath.fade(_kill_age, def.kill_banner_seconds)
		_draw_centered(
			_kill_text,
			size.y * 0.5 - 120.0,
			KILL_FONT_SIZE,
			Color(COLOR_KILL, minf(fade * 2.0, 1.0))
		)


## Draws `text` centred on the screen's width at baseline `y`, with a drop shadow.
func _draw_centered(text: String, y: float, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left: float = (size.x - width) * 0.5
	draw_string(
		font,
		Vector2(left + 2.0, y + 2.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(COLOR_OUTLINE, COLOR_OUTLINE.a * color.a)
	)
	draw_string(font, Vector2(left, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
