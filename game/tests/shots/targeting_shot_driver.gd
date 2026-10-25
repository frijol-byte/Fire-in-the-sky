extends Node
## Shot driver for targeting: the real flight arena with the player's ship at the start, running a
## script of pilot commands. The ship taps "target nearest hostile", cycles to a dummy sliding along
## its rail (the lead indicator), turns away so the target is off-screen (the edge arrow), holds the
## look-at-target camera, double-taps for the nearest target of any side (a friendly drone) and
## finally flies out of lock range. The arena's own camera and HUD take every shot.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N.

const TAP_FIRST: int = 25
const TAP_CYCLE: int = 70
const TURN_AWAY_FROM: int = 100
const TURN_AWAY_UNTIL: int = 167
const LOOK_HOLD_FROM: int = 200
const LOOK_HOLD_UNTIL: int = 270
const TURN_BACK_FROM: int = 275
const TURN_BACK_UNTIL: int = 342
const DOUBLE_TAP_AT: int = 360
const FLY_OUT_AT: int = 400
## Where the ship is put to leave lock range (the dummies stand 170 to 400 m ahead of the start).
const OUT_OF_RANGE_POSITION: Vector3 = Vector3(0.0, 0.0, 1500.0)

var _tick: int = 0
var _placed: bool = false

@onready var arena: FlightTest = $"../Arena"


func _exit_tree() -> void:
	Input.action_release("look_at_target")
	Settings.values.clear()


func _physics_process(_delta: float) -> void:
	if arena.ship == null:
		return
	if not _placed:
		_place_ship()
	_tick += 1
	arena.ship.controls = controls_for_tick(_tick)
	if _tick == LOOK_HOLD_FROM:
		Input.action_press("look_at_target")
	if _tick == LOOK_HOLD_UNTIL:
		Input.action_release("look_at_target")
	if _tick == FLY_OUT_AT:
		arena.ship.global_position = OUT_OF_RANGE_POSITION


## The scripted controls for physics tick `tick` (1-based).
static func controls_for_tick(tick: int) -> ShipControls:
	var controls: ShipControls = ShipControls.new()
	if tick == TAP_FIRST or tick == TAP_CYCLE:
		controls.target_cmd = ShipControls.Target.NEAREST_HOSTILE
	if tick == DOUBLE_TAP_AT:
		controls.target_cmd = ShipControls.Target.NEAREST_ANY
	if tick >= TURN_AWAY_FROM and tick < TURN_AWAY_UNTIL:
		controls.rotate = Vector3(0.0, 1.0, 0.0)
	if tick >= TURN_BACK_FROM and tick < TURN_BACK_UNTIL:
		controls.rotate = Vector3(0.0, -1.0, 0.0)
	return controls


func _place_ship() -> void:
	_placed = true
	for child: Node in arena.ship.get_children():
		if child is PlayerPilot:
			child.queue_free()
