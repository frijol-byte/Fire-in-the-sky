class_name FlightHud
extends Control
## Flight HUD v0 (art bible 7: minimal modern). Bottom center: speed, flight assist and boost
## state, and the energy bar. In the view: a ring where the nose points and a flight-path marker
## where the ship is actually going. With flight assist on the two sit together; drifting (FA off)
## pulls them apart, which is how you read your momentum. The same HUD is later drawn on the
## cockpit's holo plane, so it only needs a camera, not a particular view.

const NOSE_RADIUS: float = 11.0
const VELOCITY_RADIUS: float = 18.0
const EDGE_MARGIN: float = 56.0
const LINE_WIDTH: float = 2.0
const BAR_WIDTH: float = 480.0
const BAR_HEIGHT: float = 8.0
const BAR_BOTTOM_OFFSET: float = 92.0
## How long "BOOST EMPTY" shows after the capacitor runs dry.
const DEPLETED_SECONDS: float = 1.5
const COLOR_MAIN: Color = Color(0.92, 0.96, 1.0, 0.95)
const COLOR_VELOCITY: Color = Color(0.4, 1.0, 0.85, 0.95)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.55)
const COLOR_WARN: Color = Color(1.0, 0.45, 0.25, 1.0)
const COLOR_BAR_BACK: Color = Color(1.0, 1.0, 1.0, 0.18)

var ship: Ship = null

var _depleted_left: float = 0.0

@onready var _speed: Label = $Speed
@onready var _state: Label = $State
@onready var _energy: Label = $Energy


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.boost_depleted.connect(_on_boost_depleted)


## Shows the flight data of `new_ship`.
func bind(new_ship: Ship) -> void:
	ship = new_ship
	_refresh()


func _process(delta: float) -> void:
	_depleted_left = maxf(_depleted_left - delta, 0.0)
	_refresh()
	queue_redraw()


func _draw() -> void:
	if ship == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin: Vector3 = ship.global_position
	var nose: HudMath.Marker = HudMath.marker_for(
		camera, origin, -ship.global_basis.z, size, EDGE_MARGIN
	)
	if nose.on_screen:
		draw_arc(nose.position, NOSE_RADIUS, 0.0, TAU, 32, COLOR_OUTLINE, LINE_WIDTH + 3.0, true)
		draw_arc(nose.position, NOSE_RADIUS, 0.0, TAU, 32, COLOR_MAIN, LINE_WIDTH, true)
		draw_circle(nose.position, 2.0, COLOR_MAIN)
	if ship.linear_velocity.length() >= HudMath.MIN_MARKER_SPEED:
		var velocity: HudMath.Marker = HudMath.marker_for(
			camera, origin, ship.linear_velocity, size, EDGE_MARGIN
		)
		_draw_velocity_marker(velocity)
	_draw_energy_bar()


## The flight path marker: a ring with a wing on each side and a fin on top. Pinned to the screen
## edge and dimmed when the ship is going somewhere you cannot see.
func _draw_velocity_marker(marker: HudMath.Marker) -> void:
	var color: Color = COLOR_VELOCITY if marker.on_screen else COLOR_VELOCITY * Color(1, 1, 1, 0.55)
	var center: Vector2 = marker.position
	var radius: float = VELOCITY_RADIUS
	var strokes: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-radius, 0.0), Vector2(-radius * 2.0, 0.0)]),
		PackedVector2Array([Vector2(radius, 0.0), Vector2(radius * 2.0, 0.0)]),
		PackedVector2Array([Vector2(0.0, -radius), Vector2(0.0, -radius * 1.8)]),
	]
	# A dark outline first, so the marker stays readable on a bright background.
	draw_arc(center, radius, 0.0, TAU, 32, COLOR_OUTLINE, LINE_WIDTH + 3.0, true)
	for stroke: PackedVector2Array in strokes:
		draw_line(center + stroke[0], center + stroke[1], COLOR_OUTLINE, LINE_WIDTH + 3.0)
	draw_arc(center, radius, 0.0, TAU, 32, color, LINE_WIDTH, true)
	for stroke: PackedVector2Array in strokes:
		draw_line(center + stroke[0], center + stroke[1], color, LINE_WIDTH)


func _draw_energy_bar() -> void:
	var fraction: float = clampf(ship.power().fraction(), 0.0, 1.0)
	var left: float = (size.x - BAR_WIDTH) * 0.5
	var top: float = size.y - BAR_BOTTOM_OFFSET
	draw_rect(Rect2(left, top, BAR_WIDTH, BAR_HEIGHT), COLOR_BAR_BACK)
	var boost_ready: float = ship.def.boost_min_energy / ship.power().capacity
	var color: Color = COLOR_MAIN if fraction >= boost_ready else COLOR_WARN
	draw_rect(Rect2(left, top, BAR_WIDTH * fraction, BAR_HEIGHT), color)
	# A tick at the energy needed to start a boost.
	var tick_x: float = left + BAR_WIDTH * boost_ready
	draw_line(Vector2(tick_x, top - 4.0), Vector2(tick_x, top + BAR_HEIGHT + 4.0), COLOR_MAIN, 1.0)


func _refresh() -> void:
	if ship == null:
		return
	var power: PowerSystem = ship.power()
	_speed.text = speed_text(ship.linear_velocity.length())
	var fa_off: bool = ship.controls.fa_off
	var boost: HudMath.BoostState = HudMath.boost_state(
		ship.is_boosting(), _depleted_left > 0.0, power.energy, ship.def.boost_min_energy
	)
	_state.text = state_text(fa_off, boost)
	var warn: bool = fa_off or boost == HudMath.BoostState.EMPTY
	_state.add_theme_color_override("font_color", COLOR_WARN if warn else COLOR_MAIN)
	_energy.text = energy_text(power.energy, power.capacity)


func _on_boost_depleted(depleted_ship: Node) -> void:
	if depleted_ship == ship:
		_depleted_left = DEPLETED_SECONDS


## "184 m/s".
static func speed_text(speed: float) -> String:
	return TranslationServer.translate("HUD_SPEED") % speed


## "FA ON   BOOST READY".
static func state_text(fa_off: bool, boost: HudMath.BoostState) -> String:
	return (
		TranslationServer.translate(HudMath.assist_key(fa_off))
		+ "     "
		+ TranslationServer.translate(HudMath.boost_key(boost))
	)


## "ENERGY 72".
static func energy_text(energy: float, capacity: float) -> String:
	var percent: float = 100.0 * energy / capacity if capacity > 0.0 else 0.0
	return TranslationServer.translate("HUD_ENERGY") % percent
