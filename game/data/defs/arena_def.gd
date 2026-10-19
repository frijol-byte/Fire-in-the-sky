class_name ArenaDef
extends ContentDef
## Everything that makes one flight arena (a zone's space, not its ships): the sky and the sun,
## the asteroid field, the gates and where the player starts. The look of a system is tuned
## here, in a `.tres`, never in code.
##
## Units: metres, degrees. Directions are unit vectors (normalised on use).

## `strings.csv` key of the arena's name.
@export var display_name_key: String = ""
## Ship the player starts in (a `ShipDef` id).
@export var spawn_ship_id: StringName = &"kestrel"
## Where the player starts and which way the nose points.
@export var spawn_position: Vector3 = Vector3.ZERO
@export var spawn_look_at: Vector3 = Vector3(0.0, 0.0, -1000.0)

@export_group("Sky")
## Seed of the nebula and the star field (a different seed gives a different sky).
@export var sky_seed: float = 3.0
## Edge length of each face of the baked cubemap, in pixels.
@export_range(64, 2048) var sky_cubemap_size: int = 1024
@export var sky_space_color: Color = Color(0.012, 0.01, 0.02)
## Dim, wide gas clouds.
@export var sky_nebula_deep: Color = Color(0.25, 0.07, 0.02)
## The bright body of the nebula.
@export var sky_nebula_main: Color = Color(1.0, 0.45, 0.08)
## Rare hot highlights inside the nebula.
@export var sky_nebula_hot: Color = Color(1.0, 0.82, 0.45)
## Dark dust lanes cut out of the nebula.
@export var sky_dust_lane_color: Color = Color(0.02, 0.012, 0.01)
## Size of the nebula features (higher is smaller and busier).
@export var sky_nebula_scale: float = 1.6
@export_range(0.0, 2.0) var sky_nebula_strength: float = 1.0
## Stars per unit of sky (0 is none, 1 is a dense field).
@export_range(0.0, 1.0) var sky_star_density: float = 0.5
@export_range(0.0, 3.0) var sky_star_brightness: float = 1.0
## Direction towards the sun, as seen from the arena.
@export var sky_sun_direction: Vector3 = Vector3(0.55, 0.28, -0.78)
@export var sky_sun_color: Color = Color(0.85, 0.92, 1.0)
## Angular radius of the sun disc, in degrees.
@export_range(0.1, 10.0) var sky_sun_radius_deg: float = 1.4

@export_group("Light")
@export var sun_light_energy: float = 1.5
@export var sun_light_color: Color = Color(1.0, 0.93, 0.82)
## A weak coloured light from the side away from the sun, so shadowed sides keep their shape.
@export var fill_light_energy: float = 0.8
@export var fill_light_color: Color = Color(0.9, 0.45, 0.25)
## How much light the sky gives to the ships (1 = its natural brightness).
@export_range(0.0, 4.0) var ambient_energy: float = 2.5
@export_range(0.0, 8.0) var glow_intensity: float = 0.9
@export_range(0.0, 2.0) var glow_bloom: float = 0.15
## Pixels brighter than this bloom.
@export_range(0.0, 4.0) var glow_threshold: float = 0.9

@export_group("Asteroid field")
@export var field_seed: int = 4242
## Rocks drawn with MultiMesh (visual; the ones near the ship also get colliders).
@export var field_rock_count: int = 2000
## Nothing spawns closer to the centre than this (a clear lane around the start).
@export var field_inner_radius: float = 90.0
@export var field_outer_radius: float = 2600.0
## Above 1 packs the rocks towards the centre.
@export var field_density_bias: float = 1.7
## Squashes the field into a belt: 1 is a sphere, 0.2 a thin disc.
@export var field_vertical_scale: float = 0.22
## Rock scale range (each variant is about 5 m in radius at scale 1) and how the scales are
## spread (above 1 gives mostly small rocks and a few giants).
@export var field_min_scale: float = 0.5
@export var field_max_scale: float = 9.0
@export var field_scale_bias: float = 3.0
## Rocks are kept this far from the line from the start through every gate in order, so the
## course can be flown without ramming a rock (rocks outside it are as thick as ever).
@export var field_lane_radius: float = 60.0

@export_group("Rock colliders")
## Colliders kept alive around the ship (reused from a pool as it moves).
@export var collider_pool_size: int = 32
## Rocks within this distance of the ship get a collider.
@export var collider_radius: float = 420.0
@export_range(0.0, 1.0) var rock_bounce: float = 0.35
@export_range(0.0, 1.0) var rock_friction: float = 0.3

@export_group("Gates")
## One transform per ring gate: the ring lies in the local XY plane and is flown through
## along local Z.
@export var gate_transforms: Array[Transform3D] = []
## Gate scale (1 = the 60 m opening of the model).
@export var gate_scale: float = 1.0


func kind() -> StringName:
	return &"arena"


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if display_name_key.is_empty():
		result.append("display_name_key is empty")
	if spawn_ship_id == &"":
		result.append("spawn_ship_id is empty")
	if spawn_position.distance_to(spawn_look_at) < 1.0:
		result.append("spawn_look_at must be away from spawn_position")
	if sky_sun_direction.length() < 0.001:
		result.append("sky_sun_direction is zero")
	if sky_cubemap_size < 64:
		result.append("sky_cubemap_size must be at least 64")
	if field_rock_count < 0:
		result.append("field_rock_count is negative")
	if field_inner_radius < 0.0 or field_outer_radius <= field_inner_radius:
		result.append("field_outer_radius must be larger than field_inner_radius")
	if field_lane_radius < 0.0:
		result.append("field_lane_radius is negative")
	if field_density_bias <= 0.0 or field_scale_bias <= 0.0:
		result.append("field biases must be positive")
	if field_vertical_scale <= 0.0:
		result.append("field_vertical_scale must be positive")
	if field_min_scale <= 0.0 or field_max_scale < field_min_scale:
		result.append("field scale range is empty")
	if collider_pool_size < 1 or collider_radius <= 0.0:
		result.append("collider pool needs at least one collider and a positive radius")
	if gate_scale <= 0.0:
		result.append("gate_scale must be positive")
	return result


## Direction the sun's light travels (from the sun towards the arena).
func light_direction() -> Vector3:
	return -sky_sun_direction.normalized()
