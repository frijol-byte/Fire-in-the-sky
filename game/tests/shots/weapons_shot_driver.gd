extends Node
## Shot driver for the weapons: the real flight arena, the player's ship parked 70 m in front of
## the first target dummy, holding the trigger. Used for the Pulse Laser (Kestrel) and the
## Autocannon (Bulwark) shot sequences; the arena's own camera takes every shot.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N.

## Ship to fly (a `ShipDef` id).
@export var ship_id: StringName = &"kestrel"
## Physics tick on which the trigger goes down, and the tick on which it is let go.
@export var fire_from: int = 30
@export var fire_until: int = 400
## Where the ship starts, in front of the first dummy (which stands at z = -220).
@export var start_position: Vector3 = Vector3(0.0, 0.0, -150.0)

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
	var controls: ShipControls = ShipControls.new()
	controls.fire_primary = _tick >= fire_from and _tick < fire_until
	arena.ship.controls = controls


func _place_ship() -> void:
	_placed = true
	if arena.ship.def.id != ship_id:
		arena.spawn_player(ship_id)
	for child: Node in arena.ship.get_children():
		if child is PlayerPilot:
			child.queue_free()
	arena.ship.global_position = start_position
	arena.ship.weapons().seed_spread(3)
