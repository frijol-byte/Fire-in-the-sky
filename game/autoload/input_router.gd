extends Node
## Device detection, glyph set, rebinding, and the player's `ShipControls` each tick.
## Stub: the control mapping lives in project.godot's InputMap (actions listed in
## `ACTIONS`); the `ShipControls` struct arrives with the flight task.

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
	"pause",
	"system_map",
]

var last_device: Device = Device.KEYBOARD_MOUSE


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_device = Device.GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton:
		last_device = Device.KEYBOARD_MOUSE
