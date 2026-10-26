extends GdUnitTestSuite
## The flight arena's death loop (M2-T6): the player's ship is destroyed, the "Ship destroyed"
## screen comes up, a respawn puts a fresh ship at the start and everything is re-bound to it;
## pirates that die leave wrecks and loot, and the tractor fills the debug wallet.

const ARENA_SCENE: PackedScene = preload("res://world/arenas/flight_test.tscn")
const KILLING_BLOW: float = 100000.0

var _arena: FlightTest = null


func before_test() -> void:
	GameState.reset()
	_arena = ARENA_SCENE.instantiate() as FlightTest
	add_child(_arena)
	await SimHelper.step_physics(get_tree(), 3)


func after_test() -> void:
	if is_instance_valid(_arena):
		remove_child(_arena)
		_arena.free()
	GameState.reset()
	Settings.values.clear()
	Input.flush_buffered_events()
	for action: String in InputRouter.ACTIONS:
		Input.action_release(action)
	# Ships the arena took out with `queue_free` (a respawn, a faded pirate) go on the next frame.
	await get_tree().process_frame


func _kill(ship: Ship) -> void:
	ship.durability().apply(DamageInfo.make(KILLING_BLOW, DamageInfo.Type.EXPLOSIVE))


func _death_screen() -> DeathScreen:
	return _arena.get_node("DeathScreen") as DeathScreen


func test_the_death_screen_comes_up_after_the_blast_and_waits_for_the_button() -> void:
	var look: DestructionDef = Content.destruction()
	_kill(_arena.ship)
	var screen: DeathScreen = _death_screen()
	assert_bool(screen.is_pending()).is_true()
	assert_bool(screen.is_open()).is_false()
	await SimHelper.step_physics(
		get_tree(), roundi((look.death_screen_delay + 0.2) / SimHelper.TICK)
	)
	assert_bool(screen.is_open()).is_true()
	assert_bool(screen.accepts_input()).is_false()
	await SimHelper.step_physics(
		get_tree(), roundi((look.respawn_input_delay + 0.2) / SimHelper.TICK)
	)
	assert_bool(screen.accepts_input()).is_true()


func test_respawning_puts_a_fresh_ship_at_the_start_and_rebinds_everything() -> void:
	var old: Ship = _arena.ship
	var start: Vector3 = _arena.def.spawn_position
	await FlightSim.fly(get_tree(), old, FlightSim.controls(Vector3(0, 0, 1)), 60)
	_kill(old)
	await SimHelper.step_physics(get_tree(), 400)
	var screen: DeathScreen = _death_screen()
	assert_bool(screen.accepts_input()).is_true()
	screen.request_respawn()
	var ship: Ship = _arena.ship
	assert_object(ship).is_not_same(old)
	assert_bool(is_instance_valid(old) and old.is_inside_tree()).is_false()
	assert_bool(ship.is_inside_tree()).is_true()
	assert_bool(ship.is_wrecked()).is_false()
	assert_bool(ship.durability().is_destroyed()).is_false()
	assert_float(ship.durability().hull).is_equal(ship.def.hull_capacity)
	assert_vector(ship.global_position).is_equal_approx(start, Vector3.ONE * 0.5)
	assert_str(String(ship.def.id)).is_equal(
		String(old.def.id) if is_instance_valid(old) else "kestrel"
	)
	assert_bool(screen.is_open()).is_false()
	var hud: FlightHud = _arena.get_node("Hud/FlightHud") as FlightHud
	assert_object(hud.ship).is_same(ship)
	assert_object((_arena.get_node("CameraRig") as CameraRig).ship).is_same(ship)
	var pilots: int = 0
	for child: Node in ship.get_children():
		if child is PlayerPilot:
			pilots += 1
	assert_int(pilots).is_equal(1)
	assert_bool(ship.targeting().is_player).is_true()


func test_the_respawned_ship_keeps_the_class_the_player_was_flying() -> void:
	_arena.spawn_player(&"drayman")
	await SimHelper.step_physics(get_tree(), 3)
	_kill(_arena.ship)
	await SimHelper.step_physics(get_tree(), 400)
	_death_screen().request_respawn()
	assert_str(String(_arena.ship.def.id)).is_equal("drayman")


func test_the_wallet_survives_a_death_for_now() -> void:
	GameState.add_credits(120)
	_kill(_arena.ship)
	await SimHelper.step_physics(get_tree(), 400)
	_death_screen().request_respawn()
	assert_int(GameState.credits).is_equal(120)


func test_switching_ship_while_dead_also_closes_the_screen() -> void:
	_kill(_arena.ship)
	await SimHelper.step_physics(get_tree(), 400)
	assert_bool(_death_screen().is_open()).is_true()
	_arena.spawn_player(&"bulwark")
	assert_bool(_death_screen().is_open()).is_false()


func test_a_dead_pirate_leaves_the_pirate_list_and_drops_loot() -> void:
	var pirate: Ship = _arena.call_pirate()
	await SimHelper.step_physics(get_tree(), 5)
	assert_array(_arena.pirates).has_size(1)
	_kill(pirate)
	assert_array(_arena.pirates).is_empty()
	var manager: DestructionManager = _arena.get_node("DestructionManager") as DestructionManager
	assert_int(manager.loot.count()).is_greater(0)
	await SimHelper.step_physics(get_tree(), roundi(4.0 / SimHelper.TICK))
	assert_bool(is_instance_valid(pirate) and pirate.is_inside_tree()).is_false()
	# More pirates can still be called in and cleared after one died.
	_arena.call_pirate()
	_arena.clear_pirates()
	assert_array(_arena.pirates).is_empty()


func test_the_player_tractors_the_loot_of_a_dead_pirate_into_the_wallet() -> void:
	var pirate: Ship = _arena.call_pirate()
	# The player's ship at the start is far from the pirate: move the pirate close first.
	pirate.global_position = _arena.ship.global_position + Vector3(0, 0, -150)
	await SimHelper.step_physics(get_tree(), 2)
	pirate.global_position = _arena.ship.global_position + Vector3(0, 0, -150)
	_kill(pirate)
	await SimHelper.step_physics(get_tree(), roundi(10.0 / SimHelper.TICK))
	var manager: DestructionManager = _arena.get_node("DestructionManager") as DestructionManager
	assert_int(manager.loot.collected_total).is_greater(0)
	assert_int(GameState.credits + GameState.material_count(&"scrap_metal")).is_greater(0)
	assert_str(_arena.wallet_text()).contains(str(GameState.credits))


func test_the_readout_shows_the_debug_wallet() -> void:
	GameState.add_credits(75)
	GameState.add_material(&"coolant", 2)
	var text: String = _arena.wallet_text()
	assert_str(text).contains("75")
	assert_str(text).contains(tr("MATERIAL_COOLANT") % 2)
	GameState.reset()
	assert_str(_arena.wallet_text()).contains(tr("ARENA_WALLET_NONE"))
