extends GdUnitTestSuite
## `HitFeedback`: the camera shakes when the player is hit, dies or sees an explosion; the
## low-shield alarm beeps at its interval; kills play their sound; and the optional slow-motion tick
## follows the last enemy only.

var _feedback: HitFeedback = null
var _rig: CameraRig = null
var _ship: Ship = null
var _enemy: Ship = null
var _def: FeedbackDef = null


func before_test() -> void:
	Settings.values.clear()
	_ship = auto_free(FlightSim.spawn(self, &"kestrel")) as Ship
	_ship.stance = Targeting.Stance.FRIENDLY
	_enemy = auto_free(FlightSim.spawn(self, &"pirate_fighter")) as Ship
	_enemy.global_position = Vector3(0, 0, -300)
	_rig = (
		auto_free((load("res://ships/camera_rig.tscn") as PackedScene).instantiate()) as CameraRig
	)
	add_child(_rig)
	_rig.set_process(false)
	_rig.attach(_ship)
	_feedback = auto_free(HitFeedback.new()) as HitFeedback
	add_child(_feedback)
	_feedback.bind(_ship, _rig)
	_def = _feedback.def


func after_test() -> void:
	_feedback.end_slowmo()
	Settings.values.clear()


func _result(shield: float, armor: float, hull: float) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	result.shield_damage = shield
	result.armor_damage = armor
	result.hull_damage = hull
	return result


func test_a_hit_on_the_player_shakes_the_camera_by_how_much_it_hurt() -> void:
	var info: DamageInfo = DamageInfo.make(5.0, DamageInfo.Type.ENERGY, _enemy)
	Events.ship_damaged.emit(_ship, info, _result(4, 0, 0))
	var light: float = _rig.shake_now()
	assert_float(light).is_greater(0.0)
	Events.ship_damaged.emit(_ship, info, _result(0, 0, 20))
	assert_float(_rig.shake_now()).is_greater(light)


func test_hits_on_other_ships_do_not_shake_the_camera() -> void:
	var info: DamageInfo = DamageInfo.make(5.0, DamageInfo.Type.ENERGY, _ship)
	Events.ship_damaged.emit(_enemy, info, _result(0, 0, 20))
	assert_float(_rig.shake_now()).is_equal(0.0)


func test_the_players_death_shakes_hard() -> void:
	Events.ship_destroyed.emit(_ship, DamageInfo.make(500.0, DamageInfo.Type.ENERGY, _enemy))
	assert_float(_rig.shake_now()).is_equal_approx(_def.shake_death, 0.0001)


func test_a_near_explosion_shakes_and_a_far_one_does_not() -> void:
	_enemy.global_position = _ship.global_position + Vector3(0, 0, -100)
	Events.ship_destroyed.emit(_enemy, DamageInfo.make(500.0, DamageInfo.Type.ENERGY))
	var near: float = _rig.shake_now()
	assert_float(near).is_greater(0.0)
	assert_float(near).is_less(_def.shake_explosion_max)
	var far_rig: CameraRig = _rig
	far_rig.attach(_ship)
	_enemy.global_position = (
		_ship.global_position + Vector3(0, 0, -(_def.shake_explosion_range_m + 50.0))
	)
	var before: float = _rig.shake_now()
	Events.ship_destroyed.emit(_enemy, DamageInfo.make(500.0, DamageInfo.Type.ENERGY))
	assert_float(_rig.shake_now()).is_less_equal(before)


func test_the_alarm_beeps_while_the_shield_is_low_and_at_its_interval() -> void:
	_ship.durability().shield = _ship.durability().shield_capacity * 0.1
	_feedback.advance(0.0)
	assert_bool(_feedback.is_alarming()).is_true()
	assert_int(_feedback.alarm_beeps).is_equal(1)
	_feedback.advance(_def.alarm_interval * 0.5)
	assert_int(_feedback.alarm_beeps).is_equal(1)
	_feedback.advance(_def.alarm_interval * 0.6)
	assert_int(_feedback.alarm_beeps).is_equal(2)


func test_the_alarm_is_quiet_with_a_healthy_shield() -> void:
	_feedback.advance(5.0)
	assert_bool(_feedback.is_alarming()).is_false()
	assert_int(_feedback.alarm_beeps).is_equal(0)


func test_a_kill_by_the_player_plays_the_confirmation_sound() -> void:
	Events.ship_destroyed.emit(_enemy, DamageInfo.make(500.0, DamageInfo.Type.ENERGY, _ship))
	assert_int(_feedback.kill_sounds).is_equal(1)
	Events.ship_destroyed.emit(_enemy, DamageInfo.make(500.0, DamageInfo.Type.ENERGY, _enemy))
	assert_int(_feedback.kill_sounds).is_equal(1)


func test_slow_motion_is_off_unless_the_setting_is_on() -> void:
	_feedback.kill_slowmo()
	assert_float(Engine.time_scale).is_equal(1.0)
	Settings.set_value(HitFeedback.SETTING_SLOWMO, true)
	_feedback.kill_slowmo()
	assert_float(Engine.time_scale).is_equal(_def.slowmo_scale)
	assert_bool(_feedback.is_slowed()).is_true()
	_feedback.end_slowmo()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_the_tick_follows_the_last_enemy_only() -> void:
	Settings.set_value(HitFeedback.SETTING_SLOWMO, true)
	_enemy.stance = Targeting.Stance.HOSTILE
	var second: Ship = auto_free(FlightSim.spawn(self, &"pirate_interceptor")) as Ship
	second.stance = Targeting.Stance.HOSTILE
	second.global_position = Vector3(50, 0, -300)
	Events.ship_destroyed.emit(_enemy, DamageInfo.make(500.0, DamageInfo.Type.ENERGY, _ship))
	assert_float(Engine.time_scale).is_equal(1.0)
	second.begin_wreck(Content.destruction(), Vector3.ZERO)
	Events.ship_destroyed.emit(_enemy, DamageInfo.make(500.0, DamageInfo.Type.ENERGY, _ship))
	assert_float(Engine.time_scale).is_equal(_def.slowmo_scale)
