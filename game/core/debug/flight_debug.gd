class_name FlightDebug
extends Node3D
## Debug scene: fly the Kestrel with flight assist through a field of marker pylons, with the
## real chase/cockpit camera (V or R3 switches views, hold Z for free look when the
## `camera/free_look` setting is on). A stand-in until the flight arena (M1-T5). Esc quits.

const PYLON_COUNT: int = 400
const FIELD_RADIUS: float = 3000.0
const PYLON_SEED: int = 7

@onready var _ship: Ship = $Ship
@onready var _readout: Label = $Readout
@onready var _rig: CameraRig = $CameraRig


func _ready() -> void:
	_build_pylons()
	_ship.add_child(PlayerPilot.new())
	_rig.attach(_ship)
	# Free look is off by default (the right stick aims); this scene turns it on for trying it out.
	Settings.set_value(InputRouter.SETTING_FREE_LOOK, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	var local: Vector3 = _ship.local_velocity()
	_readout.text = (
		readout_text(-local.z, _ship.linear_velocity.length())
		+ "\n"
		+ power_text(
			_ship.power().energy, _ship.power().capacity, _ship.controls.fa_off, _ship.is_boosting()
		)
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().quit()


## Returns the speed readout: forward speed along the nose, and total speed.
static func readout_text(forward: float, total: float) -> String:
	return TranslationServer.translate("FLIGHT_DEBUG_SPEED") % [forward, total]


## Returns the energy readout line with the flight assist and boost state.
static func power_text(energy: float, capacity: float, fa_off: bool, boosting: bool) -> String:
	var fa_key: String = "FLIGHT_DEBUG_FA_OFF" if fa_off else "FLIGHT_DEBUG_FA_ON"
	var boost_key: String = "FLIGHT_DEBUG_BOOST" if boosting else "FLIGHT_DEBUG_NO_BOOST"
	return (
		TranslationServer.translate("FLIGHT_DEBUG_POWER") % [energy, capacity]
		+ "   "
		+ TranslationServer.translate(fa_key)
		+ "   "
		+ TranslationServer.translate(boost_key)
	)


func _build_pylons() -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(6.0, 60.0, 6.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.72, 0.2)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.55, 0.1)
	material.emission_energy_multiplier = 0.6
	mesh.material = material
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = PYLON_SEED
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = PYLON_COUNT
	for index: int in PYLON_COUNT:
		var position: Vector3 = Vector3(
			rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)
		)
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, position * FIELD_RADIUS))
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multi
	add_child(instance)
