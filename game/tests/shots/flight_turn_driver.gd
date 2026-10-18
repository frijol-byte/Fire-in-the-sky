extends Node
## Shot driver: flies the Kestrel through a scripted maneuver (accelerate, then a full-rate
## right turn, then straighten out) while a camera high above follows its position but not
## its rotation. Amber markers dropped every few ticks draw the path, so the screenshots show
## the turn and the ship's attitude through it.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is
## physics tick 2N.

## Ticks in each phase: accelerate, turn, straighten.
const ACCELERATE_TICKS: int = 90
const TURN_TICKS: int = 150
const MARKER_EVERY: int = 4
const CAMERA_HEIGHT: float = 160.0
const MARKER_RADIUS: float = 2.0
## Markers sit below the ship so the camera, above it, still sees the ship.
const MARKER_DROP: float = 12.0

var _tick: int = 0
var _marker_mesh: SphereMesh = SphereMesh.new()

@onready var ship: Ship = $"../Ship"
@onready var camera: Camera3D = $"../Camera3D"


func _ready() -> void:
	_marker_mesh.radius = MARKER_RADIUS
	_marker_mesh.height = MARKER_RADIUS * 2.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.72, 0.2)
	_marker_mesh.material = material


func _physics_process(_delta: float) -> void:
	_tick += 1
	ship.controls = controls_for_tick(_tick)
	camera.global_position = ship.global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)
	camera.look_at(ship.global_position, Vector3.FORWARD)
	if _tick % MARKER_EVERY == 0:
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.mesh = _marker_mesh
		get_parent().add_child(marker)
		marker.global_position = ship.global_position + Vector3(0.0, -MARKER_DROP, 0.0)


## The scripted controls for physics tick `tick` (1-based).
static func controls_for_tick(tick: int) -> ShipControls:
	var controls: ShipControls = ShipControls.new()
	controls.thrust = Vector3(0.0, 0.0, 1.0)
	if tick > ACCELERATE_TICKS and tick <= ACCELERATE_TICKS + TURN_TICKS:
		# Full right yaw. With flight assist on the velocity follows the nose, so the path curves.
		controls.rotate = Vector3(0.0, 1.0, 0.0)
	return controls
