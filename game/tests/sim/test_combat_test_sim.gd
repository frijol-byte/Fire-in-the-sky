extends GdUnitTestSuite
## The combat test arena as a whole (M2-T7): the first wave appears by itself, clearing a wave
## brings the next, dying and respawning starts the wave over, the debug menu picks waves, pirates
## call out their moves on the comms strip and the HUD carries the combat feedback.

const TICK: float = SimHelper.TICK
const ARENA_SCENE: PackedScene = preload("res://world/arenas/combat_test.tscn")
const KILLING_BLOW: float = 100000.0

var _arena: CombatTest = null


func before_test() -> void:
	GameState.reset()
	_arena = ARENA_SCENE.instantiate() as CombatTest
	add_child(_arena)
	await SimHelper.step_physics(get_tree(), 3)


func after_test() -> void:
	if is_instance_valid(_arena):
		remove_child(_arena)
		_arena.free()
	GameState.reset()
	Settings.values.clear()
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.flush_buffered_events()
	for action: String in InputRouter.ACTIONS:
		Input.action_release(action)
	await get_tree().process_frame


func _run(seconds: float) -> void:
	await SimHelper.step_physics(get_tree(), roundi(seconds / TICK))


func _kill(ship: Ship) -> void:
	ship.durability().apply(DamageInfo.make(KILLING_BLOW, DamageInfo.Type.EXPLOSIVE))


func _kill_pirates() -> void:
	for pirate: Ship in _arena.director.pirates.duplicate():
		_kill(pirate)


func test_the_arena_has_no_gates_or_dummies_and_the_three_flight_scenes() -> void:
	assert_int(_arena.get_node("Gates").get_child_count()).is_equal(0)
	assert_int(_arena.get_node("Dummies").get_child_count()).is_equal(0)
	assert_object(_arena.get_node_or_null("Hud/FlightHud")).is_not_null()
	assert_object(_arena.get_node_or_null("DevTools")).is_not_null()
	assert_object(_arena.get_node_or_null("PauseMenu")).is_not_null()
	assert_object(_arena.get_node_or_null("DestructionManager")).is_not_null()
	assert_str(String(_arena.def.id)).is_equal("combat_test")


func test_the_first_wave_comes_by_itself_after_the_delay() -> void:
	assert_int(_arena.director.remaining()).is_equal(0)
	await _run(_arena.director.def.first_wave_delay + 0.3)
	assert_int(_arena.director.remaining()).is_equal(1)
	assert_int(_arena.director.wave_index).is_equal(0)
	var hud: FlightHud = _arena.get_node("Hud/FlightHud") as FlightHud
	assert_str(hud.feedback().banner_text()).contains("WAVE 1")


func test_the_readout_shows_the_wave() -> void:
	await _run(_arena.director.def.first_wave_delay + 0.3)
	assert_str(_arena.readout_text()).contains("Wave 1 of 3")
	assert_str(_arena.readout_text()).contains("Pirates: 1")


func test_clearing_a_wave_brings_the_next_one_with_a_banner() -> void:
	await _run(_arena.director.def.first_wave_delay + 0.3)
	_kill_pirates()
	var hud: FlightHud = _arena.get_node("Hud/FlightHud") as FlightHud
	assert_str(hud.feedback().banner_text()).contains("WAVE 1 CLEARED")
	await _run(_arena.director.def.intermission_seconds + 0.3)
	assert_int(_arena.director.wave_index).is_equal(1)
	assert_int(_arena.director.remaining()).is_equal(2)


func test_dying_and_respawning_starts_the_wave_over() -> void:
	await _run(_arena.director.def.first_wave_delay + 0.3)
	var first: Ship = _arena.director.pirates[0]
	_kill(_arena.ship)
	await _run(6.0)
	var screen: DeathScreen = _arena.get_node("DeathScreen") as DeathScreen
	assert_bool(screen.accepts_input()).is_true()
	screen.request_respawn()
	assert_int(_arena.director.remaining()).is_equal(0)
	await get_tree().process_frame
	assert_bool(is_instance_valid(first) and first.is_inside_tree()).is_false()
	await _run(CombatTest.RESTART_DELAY + 0.3)
	assert_int(_arena.director.wave_index).is_equal(0)
	assert_int(_arena.director.remaining()).is_equal(1)
	var pilot: AIPilot = _arena.director.pirates[0].get_node("AIPilot") as AIPilot
	assert_object(pilot.forced_target).is_same(_arena.ship)


func test_picking_a_wave_from_the_menu_starts_it_after_a_short_wait() -> void:
	var menu: WaveMenu = _arena.get_node("WaveMenu") as WaveMenu
	assert_int(menu.wave_button_count()).is_equal(3)
	menu.open()
	menu.choose_wave(2)
	assert_bool(get_tree().paused).is_false()
	await _run(CombatTest.RESTART_DELAY + 0.3)
	assert_int(_arena.director.wave_index).is_equal(2)
	assert_int(_arena.director.remaining()).is_equal(3)


func test_the_menu_can_skip_a_wave_and_send_the_pirates_away() -> void:
	await _run(_arena.director.def.first_wave_delay + 0.3)
	var menu: WaveMenu = _arena.get_node("WaveMenu") as WaveMenu
	menu.next_requested.emit()
	await _run(CombatTest.RESTART_DELAY + 0.3)
	assert_int(_arena.director.wave_index).is_equal(1)
	menu.clear_requested.emit()
	assert_int(_arena.director.remaining()).is_equal(0)


func test_the_menu_switch_turns_the_slow_motion_setting_on_and_off() -> void:
	var menu: WaveMenu = _arena.get_node("WaveMenu") as WaveMenu
	menu.slowmo_changed.emit(true)
	assert_bool(Settings.get_value(HitFeedback.SETTING_SLOWMO, false) as bool).is_true()
	menu.slowmo_changed.emit(false)
	assert_bool(Settings.get_value(HitFeedback.SETTING_SLOWMO, true) as bool).is_false()


func test_a_pirate_that_changes_behavior_calls_it_out_on_the_comms_strip() -> void:
	await _run(_arena.director.def.first_wave_delay + 0.3)
	var hud: FlightHud = _arena.get_node("Hud/FlightHud") as FlightHud
	var pirate: Ship = _arena.director.pirates[0]
	# Flares always get called out (the chance is 1).
	Events.ai_behavior_changed.emit(pirate, AIUtility.Behavior.USE_DEVICE)
	assert_int(hud.comms().line_count()).is_equal(1)
	var callsign: String = pirate.get_meta(&"callsign") as String
	assert_str(hud.comms().line_text(0)).starts_with(callsign + ": ")


func test_real_pirates_chatter_while_they_fight_the_player() -> void:
	var hud: FlightHud = _arena.get_node("Hud/FlightHud") as FlightHud
	var director: BarkDirector = _arena.get_node("BarkDirector") as BarkDirector
	_arena.director.start(2, 0.0)
	await _run(25.0)
	assert_int(director.barks_total).is_greater(0)
	assert_bool(hud.comms().line_count() > 0 or director.barks_total > 0).is_true()


func test_the_arena_runs_a_long_fight_without_errors() -> void:
	_arena.director.start(2, 0.0)
	_arena.ship.controls = FlightSim.controls(Vector3(0, 0, 0.4), Vector3(0, 0.2, 0))
	await _run(30.0)
	assert_object(_arena.ship).is_not_null()
