class_name FlightTest
extends Node3D
## The flight test arena: an amber nebula sky with a sun, an asteroid belt around the start and
## a course of ring gates. Everything about it is in `data/arenas/flight_test.tres`; this script
## builds it from that data and wires the player's ship to the camera, the speed effects and the
## flight sounds.
##
## The ship is spawned by `spawn_player()`. The ship switcher (device slots 1-3: keys 1/2/3 or the
## D-pad) calls it again with the arena's `selectable_ship_ids`. It is a demo-only stand-in: the
## D-pad belongs to devices from M2.
## It also carries the flight HUD, the tuning overlay and bug capture (`DevTools`) and the pause
## menu (Esc / Start), like every flight scene (M1-T6).

const ARENA_ID: StringName = &"flight_test"
const SHIP_SCENE: PackedScene = preload("res://ships/ship.tscn")
const GATE_SCENE: PackedScene = preload("res://world/props/ring_gate.tscn")
const CAMERA_RIG_SCENE: PackedScene = preload("res://ships/camera_rig.tscn")
const DUMMY_SCENE: PackedScene = preload("res://world/props/target_dummy.tscn")

## Until the sky is baked (and always in a headless run) the background is this plain colour.
const FALLBACK_AMBIENT: Color = Color(0.35, 0.3, 0.28)

var def: ArenaDef = null
var ship: Ship = null
var gates_passed: int = 0

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _fill: DirectionalLight3D = $Fill
@onready var _sky_baker: SkyBaker = $SkyBaker
@onready var _field: AsteroidField = $AsteroidField
@onready var _gates: Node3D = $Gates
@onready var _dummies: Node3D = $Dummies
@onready var _rig: CameraRig = $CameraRig
@onready var _speed_fx: SpeedFx = $SpeedFx
@onready var _audio: ShipAudio = $ShipAudio
@onready var _readout: Label = $Readout
@onready var _help: Label = $Help
@onready var _hud: FlightHud = $Hud/FlightHud
@onready var _tools: DevTools = $DevTools


func _ready() -> void:
	def = Content.get_def(&"arena", ARENA_ID) as ArenaDef
	if def == null:
		Log.error(&"arena", "no ArenaDef '%s'" % ARENA_ID)
		return
	_configure_light()
	_environment.environment = make_environment(def, null)
	_build_gates()
	_build_dummies()
	_field.build(def, course_line(def))
	spawn_player(def.spawn_ship_id)
	# Free look is off by default (the right stick aims); the arena turns it on to try it out.
	Settings.set_value(InputRouter.SETTING_FREE_LOOK, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Events.input_device_changed.connect(_on_input_device_changed)
	_update_help()
	Game.set_state(Game.State.SPACE)
	_bake_sky()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(_delta: float) -> void:
	var wanted: StringName = ship_for_slot(def, InputRouter.controls.device)
	if wanted != &"" and ship != null and wanted != ship.def.id:
		spawn_player(wanted)


func _process(_delta: float) -> void:
	if ship == null:
		return
	# Speed, flight assist, boost and energy are on the flight HUD; this is the ship and the course.
	_readout.text = (
		"%s\n%s"
		% [
			tr("ARENA_SHIP") % [tr(ship.def.display_name_key), _switch_glyphs()],
			tr("ARENA_GATES") % gates_passed,
		]
	)


## Puts the player in a new ship of `ship_id` at the start, replacing the old one.
func spawn_player(ship_id: StringName) -> Ship:
	if ship != null:
		# Out of the tree at once, so the old body cannot push against the new one.
		remove_child(ship)
		ship.queue_free()
		ship = null
	var new_ship: Ship = SHIP_SCENE.instantiate() as Ship
	new_ship.def = Content.ship(ship_id)
	new_ship.name = "Ship"
	add_child(new_ship)
	new_ship.global_transform = Transform3D(
		Basis.looking_at(def.spawn_look_at - def.spawn_position, Vector3.UP), def.spawn_position
	)
	new_ship.add_child(PlayerPilot.new())
	InputRouter.recenter_mouse()
	ship = new_ship
	_rig.attach(ship)
	_speed_fx.attach(ship)
	_audio.attach(ship)
	_field.follow(ship)
	_hud.bind(ship)
	_tools.bind(ship, _rig)
	return ship


## The ship the device slot (1-3, 0 = none pressed) selects in `arena`, or `&""` if the slot is
## empty or the arena has no such ship.
static func ship_for_slot(arena: ArenaDef, slot: int) -> StringName:
	if arena == null or slot < 1 or slot > arena.selectable_ship_ids.size():
		return &""
	return arena.selectable_ship_ids[slot - 1]


## The world environment for `arena`: the baked `sky`, or a plain colour when there is none.
static func make_environment(arena: ArenaDef, sky: Sky) -> Environment:
	var environment: Environment = Environment.new()
	if sky != null:
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = arena.sky_space_color
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = FALLBACK_AMBIENT
	environment.ambient_light_energy = arena.ambient_energy
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = arena.glow_intensity
	environment.glow_bloom = arena.glow_bloom
	environment.glow_hdr_threshold = arena.glow_threshold
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	return environment


func _configure_light() -> void:
	_sun.light_energy = def.sun_light_energy
	_sun.light_color = def.sun_light_color
	_sun.basis = Basis.looking_at(def.light_direction(), Vector3.UP)
	# The fill comes from the other side: it travels towards the sun.
	_fill.light_energy = def.fill_light_energy
	_fill.light_color = def.fill_light_color
	_fill.basis = Basis.looking_at(-def.light_direction(), Vector3.UP)


func _bake_sky() -> void:
	var sky: Sky = await _sky_baker.bake(def)
	if sky != null:
		_environment.environment = make_environment(def, sky)


func _build_gates() -> void:
	for gate_transform: Transform3D in def.gate_transforms:
		var gate: RingGate = GATE_SCENE.instantiate() as RingGate
		_gates.add_child(gate)
		gate.transform = gate_transform.scaled_local(Vector3.ONE * def.gate_scale)
		gate.passed.connect(_on_gate_passed)


func _build_dummies() -> void:
	for index: int in def.dummy_ids.size():
		var dummy_def: DummyDef = Content.dummy(def.dummy_ids[index])
		if dummy_def == null:
			Log.error(&"arena", "no DummyDef '%s'" % def.dummy_ids[index])
			continue
		var dummy: TargetDummy = DUMMY_SCENE.instantiate() as TargetDummy
		dummy.name = "Dummy%d" % index
		# Placed before it enters the tree: a body that starts at the origin would shove a ship
		# spawned there (the start) until its first physics step moves it.
		dummy.position = def.dummy_origins[index]
		_dummies.add_child(dummy)
		dummy.setup(dummy_def, def.dummy_origins[index], def.dummy_rails[index])


## The line of the course: the start, then every gate in order.
static func course_line(arena: ArenaDef) -> PackedVector3Array:
	var result: PackedVector3Array = [arena.spawn_position]
	for gate_transform: Transform3D in arena.gate_transforms:
		result.append(gate_transform.origin)
	return result


func _on_gate_passed(_ship: Ship) -> void:
	gates_passed += 1


func _switch_glyphs() -> String:
	var glyphs: PackedStringArray = []
	for slot: int in def.selectable_ship_ids.size():
		glyphs.append(InputRouter.glyph_for(StringName("device_%d" % (slot + 1))))
	return " ".join(glyphs)


func _on_input_device_changed(_device: int) -> void:
	_update_help()


func _update_help() -> void:
	_help.text = (
		tr("ARENA_HELP")
		% [
			InputRouter.glyph_for(&"thrust_forward"),
			InputRouter.glyph_for(&"thrust_back"),
			InputRouter.glyph_for(&"boost"),
			InputRouter.glyph_for(&"fire_primary"),
			InputRouter.glyph_for(&"camera_toggle"),
			InputRouter.glyph_for(&"pause"),
		]
	)
	_help.text += (
		"\n"
		+ (
			tr("ARENA_HELP_TARGET")
			% [InputRouter.glyph_for(&"target_nearest"), InputRouter.glyph_for(&"look_at_target")]
		)
	)
	# The drift button is optional: the gamepad has none for now (see GDD 5).
	var drift: String = InputRouter.glyph_for(&"flight_assist_off")
	if drift != tr("GLYPH_UNBOUND"):
		_help.text += tr("ARENA_HELP_DRIFT") % drift
