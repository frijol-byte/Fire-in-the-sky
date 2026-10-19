extends Node
## Device detection, glyph lookup and the player's `ShipControls` each physics tick.
##
## The InputMap in project.godot is the single mapping from physical inputs to the actions in
## `ACTIONS`. Each physics tick `build_controls` turns those actions (plus the mouse virtual
## stick) into a `ShipControls`, applying a radial deadzone, a response curve and the invert-Y
## setting. Gameplay reads `controls` and nothing else. The AI fills in the same struct.

## Which kind of device the player used last. Drives button glyphs.
enum Device { KEYBOARD_MOUSE, GAMEPAD }

## Every input action the game defines (see GDD section 5). Tests check these exist.
const ACTIONS: PackedStringArray = [
	"thrust_forward",
	"thrust_back",
	"strafe_left",
	"strafe_right",
	"thrust_up",
	"thrust_down",
	"pitch_up",
	"pitch_down",
	"yaw_left",
	"yaw_right",
	"roll_left",
	"roll_right",
	"fire_primary",
	"fire_secondary",
	"boost",
	"flight_assist_off",
	"target_nearest",
	"interact",
	"device_1",
	"device_2",
	"device_3",
	"cycle_subsystem",
	"cruise_drive",
	"camera_toggle",
	"free_look",
	"pause",
	"system_map",
]

## Settings keys (see `Settings`) and their defaults.
const SETTING_STICK_DEADZONE: String = "controls/stick_deadzone"
const SETTING_CURVE_EXPONENT: String = "controls/curve_exponent"
const SETTING_INVERT_Y: String = "controls/invert_y"
const SETTING_MOUSE_FLIGHT: String = "controls/mouse_flight"
const SETTING_MOUSE_DEADZONE: String = "controls/mouse_deadzone"
const SETTING_MOUSE_RADIUS: String = "controls/mouse_radius"
## When on, holding `free_look` turns the right stick (and the mouse stick) into a camera look
## and the ship keeps flying straight. Off by default because the right stick aims.
const SETTING_FREE_LOOK: String = "camera/free_look"
const DEFAULT_FREE_LOOK: bool = false
const DEFAULT_STICK_DEADZONE: float = 0.15
## 1 is linear, above 1 gives finer control near the center of the stick.
const DEFAULT_CURVE_EXPONENT: float = 1.5
const DEFAULT_INVERT_Y: bool = false
const DEFAULT_MOUSE_FLIGHT: bool = true
## Mouse virtual stick radii as a fraction of the viewport height.
const DEFAULT_MOUSE_DEADZONE: float = 0.03
const DEFAULT_MOUSE_RADIUS: float = 0.35

## A gamepad axis must pass this far from center before it counts as "the player is using a
## gamepad" (so a drifting stick does not flip the glyphs).
const DEVICE_SWITCH_AXIS: float = 0.5
## Two presses of `target_nearest` within this many physics ticks are a double-tap.
const TARGET_DOUBLE_TAP_TICKS: int = 18

const _PAD_BUTTON_GLYPHS: Dictionary[int, StringName] = {
	JOY_BUTTON_A: &"GLYPH_PAD_A",
	JOY_BUTTON_B: &"GLYPH_PAD_B",
	JOY_BUTTON_X: &"GLYPH_PAD_X",
	JOY_BUTTON_Y: &"GLYPH_PAD_Y",
	JOY_BUTTON_BACK: &"GLYPH_PAD_SELECT",
	JOY_BUTTON_START: &"GLYPH_PAD_START",
	JOY_BUTTON_LEFT_STICK: &"GLYPH_PAD_L3",
	JOY_BUTTON_RIGHT_STICK: &"GLYPH_PAD_R3",
	JOY_BUTTON_LEFT_SHOULDER: &"GLYPH_PAD_LB",
	JOY_BUTTON_RIGHT_SHOULDER: &"GLYPH_PAD_RB",
	JOY_BUTTON_DPAD_UP: &"GLYPH_PAD_DPAD_UP",
	JOY_BUTTON_DPAD_DOWN: &"GLYPH_PAD_DPAD_DOWN",
	JOY_BUTTON_DPAD_LEFT: &"GLYPH_PAD_DPAD_LEFT",
	JOY_BUTTON_DPAD_RIGHT: &"GLYPH_PAD_DPAD_RIGHT",
	JOY_BUTTON_PADDLE1: &"GLYPH_PAD_PADDLE_1",
	JOY_BUTTON_PADDLE2: &"GLYPH_PAD_PADDLE_2",
	JOY_BUTTON_PADDLE3: &"GLYPH_PAD_PADDLE_3",
}

## Keys are "<axis index><sign of the axis value>".
const _PAD_AXIS_GLYPHS: Dictionary[String, StringName] = {
	"0-": &"GLYPH_PAD_LS_LEFT",
	"0+": &"GLYPH_PAD_LS_RIGHT",
	"1-": &"GLYPH_PAD_LS_UP",
	"1+": &"GLYPH_PAD_LS_DOWN",
	"2-": &"GLYPH_PAD_RS_LEFT",
	"2+": &"GLYPH_PAD_RS_RIGHT",
	"3-": &"GLYPH_PAD_RS_UP",
	"3+": &"GLYPH_PAD_RS_DOWN",
	"4+": &"GLYPH_PAD_LT",
	"5+": &"GLYPH_PAD_RT",
}

const _MOUSE_BUTTON_GLYPHS: Dictionary[int, StringName] = {
	MOUSE_BUTTON_LEFT: &"GLYPH_MOUSE_LEFT",
	MOUSE_BUTTON_RIGHT: &"GLYPH_MOUSE_RIGHT",
	MOUSE_BUTTON_MIDDLE: &"GLYPH_MOUSE_MIDDLE",
}

## The kind of device the player used last. Updated from `_input`.
var last_device: Device = Device.KEYBOARD_MOUSE

## The player's controls for the current physics tick. Replaced every tick, so a reference
## you keep is a snapshot.
var controls: ShipControls = ShipControls.new()

var _mouse_seen: bool = false
var _ticks_since_target_press: int = 1 << 30


func _input(event: InputEvent) -> void:
	observe_event(event)


func _physics_process(_delta: float) -> void:
	controls = build_controls()


## Builds this tick's `ShipControls` from the InputMap and the mouse virtual stick.
func build_controls() -> ShipControls:
	var c: ShipControls = ShipControls.new()
	var deadzone: float = float(Settings.get_value(SETTING_STICK_DEADZONE, DEFAULT_STICK_DEADZONE))
	var exponent: float = float(Settings.get_value(SETTING_CURVE_EXPONENT, DEFAULT_CURVE_EXPONENT))
	var invert_y: bool = bool(Settings.get_value(SETTING_INVERT_Y, DEFAULT_INVERT_Y))

	var move: Vector2 = shape_stick(
		Vector2(_axis("strafe_left", "strafe_right"), _axis("thrust_back", "thrust_forward")),
		deadzone,
		exponent
	)
	var vertical: float = shape_axis(_axis("thrust_down", "thrust_up"), deadzone, exponent)
	c.thrust = Vector3(move.x, vertical, move.y)

	var look: Vector2 = Vector2.ZERO if free_look_active() else look_input()
	var roll: float = shape_axis(_axis("roll_left", "roll_right"), deadzone, exponent)
	c.rotate = Vector3(-look.y if invert_y else look.y, look.x, roll)

	c.boost = Input.is_action_pressed("boost")
	c.fa_off = Input.is_action_pressed("flight_assist_off")
	c.fire_primary = Input.is_action_pressed("fire_primary")
	c.fire_secondary = Input.is_action_pressed("fire_secondary")
	c.interact = Input.is_action_just_pressed("interact")
	c.device = _device_slot_pressed()
	c.target_cmd = _target_command()
	return c


## The aim input as (yaw, pitch) in -1..1, pitch up positive: the right stick plus the mouse
## virtual stick, shaped like every other stick. Before the invert-Y setting.
func look_input() -> Vector2:
	var deadzone: float = float(Settings.get_value(SETTING_STICK_DEADZONE, DEFAULT_STICK_DEADZONE))
	var exponent: float = float(Settings.get_value(SETTING_CURVE_EXPONENT, DEFAULT_CURVE_EXPONENT))
	var look: Vector2 = shape_stick(
		Vector2(_axis("yaw_left", "yaw_right"), _axis("pitch_down", "pitch_up")), deadzone, exponent
	)
	look += _mouse_look(exponent)
	return look.clamp(-Vector2.ONE, Vector2.ONE)


## True while the player holds `free_look` and the free-look setting is on. The ship then
## ignores the aim input (see `build_controls`) and the camera uses it (`free_look_vector`).
func free_look_active() -> bool:
	return (
		bool(Settings.get_value(SETTING_FREE_LOOK, DEFAULT_FREE_LOOK))
		and Input.is_action_pressed("free_look")
	)


## The camera look for this frame as (yaw, pitch) in -1..1 (right and up positive, invert-Y
## applied), or zero when free look is not active.
func free_look_vector() -> Vector2:
	if not free_look_active():
		return Vector2.ZERO
	var look: Vector2 = look_input()
	if bool(Settings.get_value(SETTING_INVERT_Y, DEFAULT_INVERT_Y)):
		look.y = -look.y
	return look


## Notes which device `event` came from. Call it for every input event; it emits
## `Events.input_device_changed` when the player switches between gamepad and keyboard/mouse.
func observe_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = true
	var device: int = event_device(event)
	if device < 0 or device == last_device:
		return
	last_device = device as Device
	Log.info("input", "device changed to %s" % Device.keys()[device])
	Events.input_device_changed.emit(device)


## Returns the `Device` that produced `event`, or -1 if the event is not a deliberate input
## (a small stick wobble, a mouse motion of zero distance, a release).
static func event_device(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		return Device.GAMEPAD if (event as InputEventJoypadButton).pressed else -1
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		return Device.GAMEPAD if absf(motion.axis_value) >= DEVICE_SWITCH_AXIS else -1
	if event is InputEventKey:
		return Device.KEYBOARD_MOUSE if (event as InputEventKey).pressed else -1
	if event is InputEventMouseButton:
		return Device.KEYBOARD_MOUSE if (event as InputEventMouseButton).pressed else -1
	if event is InputEventMouseMotion:
		var mouse: InputEventMouseMotion = event
		return Device.KEYBOARD_MOUSE if mouse.relative != Vector2.ZERO else -1
	return -1


## Applies a radial deadzone to a stick: inside `deadzone` the result is zero, and from there
## the magnitude is rescaled so the deadzone edge maps to 0 and full deflection to 1.
## Magnitudes above 1 (two keyboard keys at once) are kept, so a diagonal still reaches 1 on
## both axes after `shape_stick` clamps them.
static func apply_radial_deadzone(stick: Vector2, deadzone: float) -> Vector2:
	var magnitude: float = stick.length()
	if magnitude <= deadzone or magnitude == 0.0:
		return Vector2.ZERO
	var rescaled: float = (magnitude - deadzone) / (1.0 - deadzone)
	return stick / magnitude * rescaled


## Applies the response curve to a stick: the magnitude is raised to `exponent`, the
## direction is kept. An exponent of 1 changes nothing.
static func apply_curve(stick: Vector2, exponent: float) -> Vector2:
	var magnitude: float = stick.length()
	if magnitude == 0.0:
		return Vector2.ZERO
	return stick / magnitude * pow(magnitude, exponent)


## Radial deadzone, then response curve, then each axis clamped to -1..1.
static func shape_stick(stick: Vector2, deadzone: float, exponent: float) -> Vector2:
	var shaped: Vector2 = apply_curve(apply_radial_deadzone(stick, deadzone), exponent)
	return shaped.clamp(-Vector2.ONE, Vector2.ONE)


## Deadzone and response curve for a single axis (vertical thrust, roll), clamped to -1..1.
static func shape_axis(value: float, deadzone: float, exponent: float) -> float:
	return shape_stick(Vector2(value, 0.0), deadzone, exponent).x


## Maps the mouse offset from screen center to a virtual stick. `offset` and the two radii
## are in pixels; the result has x to the right and y downward, magnitude 0..1: zero inside
## `deadzone_px`, 1 at `max_radius_px` and beyond, proportional (then curved) in between.
static func mouse_stick(
	offset: Vector2, deadzone_px: float, max_radius_px: float, exponent: float = 1.0
) -> Vector2:
	var distance: float = offset.length()
	if max_radius_px <= deadzone_px or distance <= deadzone_px:
		return Vector2.ZERO
	var magnitude: float = clampf(
		(distance - deadzone_px) / (max_radius_px - deadzone_px), 0.0, 1.0
	)
	return offset / distance * pow(magnitude, exponent)


## Returns the command for a `target_nearest` press that comes `ticks_since_last_press` ticks
## after the previous one: a double-tap targets the nearest ship of any kind.
static func resolve_target_tap(ticks_since_last_press: int, window_ticks: int) -> int:
	if ticks_since_last_press <= window_ticks:
		return ShipControls.Target.NEAREST_ANY
	return ShipControls.Target.NEAREST_HOSTILE


## Returns short text for the physical input bound to `action`, for the given `device`
## (a `Device`, or -1 for the device used last): "RT", "LMB", "Space"... Returns "" for an
## unknown or unbound action. Placeholder text until the glyph art exists.
func glyph_for(action: StringName, device: int = -1) -> String:
	var wanted: int = last_device if device < 0 else device
	if not InputMap.has_action(action):
		return ""
	var mouse_steered: bool = action in [&"pitch_up", &"pitch_down", &"yaw_left", &"yaw_right"]
	if mouse_steered and wanted == Device.KEYBOARD_MOUSE:
		return tr("GLYPH_MOUSE_MOVE")
	for event: InputEvent in InputMap.action_get_events(action):
		var key: StringName = &""
		if wanted == Device.GAMEPAD:
			key = _pad_glyph_key(event)
		elif event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
		elif event is InputEventMouseButton:
			key = _MOUSE_BUTTON_GLYPHS.get((event as InputEventMouseButton).button_index, &"")
		if not key.is_empty():
			return tr(key)
	return tr("GLYPH_UNBOUND")


func _pad_glyph_key(event: InputEvent) -> StringName:
	if event is InputEventJoypadButton:
		return _PAD_BUTTON_GLYPHS.get((event as InputEventJoypadButton).button_index, &"")
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		var sign_char: String = "+" if motion.axis_value > 0.0 else "-"
		return _PAD_AXIS_GLYPHS.get("%d%s" % [motion.axis, sign_char], &"")
	return &""


## Strength of `positive` minus `negative`, ignoring the action deadzone (we apply our own).
func _axis(negative: StringName, positive: StringName) -> float:
	return Input.get_action_raw_strength(positive) - Input.get_action_raw_strength(negative)


## The mouse virtual stick as (yaw, pitch) in -1..1. Zero until the mouse has moved, when the
## player last used the gamepad, or when mouse flight is off.
func _mouse_look(exponent: float) -> Vector2:
	if not bool(Settings.get_value(SETTING_MOUSE_FLIGHT, DEFAULT_MOUSE_FLIGHT)):
		return Vector2.ZERO
	if not _mouse_seen or last_device != Device.KEYBOARD_MOUSE:
		return Vector2.ZERO
	var viewport: Viewport = get_viewport()
	var size: Vector2 = viewport.get_visible_rect().size
	var offset: Vector2 = viewport.get_mouse_position() - size * 0.5
	var deadzone: float = float(Settings.get_value(SETTING_MOUSE_DEADZONE, DEFAULT_MOUSE_DEADZONE))
	var radius: float = float(Settings.get_value(SETTING_MOUSE_RADIUS, DEFAULT_MOUSE_RADIUS))
	var stick: Vector2 = mouse_stick(offset, deadzone * size.y, radius * size.y, exponent)
	return Vector2(stick.x, -stick.y)


func _device_slot_pressed() -> int:
	if Input.is_action_just_pressed("device_1"):
		return 1
	if Input.is_action_just_pressed("device_2"):
		return 2
	if Input.is_action_just_pressed("device_3"):
		return 3
	return 0


func _target_command() -> int:
	_ticks_since_target_press = mini(_ticks_since_target_press + 1, 1 << 30)
	if Input.is_action_just_pressed("target_nearest"):
		var command: int = resolve_target_tap(_ticks_since_target_press, TARGET_DOUBLE_TAP_TICKS)
		# After a double-tap, the next press starts a new pair.
		_ticks_since_target_press = 1 << 30 if command == ShipControls.Target.NEAREST_ANY else 0
		return command
	if Input.is_action_just_pressed("cycle_subsystem"):
		return ShipControls.Target.CYCLE_SUBSYSTEM
	return ShipControls.Target.NONE
