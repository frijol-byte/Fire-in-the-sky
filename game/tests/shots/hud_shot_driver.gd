extends Node
## Shot driver for the flight HUD and the tuning overlay. Flies the Kestrel past rows of pylons:
## cruise (flight assist on), boost, then a drift turn with flight assist off (the velocity marker
## separates from the nose ring), and finally opens the tuning overlay.
##
## The harness renders at 30 fps against 60 physics ticks, so shot frame N is physics tick 2N.
## The director runs while the overlay has paused the tree, so its process mode is ALWAYS.

const CRUISE_END: int = 200
const BOOST_END: int = 300
const DRIFT_START: int = 330
const DRIFT_TURN_END: int = 400
const OVERLAY_TICK: int = 430
const PYLON_SPACING: float = 90.0
const PYLON_ROWS: int = 40
const PYLON_SIDE: float = 45.0
const SCATTER_COUNT: int = 500
const SCATTER_SEED: int = 11

var _tick: int = 0

@onready var ship: Ship = $"../Ship"
@onready var rig: CameraRig = $"../CameraRig"
@onready var hud: FlightHud = $"../Hud/FlightHud"
@onready var overlay: TuningOverlay = $"../TuningOverlay"


func _ready() -> void:
	_build_pylons()
	rig.attach(ship)
	hud.bind(ship)
	overlay.bind(ship, rig)


func _physics_process(_delta: float) -> void:
	_tick += 1
	ship.controls = controls_for_tick(_tick)
	if _tick == OVERLAY_TICK:
		overlay.open()


## The scripted controls for physics tick `tick` (1-based).
static func controls_for_tick(tick: int) -> ShipControls:
	var controls: ShipControls = ShipControls.new()
	if tick <= BOOST_END:
		controls.thrust = Vector3(0.0, 0.0, 1.0)
		controls.boost = tick > CRUISE_END
		return controls
	if tick > DRIFT_START:
		controls.fa_off = true
		if tick <= DRIFT_TURN_END:
			controls.rotate = Vector3(0.0, 0.5, 0.0)
	return controls


func _build_pylons() -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(5.0, 50.0, 5.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.72, 0.2)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.55, 0.1)
	material.emission_energy_multiplier = 0.6
	mesh.material = material
	var spots: Array[Vector3] = []
	for row: int in PYLON_ROWS:
		var z: float = -PYLON_SPACING * (row + 1)
		spots.append(Vector3(-PYLON_SIDE, 0.0, z))
		spots.append(Vector3(PYLON_SIDE, 0.0, z))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED
	for count: int in SCATTER_COUNT:
		spots.append(
			Vector3(
				rng.randf_range(-600.0, 1800.0),
				rng.randf_range(-120.0, 120.0),
				rng.randf_range(-2400.0, 300.0)
			)
		)
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = spots.size()
	for index: int in spots.size():
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, spots[index]))
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multi
	get_parent().add_child.call_deferred(instance)
