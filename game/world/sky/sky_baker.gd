class_name SkyBaker
extends Node
## Paints the sky once, when a zone loads, and keeps it as a cubemap.
##
## Six `SubViewport`s (one per cube face) each draw `nebula_bake.gdshader` for their face in the
## same frame; the six images then become a `Cubemap` that `nebula_sky.gdshader` shows as the
## environment's `Sky`. Drawing a noise nebula every frame would cost far more than sampling a
## cubemap, which is the reason to bake.
##
## There is nothing to draw on in a headless run (the test runner), so `can_bake()` is false
## there and the caller keeps a plain background colour.

## Emitted when the sky is ready. `sky` is null if baking was not possible.
signal baked(sky: Sky)

const BAKE_SHADER: Shader = preload("res://shaders/nebula_bake.gdshader")
const SKY_SHADER: Shader = preload("res://shaders/nebula_sky.gdshader")
const FACE_COUNT: int = 6


## True when there is a renderer to draw the faces with.
static func can_bake() -> bool:
	return DisplayServer.get_name() != "headless"


## The direction (unit vector) of the pixel at `uv` (0..1, origin top left) on cube face `face`
## (0..5 = +X, -X, +Y, -Y, +Z, -Z). The shader has the same table; a test keeps the centres right.
static func face_direction(face: int, uv: Vector2) -> Vector3:
	var sc: float = uv.x * 2.0 - 1.0
	var tc: float = uv.y * 2.0 - 1.0
	var result: Vector3 = Vector3.ZERO
	match face:
		0:
			result = Vector3(1.0, -tc, -sc)
		1:
			result = Vector3(-1.0, -tc, sc)
		2:
			result = Vector3(sc, 1.0, tc)
		3:
			result = Vector3(sc, -1.0, -tc)
		4:
			result = Vector3(sc, -tc, 1.0)
		_:
			result = Vector3(-sc, -tc, -1.0)
	return result.normalized()


## The shader parameters for `def`'s sky.
static func bake_parameters(def: ArenaDef) -> Dictionary:
	return {
		"seed": def.sky_seed,
		"space_color": def.sky_space_color,
		"nebula_deep": def.sky_nebula_deep,
		"nebula_main": def.sky_nebula_main,
		"nebula_hot": def.sky_nebula_hot,
		"dust_lane": def.sky_dust_lane_color,
		"nebula_scale": def.sky_nebula_scale,
		"nebula_strength": def.sky_nebula_strength,
		"star_density": def.sky_star_density,
		"star_brightness": def.sky_star_brightness,
		"sun_direction": def.sky_sun_direction.normalized(),
		"sun_color": def.sky_sun_color,
		"sun_radius": deg_to_rad(def.sky_sun_radius_deg),
	}


## Paints the sky for `def`. Awaitable; also emits `baked`. Returns null when nothing can be
## drawn (headless).
func bake(def: ArenaDef) -> Sky:
	if not can_bake():
		baked.emit(null)
		return null
	var size: int = def.sky_cubemap_size
	var viewports: Array[SubViewport] = []
	for face: int in FACE_COUNT:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(size, size)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.disable_3d = true
		viewport.transparent_bg = false
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(size, size)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = BAKE_SHADER
		material.set_shader_parameter("face", face)
		var parameters: Dictionary = bake_parameters(def)
		for key: String in parameters:
			material.set_shader_parameter(key, parameters[key])
		rect.material = material
		viewport.add_child(rect)
		add_child(viewport)
		viewports.append(viewport)
	await RenderingServer.frame_post_draw
	var images: Array[Image] = []
	for viewport: SubViewport in viewports:
		var image: Image = viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		image.generate_mipmaps()
		images.append(image)
		viewport.queue_free()
	var cubemap: Cubemap = Cubemap.new()
	cubemap.create_from_images(images)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("cubemap", cubemap)
	var sky: Sky = Sky.new()
	sky.sky_material = material
	baked.emit(sky)
	return sky
