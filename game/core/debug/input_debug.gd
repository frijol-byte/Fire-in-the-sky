extends Control
## Debug scene: prints the player's `ShipControls` live, with two stick widgets, so input can
## be checked by eye on any device. With `show_sample` on it shows a fixed sample instead,
## which is what the screenshot shot uses.

const BACKGROUND: Color = Color(0.05, 0.07, 0.12, 1.0)
const RING: Color = Color(0.35, 0.45, 0.6, 1.0)
const DOT: Color = Color(1.0, 0.72, 0.2, 1.0)
const STICK_RADIUS: float = 170.0
const DOT_RADIUS: float = 16.0

## Show `sample_controls()` instead of the live input.
@export var show_sample: bool = false

var _controls: ShipControls = ShipControls.new()

@onready var _readout: Label = %Readout
@onready var _move_center: Control = %MoveStick
@onready var _look_center: Control = %LookStick


func _ready() -> void:
	_move_center.draw.connect(_draw_stick.bind(_move_center, true))
	_look_center.draw.connect(_draw_stick.bind(_look_center, false))


func _process(_delta: float) -> void:
	_controls = sample_controls() if show_sample else InputRouter.controls
	_readout.text = readout_text(_controls, InputRouter.last_device)
	_move_center.queue_redraw()
	_look_center.queue_redraw()


## Returns a fixed, mid-maneuver set of controls for screenshots.
static func sample_controls() -> ShipControls:
	var c: ShipControls = ShipControls.new()
	c.thrust = Vector3(-0.35, 0.0, 0.8)
	c.rotate = Vector3(0.45, 0.6, -0.2)
	c.boost = true
	c.fire_primary = true
	c.target_cmd = ShipControls.Target.NEAREST_HOSTILE
	return c


## Returns the multi-line text shown for `controls`, with button glyphs for `device`.
static func readout_text(controls: ShipControls, device: int) -> String:
	var lines: PackedStringArray = []
	lines.append(TranslationServer.translate("INPUT_DEBUG_DEVICE") % _device_name(device))
	lines.append(
		(
			TranslationServer.translate("INPUT_DEBUG_THRUST")
			% [controls.thrust.x, controls.thrust.y, controls.thrust.z]
		)
	)
	lines.append(
		(
			TranslationServer.translate("INPUT_DEBUG_ROTATE")
			% [controls.rotate.x, controls.rotate.y, controls.rotate.z]
		)
	)
	lines.append(_button_line("boost", controls.boost, device))
	lines.append(_button_line("flight_assist_off", controls.fa_off, device))
	lines.append(_button_line("fire_primary", controls.fire_primary, device))
	lines.append(_button_line("fire_secondary", controls.fire_secondary, device))
	lines.append(
		(
			TranslationServer.translate("INPUT_DEBUG_ONE_SHOT")
			% [controls.device, controls.target_cmd, _on_off(controls.interact)]
		)
	)
	return "\n".join(lines)


static func _device_name(device: int) -> String:
	if device == InputRouter.Device.GAMEPAD:
		return TranslationServer.translate("INPUT_DEVICE_GAMEPAD")
	return TranslationServer.translate("INPUT_DEVICE_KEYBOARD_MOUSE")


static func _on_off(value: bool) -> String:
	return (
		TranslationServer.translate("INPUT_DEBUG_ON")
		if value
		else TranslationServer.translate("INPUT_DEBUG_OFF")
	)


static func _button_line(action: StringName, pressed: bool, device: int) -> String:
	var label: String = TranslationServer.translate(
		"INPUT_DEBUG_ACTION_" + String(action).to_upper()
	)
	return (
		TranslationServer.translate("INPUT_DEBUG_BUTTON")
		% [label, InputRouter.glyph_for(action, device), _on_off(pressed)]
	)


## Draws one stick widget: the ring, the crosshair and a dot at the commanded deflection.
## Move shows strafe (right) and forward (up); look shows yaw (right) and pitch (up).
func _draw_stick(canvas: Control, is_move: bool) -> void:
	var center: Vector2 = canvas.size * 0.5
	var value: Vector2 = Vector2(_controls.thrust.x, _controls.thrust.z)
	if not is_move:
		value = Vector2(_controls.rotate.y, _controls.rotate.x)
	canvas.draw_arc(center, STICK_RADIUS, 0.0, TAU, 64, RING, 3.0)
	canvas.draw_line(
		center - Vector2(STICK_RADIUS, 0.0), center + Vector2(STICK_RADIUS, 0.0), RING, 1.0
	)
	canvas.draw_line(
		center - Vector2(0.0, STICK_RADIUS), center + Vector2(0.0, STICK_RADIUS), RING, 1.0
	)
	canvas.draw_circle(center + Vector2(value.x, -value.y) * STICK_RADIUS, DOT_RADIUS, DOT)
