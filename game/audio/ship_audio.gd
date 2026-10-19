class_name ShipAudio
extends Node
## The player's flight sounds: an engine hum whose pitch and volume follow the throttle, a
## wind-like hiss that grows with speed, and a whoosh when boost starts. The sounds are placeholders
## made by `tools/audio/make_placeholder_audio.py`; the audio pass (M8) swaps in real recordings
## and routes them through proper buses.
##
## Pitch and volume are pure functions of the ship's state so they can be unit tested.
##
## The hum and the hiss loop (`edit/loop_mode` in their `.wav.import`), and all three are stored as
## plain PCM (`compress/mode=0`); the default QOA compression would add artefacts to a loop.

const ENGINE_STREAM: AudioStreamWAV = preload("res://assets/audio/sfx/engine_hum.wav")
const HISS_STREAM: AudioStreamWAV = preload("res://assets/audio/sfx/dust_hiss.wav")
const WHOOSH_STREAM: AudioStreamWAV = preload("res://assets/audio/sfx/boost_whoosh.wav")

## Engine hum: playback speed at idle and at full power, and extra for speed.
const PITCH_IDLE: float = 0.7
const PITCH_FULL: float = 1.35
const PITCH_PER_SPEED: float = 0.2
## Engine hum loudness (dB) at idle and at full power, plus the boost bonus.
const ENGINE_DB_IDLE: float = -24.0
const ENGINE_DB_FULL: float = -10.0
const ENGINE_DB_BOOST: float = 3.0
## Hiss loudness: silent at rest, this loud at top speed.
const HISS_DB_TOP: float = -14.0
const SILENT_DB: float = -60.0
const WHOOSH_DB: float = -6.0

var _ship: Ship = null
var _engine: AudioStreamPlayer = AudioStreamPlayer.new()
var _hiss: AudioStreamPlayer = AudioStreamPlayer.new()
var _whoosh: AudioStreamPlayer = AudioStreamPlayer.new()
var _level: float = 0.0
var _was_boosting: bool = false


func _ready() -> void:
	_engine.stream = ENGINE_STREAM
	_hiss.stream = HISS_STREAM
	_whoosh.stream = WHOOSH_STREAM
	_whoosh.volume_db = WHOOSH_DB
	for player: AudioStreamPlayer in [_engine, _hiss, _whoosh]:
		add_child(player)
	_engine.volume_db = SILENT_DB
	_hiss.volume_db = SILENT_DB
	_engine.play()
	_hiss.play()


func _exit_tree() -> void:
	# A sound still playing when the game quits is reported as a leaked resource.
	for player: AudioStreamPlayer in [_engine, _hiss, _whoosh]:
		player.stop()


func _process(delta: float) -> void:
	if _ship == null or not is_instance_valid(_ship):
		return
	update(delta)


## Follows `ship`.
func attach(ship: Ship) -> void:
	_ship = ship
	_level = EngineFx.IDLE_LEVEL
	_was_boosting = false


## Advances the sound by `delta` seconds from the ship's state. `_process` calls it every frame;
## tests call it directly.
func update(delta: float) -> void:
	var boosting: bool = _ship.is_boosting()
	_level = EngineFx.level_step(
		_level, EngineFx.target_level(_ship.controls.thrust.z, boosting), delta
	)
	var fraction: float = speed_fraction(_ship.linear_velocity.length(), _ship.def.boost_max_speed)
	_engine.pitch_scale = engine_pitch(_level, fraction)
	_engine.volume_db = engine_volume_db(_level, boosting)
	_hiss.volume_db = hiss_volume_db(fraction)
	if boosting and not _was_boosting:
		_whoosh.play()
	_was_boosting = boosting


## Speed as a 0..1 fraction of `top_speed`.
static func speed_fraction(speed: float, top_speed: float) -> float:
	return clampf(speed / maxf(top_speed, 0.001), 0.0, 1.0)


## Playback speed of the engine hum for an engine `level` (0..1) and `speed_fraction` (0..1).
static func engine_pitch(level: float, fraction: float) -> float:
	return lerpf(PITCH_IDLE, PITCH_FULL, clampf(level, 0.0, 1.0)) + PITCH_PER_SPEED * fraction


## Loudness of the engine hum in dB.
static func engine_volume_db(level: float, boosting: bool) -> float:
	var db: float = lerpf(ENGINE_DB_IDLE, ENGINE_DB_FULL, clampf(level, 0.0, 1.0))
	return db + (ENGINE_DB_BOOST if boosting else 0.0)


## Loudness of the speed hiss in dB: silent at rest, rising with the square of the speed.
static func hiss_volume_db(fraction: float) -> float:
	var amount: float = clampf(fraction, 0.0, 1.0)
	amount *= amount
	return lerpf(SILENT_DB, HISS_DB_TOP, amount)
