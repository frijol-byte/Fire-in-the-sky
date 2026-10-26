extends Node
## Shot driver for the AI pilot: the arena's player ship is handed to an AI pilot (the friendly
## side, standard profile) and a hostile standard-profile pirate is called in. The two dogfight,
## and a spectator camera keeps both in frame (side-on, pulled back as they part), so the shots
## show the fight rather than one pilot's view of it.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N.

## The spectator stands this far from the pair's middle, plus this much per metre of separation.
const CAMERA_BASE_M: float = 90.0
const CAMERA_PER_METRE: float = 0.7
const CAMERA_FOV: float = 62.0

var _placed: bool = false
var _pirate: Ship = null
var _camera: Camera3D = null

@onready var arena: FlightTest = $"../Arena"


func _exit_tree() -> void:
	Settings.values.clear()


func _physics_process(_delta: float) -> void:
	if arena.ship == null or _placed:
		return
	_placed = true
	for child: Node in arena.ship.get_children():
		if child is PlayerPilot:
			child.queue_free()
	arena.ship.stance = Targeting.Stance.FRIENDLY
	# The first pirate called in is a rookie; the shot wants an even fight.
	_pirate = arena.call_pirate()
	var friend_pilot: AIPilot = AIPilot.new()
	friend_pilot.name = "AIPilot"
	friend_pilot.profile = Content.ai_profile(&"standard")
	# The arena's dummies are hostile too; this pilot is here for the pirate.
	friend_pilot.forced_target = _pirate
	arena.ship.add_child(friend_pilot)
	friend_pilot.seed_rolls(11)
	var pirate_pilot: AIPilot = _pirate.get_node("AIPilot") as AIPilot
	pirate_pilot.profile = Content.ai_profile(&"standard")
	pirate_pilot.seed_rolls(12)
	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_camera.far = 6000.0
	arena.add_child(_camera)
	_camera.make_current()


func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_pirate) or arena.ship == null:
		return
	var a: Vector3 = arena.ship.global_position
	var b: Vector3 = _pirate.global_position
	var middle: Vector3 = (a + b) * 0.5
	var apart: float = a.distance_to(b)
	var line: Vector3 = (b - a).normalized()
	var side: Vector3 = line.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var stand: float = CAMERA_BASE_M + apart * CAMERA_PER_METRE
	_camera.global_position = middle + side * stand + Vector3.UP * stand * 0.25
	_camera.look_at(middle, Vector3.UP)
