extends Node
## Shot driver for the camera rig: flies the Kestrel past rows of pylons (cruise, a right turn,
## boost) in the chase view, switches to the cockpit view, turns left, then free-looks right. The
## rig's own camera takes every shot, so what the PNGs show is what the player sees.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N. The phase lengths below are in ticks.

const CRUISE_END: int = 150
const TURN_END: int = 210
const BOOST_END: int = 310
const COCKPIT_TURN_START: int = 380
const COCKPIT_TURN_END: int = 440
const FREE_LOOK_START: int = 450
const PYLON_SPACING: float = 90.0
const PYLON_ROWS: int = 30
const PYLON_SIDE: float = 45.0
const SCATTER_COUNT: int = 500
const SCATTER_SEED: int = 11

var _tick: int = 0

@onready var ship: Ship = $"../Ship"
@onready var rig: CameraRig = $"../CameraRig"


func _ready() -> void:
	_build_pylons()
	rig.attach(ship)


func _exit_tree() -> void:
	Settings.values.clear()
	Input.action_release("free_look")
	Input.action_release("yaw_right")


func _physics_process(_delta: float) -> void:
	_tick += 1
	ship.controls = controls_for_tick(_tick)
	if _tick == BOOST_END + 1:
		rig.toggle_view()
	if _tick == FREE_LOOK_START:
		Settings.set_value(InputRouter.SETTING_FREE_LOOK, true)
		Input.action_press("free_look")
		Input.action_press("yaw_right", 1.0)


## The scripted controls for physics tick `tick` (1-based).
static func controls_for_tick(tick: int) -> ShipControls:
	var controls: ShipControls = ShipControls.new()
	if tick > FREE_LOOK_START:
		return controls
	controls.thrust = Vector3(0.0, 0.0, 1.0)
	if tick > CRUISE_END and tick <= TURN_END:
		controls.rotate = Vector3(0.0, 1.0, 0.0)
	if tick > TURN_END and tick <= BOOST_END:
		controls.boost = true
	if tick > COCKPIT_TURN_START and tick <= COCKPIT_TURN_END:
		controls.rotate = Vector3(0.0, -1.0, 0.0)
	return controls


## Two rows of amber pylons along the first stretch, and a scatter of them over the area the
## turns cover, so every view has something to look at.
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
				rng.randf_range(-300.0, 1800.0),
				rng.randf_range(-120.0, 120.0),
				rng.randf_range(-1800.0, 300.0)
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
