class_name HitFeedback
extends Node
## The non-visual half of the combat feedback (GDD 7.4, M2-T7): the camera shakes when the player
## is hit, when the player's ship is destroyed and when something blows up nearby; the low-shield
## alarm beeps while the shield is low; a kill gets its confirmation sound; and, when the setting
## `feedback/kill_slowmo` is on, the last enemy's destruction slows the game for a moment. The
## markers, indicators and bars are `FeedbackHud`. Numbers: `data/combat/feedback_default.tres`;
## rules: `FeedbackMath`.
##
## Each flight scene with fighting carries one and calls `bind` with the player's ship and camera
## rig (again after every respawn).

## Settings key: slow down for a moment when the last enemy goes down. Off unless the player (or
## the debug menu) turns it on.
const SETTING_SLOWMO: String = "feedback/kill_slowmo"
const SOUND_ALARM: AudioStreamWAV = preload("res://assets/audio/sfx/low_shield_alarm.wav")
const SOUND_KILL: AudioStreamWAV = preload("res://assets/audio/sfx/kill_confirm.wav")
const ALARM_DB: float = -8.0
const KILL_DB: float = -4.0

var def: FeedbackDef = null
var ship: Ship = null
var rig: CameraRig = null
## How many times the alarm has beeped and the kill sound has played (for tests).
var alarm_beeps: int = 0
var kill_sounds: int = 0

var _alarm_on: bool = false
var _beep_left: float = 0.0
var _alarm_player: AudioStreamPlayer = AudioStreamPlayer.new()
var _kill_player: AudioStreamPlayer = AudioStreamPlayer.new()
var _slowmo_serial: int = 0


func _ready() -> void:
	def = Content.feedback()
	_alarm_player.stream = SOUND_ALARM
	_alarm_player.volume_db = ALARM_DB
	_kill_player.stream = SOUND_KILL
	_kill_player.volume_db = KILL_DB
	for player: AudioStreamPlayer in [_alarm_player, _kill_player]:
		# A sound still playing as the scene leaves the tree is reported as a leaked resource.
		player.tree_exiting.connect(player.stop)
		add_child(player)
	Events.ship_damaged.connect(_on_ship_damaged)
	Events.ship_destroyed.connect(_on_ship_destroyed)


func _exit_tree() -> void:
	if Events.ship_damaged.is_connected(_on_ship_damaged):
		Events.ship_damaged.disconnect(_on_ship_damaged)
	if Events.ship_destroyed.is_connected(_on_ship_destroyed):
		Events.ship_destroyed.disconnect(_on_ship_destroyed)
	end_slowmo()


func _process(delta: float) -> void:
	advance(delta)


## Follows the player's `new_ship` and shakes `new_rig`'s camera.
func bind(new_ship: Ship, new_rig: CameraRig) -> void:
	ship = new_ship
	rig = new_rig
	_alarm_on = false
	_beep_left = 0.0


## Moves the alarm on by `delta` seconds. `_process` calls it; tests call it directly.
func advance(delta: float) -> void:
	if ship == null or not is_instance_valid(ship):
		_alarm_on = false
		return
	var durability: Durability = ship.durability()
	_alarm_on = (
		not durability.is_destroyed()
		and FeedbackMath.alarm_on(
			_alarm_on, durability.shield_fraction(), durability.shield_capacity, def
		)
	)
	if not _alarm_on:
		_beep_left = 0.0
		return
	_beep_left -= delta
	if _beep_left <= 0.0:
		_beep_left = def.alarm_interval
		alarm_beeps += 1
		_alarm_player.play()


func is_alarming() -> bool:
	return _alarm_on


## True while the game is slowed down for a kill.
func is_slowed() -> bool:
	return _slowmo_serial > 0 and Engine.time_scale < 1.0


## Slows the game for `def.slowmo_seconds` of real time (when the setting is on).
func kill_slowmo() -> void:
	if not Settings.get_value(SETTING_SLOWMO, false):
		return
	_slowmo_serial += 1
	var serial: int = _slowmo_serial
	Engine.time_scale = def.slowmo_scale
	await get_tree().create_timer(def.slowmo_seconds, true, false, true).timeout
	if serial == _slowmo_serial:
		end_slowmo()


## Back to full speed.
func end_slowmo() -> void:
	_slowmo_serial = 0
	Engine.time_scale = 1.0


func _on_ship_damaged(node: Node, _info: DamageInfo, result: DamageResult) -> void:
	if node != ship or rig == null:
		return
	var strength: float = FeedbackMath.hit_shake(result, def)
	if strength > 0.0:
		rig.shake(strength, def.shake_hit_seconds)


func _on_ship_destroyed(node: Node, info: DamageInfo) -> void:
	if ship == null or not is_instance_valid(ship) or rig == null:
		return
	if node == ship:
		rig.shake(def.shake_death, def.shake_death_seconds)
		return
	if node is Node3D:
		var distance: float = (node as Node3D).global_position.distance_to(ship.global_position)
		var strength: float = FeedbackMath.explosion_shake(distance, def)
		if strength > 0.0:
			rig.shake(strength, def.shake_explosion_seconds)
	if info.source == ship:
		kill_sounds += 1
		_kill_player.play()
		if not _hostiles_left(node):
			kill_slowmo()


## True while a living hostile ship other than `except` is in play.
func _hostiles_left(except: Node) -> bool:
	for node: Node in get_tree().get_nodes_in_group(Targeting.GROUP):
		var other: Ship = node as Ship
		if other != null and other != except and not other.is_wrecked():
			if other.stance == Targeting.Stance.HOSTILE:
				return true
	return false
