extends Node
## Shot driver for the Homing Missile: the real flight arena with the player's Kestrel at the start,
## the first target dummy selected, the secondary button held until the lock completes and then
## released. The arena's own camera and HUD take every shot: the lock ring filling, LOCK, the launch,
## the missile in flight, the blast and the damaged dummy.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N.

const SELECT_AT: int = 10
const HOLD_FROM: int = 25
const RELEASE_AT: int = 122

var _tick: int = 0
var _placed: bool = false

@onready var arena: FlightTest = $"../Arena"


func _exit_tree() -> void:
	Settings.values.clear()


func _physics_process(_delta: float) -> void:
	if arena.ship == null:
		return
	if not _placed:
		_place_ship()
	_tick += 1
	arena.ship.controls = controls_for_tick(_tick)
	if _tick == SELECT_AT:
		var dummy: Node3D = arena.get_node("Dummies").get_child(0) as Node3D
		arena.ship.targeting().select(dummy)


## The scripted controls for physics tick `tick` (1-based).
static func controls_for_tick(tick: int) -> ShipControls:
	var controls: ShipControls = ShipControls.new()
	controls.fire_secondary = tick >= HOLD_FROM and tick < RELEASE_AT
	return controls


func _place_ship() -> void:
	_placed = true
	for child: Node in arena.ship.get_children():
		if child is PlayerPilot:
			child.queue_free()
