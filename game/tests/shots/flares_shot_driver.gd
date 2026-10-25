extends Node
## Shot driver for the incoming-missile warning and the flares: an enemy Kestrel 650 m behind the
## player launches a homing missile at the player's ship. The warning banner and the marker show, and
## when the missile is 260 m away the player throws flares (device slot 1, through `DeviceSystem`).
## The flares' decoy chance is raised to 100% so the shot always shows the missile chasing a flare.
## The arena's own camera and HUD take every shot.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N.

const LAUNCH_AT: int = 20
const ENEMY_DISTANCE: float = 650.0
const FLARE_DISTANCE: float = 260.0
const SHIP_SCENE: PackedScene = preload("res://ships/ship.tscn")

var _tick: int = 0
var _placed: bool = false
var _threw: bool = false
var _missile: Missile = null

@onready var arena: FlightTest = $"../Arena"


func _exit_tree() -> void:
	Settings.values.clear()


func _physics_process(_delta: float) -> void:
	if arena.ship == null:
		return
	if not _placed:
		_place()
	_tick += 1
	var controls: ShipControls = ShipControls.new()
	controls.thrust = Vector3(0.0, 0.0, 0.3)
	if _tick == LAUNCH_AT:
		_launch()
	if _missile != null and _missile.active and not _threw:
		if _missile.position.distance_to(arena.ship.global_position) < FLARE_DISTANCE:
			_threw = true
			controls.device = 1
	arena.ship.controls = controls


func _place() -> void:
	_placed = true
	for child: Node in arena.ship.get_children():
		if child is PlayerPilot:
			child.queue_free()
	Content.device(&"flares").decoy_chance = 1.0
	var enemy: Ship = SHIP_SCENE.instantiate() as Ship
	enemy.def = Content.ship(&"kestrel")
	enemy.name = "Enemy"
	arena.add_child(enemy)
	var behind: Vector3 = arena.ship.global_position + Vector3(30.0, 10.0, ENEMY_DISTANCE)
	enemy.global_transform = Transform3D(
		Basis.looking_at(arena.ship.global_position - behind, Vector3.UP), behind
	)


func _launch() -> void:
	var enemy: Ship = arena.get_node("Enemy") as Ship
	var manager: MissileManager = MissileManager.for_node(arena)
	var def: SecondaryDef = Content.secondary(&"homing_missile")
	var forward: Vector3 = -enemy.global_basis.z
	_missile = manager.launch(
		def, enemy, enemy.global_position + forward * 6.0, forward * def.launch_speed, arena.ship
	)
