class_name MissileWarning
extends Control
## The incoming-missile warning (GDD 7.2): while a homing missile is steering at the player's ship,
## a flashing "MISSILE INCOMING" banner with the distance to the nearest one, a marker on that
## missile (pinned to the screen edge when it is out of view, like the target arrows), and an alarm
## whose beeps come faster as the missile closes. A missile that a flare has fooled stops counting.
## It is a child of `FlightHud` and only needs the ship and the current 3D camera.

const EDGE_MARGIN: float = 56.0
const LINE_WIDTH: float = 3.0
const BANNER_TOP: float = 150.0
const BANNER_FONT_SIZE: int = 40
const DISTANCE_FONT_SIZE: int = 24
const MARKER_SIZE: float = 16.0
const ARROW_SIZE: float = 18.0
const FLASH_HZ: float = 3.0
## Seconds between alarm beeps for a missile far away, and for one about to hit.
const BEEP_SLOW: float = 0.9
const BEEP_FAST: float = 0.14
## At or beyond this time to impact the alarm beeps slowly; at or below `NEAR_SECONDS` fast.
const FAR_SECONDS: float = 6.0
const NEAR_SECONDS: float = 0.6
const ALARM_DB: float = -6.0
const SOUND_WARNING: AudioStreamWAV = preload("res://assets/audio/sfx/missile_warning.wav")
const COLOR_WARN: Color = Color(1.0, 0.3, 0.22, 0.95)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.6)
const COLOR_TEXT: Color = Color(0.92, 0.96, 1.0, 0.95)

var ship: Ship = null

var _nearest: Missile = null
var _distance: float = 0.0
var _time_to_impact: float = INF
var _clock: float = 0.0
var _beep_left: float = 0.0
var _alarm: AudioStreamPlayer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alarm = AudioStreamPlayer.new()
	_alarm.name = "Alarm"
	_alarm.stream = SOUND_WARNING
	_alarm.volume_db = ALARM_DB
	# A sound still playing when the node leaves the tree (a scene change, a quit) is reported as
	# a leaked resource; `tree_exiting` fires while stopping it still works.
	_alarm.tree_exiting.connect(_alarm.stop)
	add_child(_alarm)


## Warns about the missiles that hunt `new_ship`.
func bind(new_ship: Ship) -> void:
	ship = new_ship
	_nearest = null
	_beep_left = 0.0


func _process(delta: float) -> void:
	_clock += delta
	_scan()
	if _nearest == null:
		_beep_left = 0.0
	else:
		_beep_left -= delta
		if _beep_left <= 0.0:
			_beep_left = beep_interval(_time_to_impact)
			_alarm.play()
	queue_redraw()


## True while a missile is hunting the ship (the banner is up).
func is_warning() -> bool:
	return _nearest != null


func _draw() -> void:
	if _nearest == null or ship == null or not ship.is_inside_tree():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var lit: bool = flash_on(_clock)
	var color: Color = COLOR_WARN if lit else Color(COLOR_WARN, COLOR_WARN.a * 0.4)
	var font: Font = get_theme_default_font()
	var banner: String = TranslationServer.translate("HUD_MISSILE_INCOMING")
	var width: float = (
		font.get_string_size(banner, HORIZONTAL_ALIGNMENT_CENTER, -1, BANNER_FONT_SIZE).x
	)
	var left: float = (size.x - width) * 0.5
	draw_string(
		font,
		Vector2(left + 2.0, BANNER_TOP + 2.0),
		banner,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		BANNER_FONT_SIZE,
		COLOR_OUTLINE
	)
	draw_string(
		font,
		Vector2(left, BANNER_TOP),
		banner,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		BANNER_FONT_SIZE,
		color
	)
	var distance_label: String = HudMath.distance_text(_distance)
	var distance_width: float = (
		font.get_string_size(distance_label, HORIZONTAL_ALIGNMENT_CENTER, -1, DISTANCE_FONT_SIZE).x
	)
	draw_string(
		font,
		Vector2((size.x - distance_width) * 0.5, BANNER_TOP + 32.0),
		distance_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		DISTANCE_FONT_SIZE,
		COLOR_TEXT
	)
	var drawn: Vector3 = _nearest.drawn_position(Engine.get_physics_interpolation_fraction())
	var marker: HudMath.Marker = HudMath.marker_at(camera, drawn, size, EDGE_MARGIN)
	if marker.on_screen:
		_draw_marker(marker.position, color)
	else:
		var points: PackedVector2Array = HudMath.arrow_points(
			marker.position, marker.position - size * 0.5, ARROW_SIZE
		)
		draw_colored_polygon(points, color)


## A diamond around the missile.
func _draw_marker(center: Vector2, color: Color) -> void:
	var diamond: PackedVector2Array = PackedVector2Array(
		[
			center + Vector2(0.0, -MARKER_SIZE),
			center + Vector2(MARKER_SIZE, 0.0),
			center + Vector2(0.0, MARKER_SIZE),
			center + Vector2(-MARKER_SIZE, 0.0),
			center + Vector2(0.0, -MARKER_SIZE),
		]
	)
	draw_polyline(diamond, COLOR_OUTLINE, LINE_WIDTH + 3.0, true)
	draw_polyline(diamond, color, LINE_WIDTH, true)


## Finds the hunting missile that will arrive first.
func _scan() -> void:
	_nearest = null
	_time_to_impact = INF
	if ship == null or not ship.is_inside_tree():
		return
	var manager: MissileManager = MissileManager.for_node(self)
	if manager == null:
		return
	for incoming: Missile in manager.incoming_for(ship):
		var arrival: float = time_to_impact(
			incoming.position, incoming.velocity, ship.global_position, ship.linear_velocity
		)
		if _nearest == null or arrival < _time_to_impact:
			_nearest = incoming
			_time_to_impact = arrival
	if _nearest != null:
		_distance = _nearest.position.distance_to(ship.global_position)


## Seconds until a missile at `missile_pos` moving at `missile_vel` reaches a ship at `ship_pos`
## moving at `ship_vel`, at their present closing speed. INF when they are not closing.
static func time_to_impact(
	missile_pos: Vector3, missile_vel: Vector3, ship_pos: Vector3, ship_vel: Vector3
) -> float:
	var offset: Vector3 = ship_pos - missile_pos
	var distance: float = offset.length()
	if distance < 0.001:
		return 0.0
	var closing: float = (missile_vel - ship_vel).dot(offset / distance)
	return distance / closing if closing > 0.001 else INF


## Seconds between alarm beeps for a missile `seconds` from impact: slow when it is far, fast when
## it is about to hit.
static func beep_interval(seconds: float) -> float:
	var closeness: float = (
		1.0 - clampf((seconds - NEAR_SECONDS) / (FAR_SECONDS - NEAR_SECONDS), 0.0, 1.0)
	)
	return lerpf(BEEP_SLOW, BEEP_FAST, closeness)


## Whether the flashing banner is lit at `clock` seconds.
static func flash_on(clock: float) -> bool:
	return fposmod(clock * FLASH_HZ, 1.0) < 0.6
