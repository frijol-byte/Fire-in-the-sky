extends GdUnitTestSuite
## `FeedbackHud`: hit markers for the player's hits on enemies, damage indicators for hits on the
## player, the kill banner, the low-shield alarm and the banner line, with their timing.

const HUD_SCENE: PackedScene = preload("res://ui/hud/flight_hud.tscn")

var _hud: FlightHud = null
var _feedback: FeedbackHud = null
var _ship: Ship = null
var _enemy: Ship = null


func before_test() -> void:
	_ship = auto_free(FlightSim.spawn(self, &"kestrel")) as Ship
	_enemy = auto_free(FlightSim.spawn(self, &"pirate_fighter")) as Ship
	_enemy.global_position = Vector3(0, 0, -300)
	_hud = auto_free(HUD_SCENE.instantiate()) as FlightHud
	add_child(_hud)
	_hud.bind(_ship)
	_feedback = _hud.feedback()


func _result(shield: float, armor: float, hull: float, destroyed: bool = false) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	result.shield_damage = shield
	result.armor_damage = armor
	result.hull_damage = hull
	result.destroyed = destroyed
	return result


func _hit(target: Node, shooter: Node, result: DamageResult) -> void:
	var info: DamageInfo = DamageInfo.make(5.0, DamageInfo.Type.ENERGY, shooter, Vector3.ZERO)
	Events.ship_damaged.emit(target, info, result)


func test_a_hit_on_an_enemy_makes_the_marker_of_the_layer_it_reached() -> void:
	_hit(_enemy, _ship, _result(5, 0, 0))
	assert_int(_feedback.last_marker()).is_equal(FeedbackMath.Marker.SHIELD)
	_hit(_enemy, _ship, _result(0, 5, 0))
	assert_int(_feedback.last_marker()).is_equal(FeedbackMath.Marker.ARMOR)
	_hit(_enemy, _ship, _result(0, 0, 5))
	assert_int(_feedback.last_marker()).is_equal(FeedbackMath.Marker.HULL)
	_hit(_enemy, _ship, _result(0, 0, 5, true))
	assert_int(_feedback.last_marker()).is_equal(FeedbackMath.Marker.KILL)
	assert_int(_feedback.marker_count()).is_equal(4)
	assert_int(_feedback.indicator_count()).is_equal(0)


func test_somebody_elses_hits_make_no_marker() -> void:
	var other: Ship = auto_free(FlightSim.spawn(self, &"kestrel")) as Ship
	_hit(_enemy, other, _result(5, 0, 0))
	assert_int(_feedback.marker_count()).is_equal(0)


func test_markers_fade_away_and_a_kill_marker_lasts_longer() -> void:
	var def: FeedbackDef = Content.feedback()
	_hit(_enemy, _ship, _result(5, 0, 0))
	_hit(_enemy, _ship, _result(0, 0, 5, true))
	_feedback.advance(def.hit_marker_seconds + 0.01)
	assert_int(_feedback.marker_count()).is_equal(1)
	assert_int(_feedback.last_marker()).is_equal(FeedbackMath.Marker.KILL)
	_feedback.advance(def.kill_marker_seconds)
	assert_int(_feedback.marker_count()).is_equal(0)


func test_a_hit_on_the_player_makes_an_indicator_that_fades() -> void:
	_hit(_ship, _enemy, _result(5, 0, 0))
	assert_int(_feedback.indicator_count()).is_equal(1)
	assert_int(_feedback.marker_count()).is_equal(0)
	_feedback.advance(Content.feedback().indicator_seconds + 0.01)
	assert_int(_feedback.indicator_count()).is_equal(0)


func test_a_hit_from_nowhere_makes_no_indicator() -> void:
	var info: DamageInfo = DamageInfo.make(
		5.0, DamageInfo.Type.KINETIC, null, _ship.global_position
	)
	Events.ship_damaged.emit(_ship, info, _result(5, 0, 0))
	assert_int(_feedback.indicator_count()).is_equal(0)


func test_only_so_many_indicators_show_at_once() -> void:
	var limit: int = Content.feedback().max_indicators
	for _hit_number: int in limit + 3:
		_hit(_ship, _enemy, _result(5, 0, 0))
	assert_int(_feedback.indicator_count()).is_equal(limit)


func test_destroying_something_shows_the_kill_banner_with_its_name() -> void:
	var info: DamageInfo = DamageInfo.make(500.0, DamageInfo.Type.ENERGY, _ship)
	Events.ship_destroyed.emit(_enemy, info)
	assert_str(_feedback.kill_text()).contains("Cinder Raider")
	_feedback.advance(Content.feedback().kill_banner_seconds + 0.1)
	assert_str(_feedback.kill_text()).is_empty()


func test_the_players_own_death_and_other_peoples_kills_show_no_kill_banner() -> void:
	Events.ship_destroyed.emit(_ship, DamageInfo.make(500.0, DamageInfo.Type.ENERGY, _enemy))
	var other: Ship = auto_free(FlightSim.spawn(self, &"kestrel")) as Ship
	Events.ship_destroyed.emit(_enemy, DamageInfo.make(500.0, DamageInfo.Type.ENERGY, other))
	assert_str(_feedback.kill_text()).is_empty()


func test_the_alarm_comes_on_with_a_low_shield_and_goes_off_when_it_recovers() -> void:
	var durability: Durability = _ship.durability()
	_feedback.advance(0.1)
	assert_bool(_feedback.is_alarming()).is_false()
	durability.shield = durability.shield_capacity * 0.2
	_feedback.advance(0.1)
	assert_bool(_feedback.is_alarming()).is_true()
	durability.shield = durability.shield_capacity * 0.3
	_feedback.advance(0.1)
	assert_bool(_feedback.is_alarming()).is_true()
	durability.shield = durability.shield_capacity * 0.5
	_feedback.advance(0.1)
	assert_bool(_feedback.is_alarming()).is_false()


func test_a_destroyed_ship_has_no_alarm() -> void:
	_ship.durability().shield = 0.0
	_ship.durability().apply(DamageInfo.make(100000.0, DamageInfo.Type.EXPLOSIVE))
	_feedback.advance(0.1)
	assert_bool(_feedback.is_alarming()).is_false()


func test_a_banner_shows_for_its_time() -> void:
	_feedback.show_banner("WAVE 2", 3.0)
	assert_str(_feedback.banner_text()).is_equal("WAVE 2")
	_feedback.advance(2.9)
	assert_str(_feedback.banner_text()).is_equal("WAVE 2")
	_feedback.advance(0.2)
	assert_str(_feedback.banner_text()).is_empty()


func test_binding_a_new_ship_forgets_the_old_markers() -> void:
	_hit(_ship, _enemy, _result(5, 0, 0))
	_hit(_enemy, _ship, _result(5, 0, 0))
	_hud.bind(_enemy)
	assert_int(_feedback.indicator_count()).is_equal(0)
	assert_int(_feedback.marker_count()).is_equal(0)


func test_drawing_with_a_camera_does_not_fail() -> void:
	var rig: CameraRig = (
		auto_free((load("res://ships/camera_rig.tscn") as PackedScene).instantiate()) as CameraRig
	)
	add_child(rig)
	rig.attach(_ship)
	_hit(_ship, _enemy, _result(5, 0, 0))
	_hit(_enemy, _ship, _result(0, 0, 5, true))
	_feedback.show_banner("x", 1.0)
	_ship.durability().shield = 1.0
	_feedback.advance(0.1)
	_feedback.queue_redraw()
	await get_tree().process_frame
	assert_bool(_feedback.is_alarming()).is_true()
