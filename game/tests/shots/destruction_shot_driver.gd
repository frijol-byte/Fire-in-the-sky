extends Node
## Shot driver for destruction (M2-T6): the real flight arena. A pirate hangs still ahead of the
## player's Kestrel and is destroyed at `KILL_TICK`, so the shots follow the explosion, the
## wreck, the debris, the loot containers and the tractor pulling them into the debug wallet.
## With `player_dies` set, the player's own ship is the one that blows up instead, and the shots
## end on the "Ship destroyed" screen.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N.

## The physics tick the victim is destroyed on.
const KILL_TICK: int = 80
## Where the pirate hangs, in the player's ship axes (the camera behind the player sees it).
const PIRATE_OFFSET: Vector3 = Vector3(7.0, 3.0, -60.0)

@export var player_dies: bool = false

var _tick: int = 0
var _placed: bool = false
var _pirate: Ship = null

@onready var arena: FlightTest = $"../Arena"


func _exit_tree() -> void:
	Settings.values.clear()


func _physics_process(_delta: float) -> void:
	if arena.ship == null:
		return
	if not _placed:
		_place()
	_tick += 1
	if _tick == KILL_TICK:
		var victim: Ship = arena.ship if player_dies else _pirate
		victim.durability().apply(
			DamageInfo.make(100000.0, DamageInfo.Type.EXPLOSIVE, arena.ship, victim.global_position)
		)
	# The player sits still: the tractor brings the loot to the ship.
	arena.ship.controls = ShipControls.new()


func _place() -> void:
	_placed = true
	# The player's pilot stays (it also marks the ship as the player's, which the tractor needs); this
	# driver runs after it each tick and overwrites the controls it wrote.
	# The arena's dummies are hostile: keep them out of the way of the picture.
	for dummy: Node in arena.get_node("Dummies").get_children():
		(dummy as Node3D).visible = false
	if player_dies:
		return
	_pirate = arena.call_pirate()
	_pirate.get_node("AIPilot").queue_free()
	var basis: Basis = arena.ship.global_basis.orthonormalized()
	_pirate.global_position = arena.ship.global_position + basis * PIRATE_OFFSET
	_pirate.global_transform.basis = basis * Basis(Vector3.UP, deg_to_rad(155.0))
