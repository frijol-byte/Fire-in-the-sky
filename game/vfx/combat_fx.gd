class_name CombatFx
extends Node3D
## The look and sound of shooting, v0: a muzzle flash and a shot sound where a weapon fires, and
## sparks, a flash and a sound where a shot lands. Everything is pooled (`FLASH_POOL`,
## `SPARK_POOL`, `SOUND_POOL`): a busy fight reuses the same nodes, nothing is created per shot.
##
## `ProjectileManager` owns one. The shield-hit ripple is drawn on the hit ship by `ShieldFx`.
##
## What a hit looks like depends on the deepest layer it reached (`impact_kind`): a shield hit is a
## cool flash with no sparks (the ripple carries it), armor and hull throw sparks, and a shot that
## hits rock is a small dull puff.

enum ImpactKind { WORLD, SHIELD, ARMOR, HULL }

const FLASH_POOL: int = 24
## Big flashes (explosions, launches, flares) have a pool of their own: their billboards keep the
## scale they are given, so they really are as big as asked. (The small muzzle and impact flashes
## are drawn at the billboard's unit size.)
const BLAST_POOL: int = 12
## Spark bursts kept per kind of hit (each kind has bursts of its own size, see `SPARK_COUNT`).
const SPARK_POOL: int = 8
const SOUND_POOL: int = 12
const FLASH_TIME: float = 0.07
const IMPACT_FLASH_TIME: float = 0.12
const GLOW_TEXTURE_SIZE: int = 64
## Impact flash diameter (m) per `ImpactKind`, and spark counts.
const IMPACT_FLASH_SIZE: Array[float] = [2.5, 6.0, 3.5, 4.5]
const SPARK_COUNT: Array[int] = [4, 0, 9, 14]
const SHIELD_COLOR: Color = Color(0.45, 0.75, 1.0)
const WORLD_COLOR: Color = Color(0.8, 0.7, 0.6)
const SOUND_HIT_SHIELD: AudioStreamWAV = preload("res://assets/audio/sfx/hit_shield.wav")
const SOUND_HIT_ARMOR: AudioStreamWAV = preload("res://assets/audio/sfx/hit_armor.wav")
const SOUND_HIT_HULL: AudioStreamWAV = preload("res://assets/audio/sfx/hit_hull.wav")
const SOUND_HIT_ROCK: AudioStreamWAV = preload("res://assets/audio/sfx/hit_rock.wav")
const SOUND_OVERHEAT: AudioStreamWAV = preload("res://assets/audio/sfx/weapon_overheat.wav")
const SOUND_EXPLOSION: AudioStreamWAV = preload("res://assets/audio/sfx/explosion.wav")
const HIT_SOUND_DB: float = -6.0
const OVERHEAT_SOUND_DB: float = -8.0
const EXPLOSION_SOUND_DB: float = -2.0
## An explosion is a hot flash a little bigger than its blast radius over a white core, and sparks.
const EXPLOSION_FLASH_FACTOR: float = 1.5
const EXPLOSION_CORE_FACTOR: float = 0.55
const EXPLOSION_FLASH_TIME: float = 0.4
const EXPLOSION_CORE_TIME: float = 0.2


class Flash:
	extends RefCounted
	var node: MeshInstance3D = null
	var material: StandardMaterial3D = null
	var left: float = 0.0
	var total: float = 0.1
	var size: float = 1.0


var _flashes: Array[Flash] = []
var _blasts: Array[Flash] = []
var _next_blast: int = 0
## Spark bursts per `ImpactKind`; a burst's particle count is fixed when it is made, because
## changing it while the particles are alive reallocates their buffers.
var _sparks: Dictionary[int, Array] = {}
var _next_spark: Dictionary[int, int] = {}
var _players: Array[AudioStreamPlayer3D] = []
var _next_flash: int = 0
var _next_player: int = 0
var _streams: Dictionary[String, AudioStream] = {}
var _glow: GradientTexture2D = null


func _ready() -> void:
	top_level = true
	_glow = _radial_texture()
	for index: int in FLASH_POOL:
		_flashes.append(_make_flash(false))
	for index: int in BLAST_POOL:
		_blasts.append(_make_flash(true))
	for kind: int in ImpactKind.values():
		var bursts: Array[CPUParticles3D] = []
		if SPARK_COUNT[kind] > 0:
			for index: int in SPARK_POOL:
				bursts.append(_make_sparks(SPARK_COUNT[kind]))
		_sparks[kind] = bursts
		_next_spark[kind] = 0
	for index: int in SOUND_POOL:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.unit_size = 25.0
		player.max_distance = 1500.0
		# A sound still playing when the node leaves the tree (a scene change, a quit) is reported
		# as a leaked resource; `tree_exiting` fires while stopping it still works.
		player.tree_exiting.connect(player.stop)
		add_child(player)
		_players.append(player)


func _process(delta: float) -> void:
	for flash: Flash in _flashes + _blasts:
		if flash.left <= 0.0:
			continue
		flash.left = maxf(flash.left - delta, 0.0)
		_draw_flash(flash)


## A muzzle flash at `position`, and the weapon's shot sound.
func muzzle(position: Vector3, weapon: WeaponDef) -> void:
	_start_flash(position, weapon.tracer_color, weapon.muzzle_flash_size, FLASH_TIME)
	if not weapon.fire_sfx.is_empty():
		play(_stream(weapon.fire_sfx), position, weapon.fire_sfx_db)


## The vent sound of a gun that has just overheated.
func overheat(position: Vector3) -> void:
	play(SOUND_OVERHEAT, position, OVERHEAT_SOUND_DB)


## What a landed shot looks and sounds like. `result` is what `Durability.apply` reported, or
## null when the shot hit plain geometry.
func impact(point: Vector3, normal: Vector3, weapon: WeaponDef, result: DamageResult) -> void:
	var kind: ImpactKind = impact_kind(result)
	var color: Color = impact_color(kind, weapon)
	_start_flash(point, color, IMPACT_FLASH_SIZE[kind], IMPACT_FLASH_TIME)
	if SPARK_COUNT[kind] > 0:
		_emit_sparks(kind, point, normal, color)
	play(hit_stream(kind), point, HIT_SOUND_DB)


## An explosion of blast radius `radius` metres at `position`: a flash over a white core, a burst
## of sparks and a boom. Missiles and rockets use it (`harmless` ones just a small one).
func explosion(position: Vector3, radius: float, color: Color) -> void:
	flash(position, color, radius * EXPLOSION_FLASH_FACTOR, EXPLOSION_FLASH_TIME)
	flash(position, Color.WHITE, radius * EXPLOSION_CORE_FACTOR, EXPLOSION_CORE_TIME)
	_emit_sparks(ImpactKind.HULL, position, Vector3.UP, color)
	play(SOUND_EXPLOSION, position, EXPLOSION_SOUND_DB)


## A big flash of `size` metres at `position` that fades away over `time` seconds.
func flash(position: Vector3, color: Color, size: float, time: float = FLASH_TIME) -> void:
	var blast: Flash = _blasts[_next_blast]
	_next_blast = (_next_blast + 1) % _blasts.size()
	_light(blast, position, color, size, time)


## The sound at `path` (loaded once).
func load_sound(path: String) -> AudioStream:
	return _stream(path)


## Plays `stream` at `position` on the next sound slot (the oldest sound is cut off when all are
## busy). `pitch` is a pitch multiplier.
func play(stream: AudioStream, position: Vector3, volume_db: float, pitch: float = 1.0) -> void:
	if stream == null or _players.is_empty():
		return
	var player: AudioStreamPlayer3D = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.global_position = position
	player.play()


## Flashes showing right now.
func active_flashes() -> int:
	var count: int = 0
	for flash: Flash in _flashes + _blasts:
		if flash.left > 0.0:
			count += 1
	return count


## Spark bursts showing right now.
func active_sparks() -> int:
	var count: int = 0
	for kind: int in _sparks:
		for sparks: CPUParticles3D in _sparks[kind]:
			if sparks.emitting:
				count += 1
	return count


## Sounds playing right now.
func active_sounds() -> int:
	var count: int = 0
	for player: AudioStreamPlayer3D in _players:
		if player.playing:
			count += 1
	return count


## Which of the four looks a hit gets: the deepest layer it reached, or `WORLD` with no result.
static func impact_kind(result: DamageResult) -> ImpactKind:
	if result == null:
		return ImpactKind.WORLD
	match result.deepest_layer():
		DamageTable.Layer.SHIELD:
			return ImpactKind.SHIELD
		DamageTable.Layer.ARMOR:
			return ImpactKind.ARMOR
		DamageTable.Layer.HULL:
			return ImpactKind.HULL
		_:
			return ImpactKind.WORLD


## Colour of the flash and sparks for `kind`.
static func impact_color(kind: ImpactKind, weapon: WeaponDef) -> Color:
	match kind:
		ImpactKind.SHIELD:
			return SHIELD_COLOR
		ImpactKind.WORLD:
			return WORLD_COLOR
		_:
			return weapon.impact_color


## The sound of a hit of `kind`.
static func hit_stream(kind: ImpactKind) -> AudioStream:
	match kind:
		ImpactKind.SHIELD:
			return SOUND_HIT_SHIELD
		ImpactKind.ARMOR:
			return SOUND_HIT_ARMOR
		ImpactKind.HULL:
			return SOUND_HIT_HULL
		_:
			return SOUND_HIT_ROCK


## Flash scale 0..1 `left` seconds before the end of a flash lasting `total`: it pops to full and
## shrinks away.
static func flash_scale(left: float, total: float) -> float:
	if total <= 0.0:
		return 0.0
	return clampf(left / total, 0.0, 1.0)


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) as AudioStream
	return _streams[path]


func _start_flash(position: Vector3, color: Color, size: float, time: float) -> void:
	var flash: Flash = _flashes[_next_flash]
	_next_flash = (_next_flash + 1) % _flashes.size()
	_light(flash, position, color, size, time)


func _light(flash: Flash, position: Vector3, color: Color, size: float, time: float) -> void:
	flash.left = time
	flash.total = time
	flash.size = size
	flash.node.global_position = position
	flash.material.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0)
	_draw_flash(flash)


func _draw_flash(flash: Flash) -> void:
	var amount: float = flash_scale(flash.left, flash.total)
	flash.node.visible = flash.left > 0.0
	var diameter: float = flash.size * (0.4 + 0.6 * amount)
	flash.node.scale = Vector3(diameter, diameter, diameter)


func _emit_sparks(kind: int, point: Vector3, normal: Vector3, color: Color) -> void:
	var bursts: Array = _sparks[kind]
	var sparks: CPUParticles3D = bursts[_next_spark[kind]]
	_next_spark[kind] = (_next_spark[kind] + 1) % bursts.size()
	sparks.global_position = point
	sparks.direction = normal if normal.length_squared() > 0.0 else Vector3.UP
	sparks.color = color
	sparks.restart()
	sparks.emitting = true


func _make_flash(keep_scale: bool) -> Flash:
	var flash: Flash = Flash.new()
	var node: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = keep_scale
	material.albedo_texture = _glow
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(node)
	flash.node = node
	flash.material = material
	return flash


func _make_sparks(count: int) -> CPUParticles3D:
	var sparks: CPUParticles3D = CPUParticles3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _glow
	material.albedo_color = Color(1.3, 1.3, 1.3, 1.0)
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	sparks.mesh = quad
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.lifetime = 0.45
	sparks.amount = count
	sparks.spread = 60.0
	sparks.gravity = Vector3.ZERO
	sparks.initial_velocity_min = 12.0
	sparks.initial_velocity_max = 38.0
	sparks.damping_min = 20.0
	sparks.damping_max = 40.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.2
	sparks.local_coords = false
	sparks.draw_order = CPUParticles3D.DRAW_ORDER_INDEX
	sparks.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(sparks)
	return sparks


func _radial_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gradient.colors = PackedColorArray(
		[Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.5), Color(1.0, 1.0, 1.0, 0.0)]
	)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = GLOW_TEXTURE_SIZE
	texture.height = GLOW_TEXTURE_SIZE
	return texture
