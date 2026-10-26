class_name EngineFx
extends Node
## Engine glow and exhaust trails for a ship: a glowing sprite on each `SOCKET_engine_*` that
## swells with throttle and turns white-hot on boost, and a ribbon of light left in the world
## behind each engine. Any ship can have one (AI ships too); `Ship` adds it to itself.
##
## The sprite is a child of the socket, so it moves with the model. The trail is not: it is a
## world-space ribbon built from where the socket has been over the last fraction of a second.

const GLOW_TEXTURE_SIZE: int = 128
## Glow sprite radius at idle and at full throttle, as a multiple of the socket's `glow_radius`.
const IDLE_LEVEL: float = 0.28
## How fast the engine level follows the throttle (per second).
const LEVEL_RATE: float = 6.0
## Trail points are sampled every physics tick; this many at most make the trail.
const TRAIL_POINTS: int = 36
## The trail is cut to this length in metres (it would be 190 m long at boost speed otherwise).
const TRAIL_LENGTH: float = 55.0
## Trail width at the head (metres) at idle, at full power and boosting; the tail is always 0.
const TRAIL_WIDTH_IDLE: float = 0.12
const TRAIL_WIDTH_FULL: float = 0.45
const TRAIL_WIDTH_BOOST: float = 0.75
## The trail's brightness at most (it is added to the picture, so full strength would burn out).
const TRAIL_ALPHA: float = 0.55
## The chase camera sits right behind the ship, so the trail points at it: the trail fades out
## between these distances (metres) from the camera instead of filling the screen.
const TRAIL_FADE_NEAR: float = 6.0
const TRAIL_FADE_FAR: float = 24.0
## Glow sprite size (metres across) at level 0 and level 1, and the extra size boosting adds.
const GLOW_SIZE_IDLE: float = 1.1
const GLOW_SIZE_FULL: float = 3.6
const GLOW_SIZE_BOOST: float = 2.4

const COLOR_NORMAL: Color = Color(0.35, 0.65, 1.0)
const COLOR_BOOST: Color = Color(0.75, 0.95, 1.0)

var _ship: Ship = null
var _sockets: Array[Marker3D] = []
var _glows: Array[MeshInstance3D] = []
var _trail_meshes: Array[MeshInstance3D] = []
var _trail_points: Array[PackedVector3Array] = []
var _glow_material: StandardMaterial3D = null
var _trail_material: StandardMaterial3D = null
var _level: float = 0.0
var _boost: float = 0.0
var _off: bool = false


func _process(delta: float) -> void:
	if _ship == null or _off:
		return
	update(delta)


func _physics_process(_delta: float) -> void:
	if _ship == null or _off:
		return
	for index: int in _sockets.size():
		var points: PackedVector3Array = _trail_points[index]
		points.append(_sockets[index].global_position)
		if points.size() > TRAIL_POINTS:
			points.remove_at(0)
		_trail_points[index] = points


## Builds a glow and a trail for each engine socket of `ship`'s model.
func setup(ship: Ship) -> void:
	_ship = ship
	_glow_material = _make_glow_material()
	_trail_material = _make_trail_material()
	if ship.model == null:
		return
	_sockets = ship.model.get_sockets(&"engine")
	for socket: Marker3D in _sockets:
		var glow: MeshInstance3D = MeshInstance3D.new()
		glow.name = "Glow"
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2.ONE
		quad.material = _glow_material
		glow.mesh = quad
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		socket.add_child(glow)
		_glows.append(glow)
		var trail: MeshInstance3D = MeshInstance3D.new()
		trail.name = "Trail%d" % _trail_meshes.size()
		trail.top_level = true
		trail.mesh = ImmediateMesh.new()
		trail.material_override = _trail_material
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		trail.extra_cull_margin = 16384.0
		add_child(trail)
		_trail_meshes.append(trail)
		_trail_points.append(PackedVector3Array())
	update(0.0)


## Puts the engines out for good: the glows and trails disappear (a destroyed ship).
func shut_down() -> void:
	_off = true
	for glow: MeshInstance3D in _glows:
		glow.visible = false
	for trail: MeshInstance3D in _trail_meshes:
		trail.visible = false


## True once `shut_down` has been called.
func is_off() -> bool:
	return _off


## Advances the engine level by `delta` seconds and redraws the glows and trails. `_process`
## calls it every frame; tests call it directly.
func update(delta: float) -> void:
	var thrust: float = _ship.controls.thrust.z
	_level = level_step(_level, target_level(thrust, _ship.is_boosting()), delta)
	_boost = lerpf(
		_boost, 1.0 if _ship.is_boosting() else 0.0, CameraRig.smooth_weight(delta, 0.15)
	)
	var color: Color = COLOR_NORMAL.lerp(COLOR_BOOST, _boost)
	_glow_material.albedo_color = Color(color, glow_alpha(_level))
	var size: float = glow_size(_level, _boost)
	for glow: MeshInstance3D in _glows:
		glow.scale = Vector3(size, size, size)
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var camera_position: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	for index: int in _trail_meshes.size():
		_draw_trail(index, camera_position, color)


## Current engine level, 0..1 (what the glow and the trail show).
func level() -> float:
	return _level


## Number of engines (one glow and one trail each).
func engine_count() -> int:
	return _glows.size()


## Number of points the trail behind engine `index` is made of.
func trail_length(index: int) -> int:
	return _trail_points[index].size()


## The level an engine heads for: idle when coasting, full on full forward throttle, and
## full while boosting.
static func target_level(forward_thrust: float, boosting: bool) -> float:
	if boosting:
		return 1.0
	return lerpf(IDLE_LEVEL, 1.0, clampf(forward_thrust, 0.0, 1.0))


## One step towards `target`.
static func level_step(current: float, target: float, delta: float) -> float:
	return lerpf(current, target, CameraRig.smooth_weight(delta, 1.0 / LEVEL_RATE))


## Opacity of the glow sprite at `level`.
static func glow_alpha(level_value: float) -> float:
	return clampf(0.35 + 0.65 * level_value, 0.0, 1.0)


## Diameter in metres of the glow sprite.
static func glow_size(level_value: float, boost: float) -> float:
	return lerpf(GLOW_SIZE_IDLE, GLOW_SIZE_FULL, level_value) + GLOW_SIZE_BOOST * boost


## Width in metres of the trail's head.
static func trail_width(level_value: float, boost: float) -> float:
	var width: float = lerpf(TRAIL_WIDTH_IDLE, TRAIL_WIDTH_FULL, level_value)
	return lerpf(width, TRAIL_WIDTH_BOOST, boost)


## `points` (oldest first) without the oldest ones that lie more than `max_length` metres of path
## away from the newest point.
static func trim_to_length(points: PackedVector3Array, max_length: float) -> PackedVector3Array:
	var travelled: float = 0.0
	var keep_from: int = 0
	for index: int in range(points.size() - 1, 0, -1):
		travelled += points[index].distance_to(points[index - 1])
		if travelled > max_length:
			keep_from = index
			break
	return points.slice(keep_from)


## The vertices of a camera-facing ribbon through `points` (oldest first), as a triangle strip:
## two vertices per point, offset to either side, plus a colour for each. The ribbon is
## `width` wide at the newest point and tapers to a point at the oldest, fading as it goes, and
## fading out too within `TRAIL_FADE_FAR` of the camera.
## Returns {"vertices": PackedVector3Array, "colors": PackedColorArray}; empty with < 2 points.
static func ribbon(
	points: PackedVector3Array, camera_position: Vector3, width: float, color: Color
) -> Dictionary:
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	var count: int = points.size()
	if count < 2:
		return {"vertices": vertices, "colors": colors}
	for index: int in count:
		var along: Vector3 = points[mini(index + 1, count - 1)] - points[maxi(index - 1, 0)]
		var to_camera: Vector3 = camera_position - points[index]
		var side: Vector3 = along.cross(to_camera)
		if side.length_squared() < 0.000001:
			side = Vector3.UP
		side = side.normalized()
		var age: float = float(index) / float(count - 1)
		var half: float = width * 0.5 * age
		var near_camera: float = smoothstep(TRAIL_FADE_NEAR, TRAIL_FADE_FAR, to_camera.length())
		var faded: Color = Color(color, color.a * age * age * near_camera)
		vertices.append(points[index] + side * half)
		vertices.append(points[index] - side * half)
		colors.append(faded)
		colors.append(faded)
	return {"vertices": vertices, "colors": colors}


func _draw_trail(index: int, camera_position: Vector3, color: Color) -> void:
	var mesh: ImmediateMesh = _trail_meshes[index].mesh as ImmediateMesh
	mesh.clear_surfaces()
	# The newest point is the socket's position now, so the trail has no gap at the engine.
	var points: PackedVector3Array = _trail_points[index].duplicate()
	points.append(_sockets[index].get_global_transform_interpolated().origin)
	points = trim_to_length(points, TRAIL_LENGTH)
	var data: Dictionary = ribbon(
		points,
		camera_position,
		trail_width(_level, _boost),
		Color(color, glow_alpha(_level) * TRAIL_ALPHA)
	)
	var vertices: PackedVector3Array = data["vertices"]
	if vertices.size() < 4:
		return
	var colors: PackedColorArray = data["colors"]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for vertex: int in vertices.size():
		mesh.surface_set_color(colors[vertex])
		mesh.surface_add_vertex(vertices[vertex])
	mesh.surface_end()


func _make_glow_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _radial_texture()
	material.disable_receive_shadows = true
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_trail_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _radial_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray(
		[Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.45), Color(1.0, 1.0, 1.0, 0.0)]
	)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = GLOW_TEXTURE_SIZE
	texture.height = GLOW_TEXTURE_SIZE
	return texture
