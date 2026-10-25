extends Node
## Shot driver for the flight arena: the real arena scene, with the player's pilot swapped for a
## script. The ship sits still at the start, accelerates down the course, boosts, switches to the
## cockpit view and back. The arena's own camera rig takes every shot, so the PNGs show what the
## player sees.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N. The phase lengths below are in ticks.

const CRUISE_START: int = 90
const BOOST_START: int = 200
const COCKPIT_START: int = 420
const CHASE_AGAIN: int = 520
const TURN_START: int = 560

## Pretend the player last used a gamepad, so the help line shows the pad's glyphs.
@export var gamepad_glyphs: bool = false

var _tick: int = 0
var _saved_device: InputRouter.Device = InputRouter.last_device
var _pilot_removed: bool = false

@onready var arena: FlightTest = $"../Arena"


func _ready() -> void:
	if gamepad_glyphs:
		InputRouter.last_device = InputRouter.Device.GAMEPAD
		Events.input_device_changed.emit(InputRouter.Device.GAMEPAD)


func _exit_tree() -> void:
	Settings.values.clear()
	InputRouter.last_device = _saved_device


func _physics_process(_delta: float) -> void:
	var ship: Ship = arena.ship
	if ship == null:
		return
	if not _pilot_removed:
		for child: Node in ship.get_children():
			if child is PlayerPilot:
				child.queue_free()
		_pilot_removed = true
	_tick += 1
	ship.controls = controls_for_tick(_tick)
	var rig: CameraRig = arena.get_node("CameraRig") as CameraRig
	if _tick == COCKPIT_START:
		rig.set_view(CameraRig.View.COCKPIT)
	if _tick == CHASE_AGAIN:
		rig.set_view(CameraRig.View.CHASE)


## The scripted controls for physics tick `tick` (1-based).
static func controls_for_tick(tick: int) -> ShipControls:
	var controls: ShipControls = ShipControls.new()
	if tick < CRUISE_START:
		return controls
	controls.thrust = Vector3(0.0, 0.0, 1.0)
	controls.boost = tick >= BOOST_START and tick < COCKPIT_START + 60
	if tick >= TURN_START:
		controls.rotate = Vector3(0.0, 0.5, 0.0)
	return controls
