class_name SpeedFx
extends Node3D
## The sense of speed (GDD 4.5): space dust streaming past the camera, and long streak lines that
## fade in while boosting. Both are `MultiMesh` quads drawn by `space_dust.gdshader`, which keeps
## them in a box around the camera and stretches them along the ship's velocity; this node only
## scatters the specks once and feeds the shader the ship's velocity and boost every frame.

const DUST_SHADER: Shader = preload("res://shaders/space_dust.gdshader")

## Dust: many short specks close to the camera.
const DUST_COUNT: int = 1100
const DUST_BOX: float = 170.0
const DUST_STREAK_TIME: float = 0.028
const DUST_WIDTH: float = 0.1
const DUST_MIN_LENGTH: float = 0.3
## Boost streaks: fewer, longer, brighter lines in a bigger box.
const STREAK_COUNT: int = 260
const STREAK_BOX: float = 420.0
const STREAK_TIME: float = 0.075
const STREAK_WIDTH: float = 0.28
const STREAK_MIN_LENGTH: float = 2.0
const STREAK_INTENSITY: float = 1.6
## Dust is a faint hint at rest and brightens with speed.
const DUST_REST_INTENSITY: float = 0.55
const DUST_SPEED_GAIN: float = 0.9
## Used until a ship is attached.
const DEFAULT_FULL_SPEED: float = 320.0
## Seconds the boost streaks take to fade in and out.
const BOOST_IN_TAU: float = 0.12
const BOOST_OUT_TAU: float = 0.3
const DUST_SEED: int = 2026
const STREAK_SEED: int = 2027

var _ship: Ship = null
var _boost_amount: float = 0.0
var _dust_material: ShaderMaterial = null
var _streak_material: ShaderMaterial = null


func _ready() -> void:
	# Both layers are drawn by the shader around the camera; the node itself stays at the origin.
	_dust_material = _make_material(DUST_BOX, DUST_STREAK_TIME, DUST_MIN_LENGTH, DUST_WIDTH)
	_streak_material = _make_material(STREAK_BOX, STREAK_TIME, STREAK_MIN_LENGTH, STREAK_WIDTH)
	_streak_material.set_shader_parameter("tint", Color(0.7, 0.88, 1.0))
	_add_layer("Dust", DUST_COUNT, DUST_BOX, DUST_SEED, _dust_material)
	_add_layer("Streaks", STREAK_COUNT, STREAK_BOX, STREAK_SEED, _streak_material)
	_apply(0.0)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	if _ship == null or not is_instance_valid(_ship):
		return
	update(delta)


## Follows `ship`: its velocity stretches the specks, its boost brings in the streak lines.
func attach(ship: Ship) -> void:
	_ship = ship
	_boost_amount = 0.0


## Advances the boost fade by `delta` seconds and updates the shader. `_process` calls it every
## frame; tests call it directly.
func update(delta: float) -> void:
	var boosting: bool = _ship != null and _ship.is_boosting()
	_boost_amount = boost_step(_boost_amount, boosting, delta)
	var velocity: Vector3 = _ship.linear_velocity if _ship != null else Vector3.ZERO
	_apply_velocity(velocity)
	_apply(_boost_amount)


## Current strength of the boost streaks, 0..1.
func boost_amount() -> float:
	return _boost_amount


## One step of the boost streaks' fade: eases towards 1 while boosting and back to 0 after.
static func boost_step(current: float, boosting: bool, delta: float) -> float:
	var wanted: float = 1.0 if boosting else 0.0
	var tau: float = BOOST_IN_TAU if boosting else BOOST_OUT_TAU
	return lerpf(current, wanted, CameraRig.smooth_weight(delta, tau))


## Positions for `count` specks, scattered in a cube of edge `box` around the origin. The same
## seed always gives the same specks.
static func scatter(count: int, box: float, seed_value: int) -> PackedVector3Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: PackedVector3Array = []
	for _index: int in count:
		result.append(
			(
				Vector3(
					rng.randf_range(-0.5, 0.5),
					rng.randf_range(-0.5, 0.5),
					rng.randf_range(-0.5, 0.5)
				)
				* box
			)
		)
	return result


## Length in metres of a streak for a ship moving at `speed`.
static func streak_length(speed: float, streak_time: float, min_length: float) -> float:
	return maxf(min_length, speed * streak_time)


func _make_material(
	box: float, streak_time: float, min_length: float, width: float
) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = DUST_SHADER
	material.set_shader_parameter("box_size", box)
	material.set_shader_parameter("streak_time", streak_time)
	material.set_shader_parameter("min_length", min_length)
	material.set_shader_parameter("width", width)
	return material


func _add_layer(
	layer_name: String, count: int, box: float, seed_value: int, material: ShaderMaterial
) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = count
	var points: PackedVector3Array = scatter(count, box, seed_value)
	for index: int in count:
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[index]))
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = layer_name
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves the specks to the camera; keep them from being culled by the node's box.
	instance.extra_cull_margin = 16384.0
	add_child(instance)


func _apply_velocity(velocity: Vector3) -> void:
	_dust_material.set_shader_parameter("velocity", velocity)
	_streak_material.set_shader_parameter("velocity", velocity)


func _apply(boost: float) -> void:
	var speed_fraction: float = 0.0
	var full_speed: float = DEFAULT_FULL_SPEED
	if _ship != null and _ship.def != null:
		full_speed = _ship.def.boost_max_speed
		speed_fraction = clampf(_ship.linear_velocity.length() / full_speed, 0.0, 1.0)
	_dust_material.set_shader_parameter(
		"intensity", lerpf(DUST_REST_INTENSITY, 1.0, speed_fraction)
	)
	_dust_material.set_shader_parameter("speed_gain", DUST_SPEED_GAIN)
	_dust_material.set_shader_parameter("full_speed", full_speed)
	_streak_material.set_shader_parameter("intensity", STREAK_INTENSITY * boost)
