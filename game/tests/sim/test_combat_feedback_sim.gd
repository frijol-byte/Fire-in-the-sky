extends GdUnitTestSuite
## The combat feedback in a real fight (M2-T7): a pirate shoots the player (indicators, camera shake,
## the low-shield alarm), the player shoots a dummy (hit markers) and blows it up (kill banner).

const TICK: float = SimHelper.TICK
const HUD_SCENE: PackedScene = preload("res://ui/hud/flight_hud.tscn")

var _player: Ship = null
var _hud: FlightHud = null
var _rig: CameraRig = null
var _feedback: HitFeedback = null


func before_test() -> void:
	Settings.values.clear()
	auto_free(CombatSim.spawn_manager(self))
	_player = auto_free(FlightSim.spawn(self, &"kestrel")) as Ship
	_player.stance = Targeting.Stance.FRIENDLY
	_player.weapons().seed_spread(1)
	_hud = auto_free(HUD_SCENE.instantiate()) as FlightHud
	add_child(_hud)
	_hud.bind(_player)
	_rig = (
		auto_free((load("res://ships/camera_rig.tscn") as PackedScene).instantiate()) as CameraRig
	)
	add_child(_rig)
	_rig.attach(_player)
	_feedback = auto_free(HitFeedback.new()) as HitFeedback
	add_child(_feedback)
	_feedback.bind(_player, _rig)
	await CombatSim.settle(get_tree())


func after_test() -> void:
	Settings.values.clear()
	# Free everything now and give the audio server a few frames to let go of the sounds that are
	# still playing; otherwise they are reported as leaked resources at exit.
	for child: Node in get_children():
		if (
			child is Ship
			or child is TargetDummy
			or child is HitFeedback
			or child is ProjectileManager
			or child is DestructionManager
		):
			child.free()
	_hud.free()
	_rig.free()
	for _frame: int in 3:
		await get_tree().process_frame


func test_a_pirate_shooting_the_player_shows_indicators_shakes_the_camera_and_sounds_the_alarm(
) -> void:
	var pirate: Ship = CombatSim.spawn_ai(
		self,
		&"pirate_fighter",
		Vector3(0, 0, -250),
		Vector3.ZERO,
		Targeting.Stance.HOSTILE,
		&"ace",
		5,
		_player
	)
	auto_free(pirate)
	var indicators: int = 0
	var shaken: bool = false
	for _tick: int in roundi(40.0 / TICK):
		await get_tree().physics_frame
		indicators = maxi(indicators, _hud.feedback().indicator_count())
		shaken = shaken or _rig.shake_now() > 0.0
		if _feedback.alarm_beeps > 0 and indicators > 0 and shaken:
			break
	assert_int(indicators).is_greater(0)
	assert_bool(shaken).is_true()
	assert_int(_feedback.alarm_beeps).is_greater(0)
	assert_bool(_player.durability().shield_fraction() < 0.5).is_true()


func test_the_player_shooting_a_dummy_gets_markers_and_then_a_kill() -> void:
	var dummy: TargetDummy = (
		auto_free(CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -150))) as TargetDummy
	)
	var manager: DestructionManager = auto_free(DestructionManager.new()) as DestructionManager
	add_child(manager)
	await CombatSim.settle(get_tree())
	_player.controls = FlightSim.controls()
	_player.controls.fire_primary = true
	var kinds: Dictionary[int, bool] = {}
	var killed: bool = false
	for _tick: int in roundi(40.0 / TICK):
		await get_tree().physics_frame
		var kind: int = _hud.feedback().last_marker()
		if kind >= 0:
			kinds[kind] = true
		if _hud.feedback().kill_text() != "":
			killed = true
			break
	assert_bool(kinds.has(FeedbackMath.Marker.SHIELD)).is_true()
	assert_bool(kinds.has(FeedbackMath.Marker.KILL)).is_true()
	assert_bool(killed).is_true()
	assert_int(_feedback.kill_sounds).is_equal(1)
	assert_bool(dummy.durability().is_destroyed()).is_true()
