extends Node
## Shot driver for the ship switcher: the real arena scene, the player's pilot swapped for a
## script. The Kestrel cruises, then the Bulwark and the Drayman are picked with the device slots'
## own code path (`FlightTest.spawn_player`), each flying the same scripted line so the chase
## cameras can be compared. Shot frame N is physics tick 2N (see `arena_shot_driver.gd`).

const SWITCH_TICKS: Dictionary[int, StringName] = {160: &"bulwark", 320: &"drayman"}
const CRUISE_START: int = 20

var _tick: int = 0
var _started_at: int = 0

@onready var arena: FlightTest = $"../Arena"


func _exit_tree() -> void:
	Settings.values.clear()


func _physics_process(_delta: float) -> void:
	var ship: Ship = arena.ship
	if ship == null:
		return
	_tick += 1
	if SWITCH_TICKS.has(_tick):
		ship = arena.spawn_player(SWITCH_TICKS[_tick])
		_started_at = _tick
	for child: Node in ship.get_children():
		if child is PlayerPilot:
			child.queue_free()
	var controls: ShipControls = ShipControls.new()
	if _tick - _started_at >= CRUISE_START:
		controls.thrust = Vector3(0.0, 0.0, 1.0)
		controls.rotate = Vector3(0.0, 0.15, 0.0)
	ship.controls = controls
