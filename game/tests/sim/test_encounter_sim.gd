extends GdUnitTestSuite
## `EncounterDirector` with real ships: waves appear around the player after their delay, a wave is
## cleared when its last pirate is destroyed, the next one follows after the intermission, the
## last loops (or ends the encounter), and a restart brings the same wave back.

const KILLING_BLOW: float = 100000.0

var _world: Node3D = null
var _player: Ship = null
var _director: EncounterDirector = null
var _def: EncounterDef = null
var _events: Array[String] = []


func before_test() -> void:
	_events.clear()
	_world = auto_free(Node3D.new()) as Node3D
	add_child(_world)
	_player = FlightSim.spawn(_world, &"kestrel")
	_player.stance = Targeting.Stance.FRIENDLY
	_def = Content.encounter(&"combat_test").duplicate() as EncounterDef
	# Most tests want the whole wave at once; the stagger has its own tests.
	_def.stagger_seconds = 0.0
	_director = EncounterDirector.new()
	_world.add_child(_director)
	_director.setup(_def, _world)
	_director.bind_player(_player)
	_director.wave_started.connect(
		func(index: int, count: int) -> void: _events.append("start %d x%d" % [index, count])
	)
	_director.wave_cleared.connect(func(index: int) -> void: _events.append("clear %d" % index))
	_director.encounter_complete.connect(func() -> void: _events.append("complete"))


func after_test() -> void:
	# Ships freed with `queue_free` go on the next frame.
	await get_tree().process_frame


func _kill_all() -> void:
	for pirate: Ship in _director.pirates.duplicate():
		pirate.durability().apply(DamageInfo.make(KILLING_BLOW, DamageInfo.Type.EXPLOSIVE))


func test_nothing_appears_until_the_first_wave_delay_is_over() -> void:
	_director.start(0)
	_director.advance(_def.first_wave_delay - 0.1)
	assert_int(_director.remaining()).is_equal(0)
	assert_int(_director.state).is_equal(EncounterDirector.State.WAITING)
	_director.advance(0.2)
	assert_int(_director.remaining()).is_equal(1)
	assert_int(_director.state).is_equal(EncounterDirector.State.ACTIVE)
	assert_array(_events).contains_exactly(["start 0 x1"])


func test_pirates_are_hostile_ai_ships_hunting_the_player() -> void:
	_director.start(1, 0.0)
	assert_int(_director.remaining()).is_equal(2)
	for pirate: Ship in _director.pirates:
		assert_int(pirate.stance).is_equal(Targeting.Stance.HOSTILE)
		var pilot: AIPilot = pirate.get_node("AIPilot") as AIPilot
		assert_object(pilot.forced_target).is_same(_player)
		assert_object(pilot.profile).is_not_null()
		assert_bool(pirate.has_meta(&"callsign")).is_true()
		assert_str(pirate.get_meta(&"callsign") as String).is_not_empty()
		assert_float(pirate.global_position.distance_to(_player.global_position)).is_equal_approx(
			_def.spawn_distance_m, 1.0
		)
	assert_str(String(_director.pirates[0].def.id)).is_equal("pirate_fighter")
	assert_str(String(_director.pirates[1].def.id)).is_equal("pirate_interceptor")
	assert_str(String(_director.pirates[1].get_node("AIPilot").profile.id)).is_equal("rookie")


func test_each_pirate_has_its_own_callsign() -> void:
	_director.start(2, 0.0)
	var names: Array[String] = []
	for pirate: Ship in _director.pirates:
		var callsign: String = pirate.get_meta(&"callsign") as String
		assert_array(names).not_contains([callsign])
		names.append(callsign)


func test_killing_the_last_pirate_clears_the_wave_and_the_next_one_follows() -> void:
	_director.start(0, 0.0)
	_kill_all()
	assert_int(_director.remaining()).is_equal(0)
	assert_int(_director.state).is_equal(EncounterDirector.State.CLEARED)
	assert_array(_events).contains_exactly(["start 0 x1", "clear 0"])
	_director.advance(_def.intermission_seconds - 0.1)
	assert_int(_director.remaining()).is_equal(0)
	_director.advance(0.2)
	assert_int(_director.remaining()).is_equal(2)
	assert_int(_director.wave_index).is_equal(1)
	assert_str(_events[-1]).is_equal("start 1 x2")


func test_a_wave_is_not_cleared_while_a_pirate_is_left() -> void:
	_director.start(1, 0.0)
	var first: Ship = _director.pirates[0]
	first.durability().apply(DamageInfo.make(KILLING_BLOW, DamageInfo.Type.EXPLOSIVE))
	assert_int(_director.remaining()).is_equal(1)
	assert_int(_director.state).is_equal(EncounterDirector.State.ACTIVE)
	assert_array(_events).contains_exactly(["start 1 x2"])


func test_the_encounter_loops_back_to_the_first_wave() -> void:
	_director.start(2, 0.0)
	_kill_all()
	assert_int(_director.state).is_equal(EncounterDirector.State.CLEARED)
	_director.advance(_def.intermission_seconds + 0.1)
	assert_int(_director.wave_index).is_equal(0)
	assert_int(_director.remaining()).is_equal(1)
	assert_bool(_events.has("complete")).is_false()


func test_without_a_loop_the_last_wave_ends_the_encounter() -> void:
	_def.loop = false
	_director.start(2, 0.0)
	_kill_all()
	assert_int(_director.state).is_equal(EncounterDirector.State.IDLE)
	assert_array(_events).contains_exactly(["start 2 x3", "clear 2", "complete"])
	_director.advance(100.0)
	assert_int(_director.remaining()).is_equal(0)


func test_restarting_a_wave_sends_the_pirates_away_and_brings_the_same_wave_back() -> void:
	_director.start(1, 0.0)
	var old: Array[Ship] = _director.pirates.duplicate()
	_director.restart_wave(-1, 2.0)
	assert_int(_director.remaining()).is_equal(0)
	assert_int(_director.state).is_equal(EncounterDirector.State.WAITING)
	await get_tree().process_frame
	for pirate: Ship in old:
		assert_bool(is_instance_valid(pirate)).is_false()
	_director.advance(2.1)
	assert_int(_director.remaining()).is_equal(2)
	assert_int(_director.wave_index).is_equal(1)
	assert_array(_events).contains_exactly(["start 1 x2", "start 1 x2"])


func test_a_chosen_wave_replaces_the_one_in_play() -> void:
	_director.start(0, 0.0)
	_director.restart_wave(2, 0.0)
	assert_int(_director.wave_index).is_equal(2)
	assert_int(_director.remaining()).is_equal(3)


func test_a_new_player_ship_becomes_the_target_of_the_pirates_already_out() -> void:
	_director.start(1, 0.0)
	var second: Ship = FlightSim.spawn(_world, &"bulwark")
	_director.bind_player(second)
	for pirate: Ship in _director.pirates:
		assert_object((pirate.get_node("AIPilot") as AIPilot).forced_target).is_same(second)


func test_the_wave_waits_for_a_player_to_fight() -> void:
	_director.player = null
	_director.start(0, 0.0)
	assert_int(_director.remaining()).is_equal(0)
	_director.bind_player(_player)
	_director.advance(1.0)
	assert_int(_director.remaining()).is_equal(1)


func test_stopping_sends_the_pirates_away_for_good() -> void:
	_director.start(2, 0.0)
	_director.stop()
	assert_int(_director.remaining()).is_equal(0)
	_director.advance(100.0)
	assert_int(_director.remaining()).is_equal(0)
	assert_int(_director.state).is_equal(EncounterDirector.State.IDLE)


func test_a_pirate_that_leaves_the_scene_is_dropped_from_the_list() -> void:
	_director.start(1, 0.0)
	var gone: Ship = _director.pirates[0]
	_world.remove_child(gone)
	gone.queue_free()
	assert_int(_director.remaining()).is_equal(1)


func test_with_a_stagger_the_pirates_arrive_one_after_another() -> void:
	_def.stagger_seconds = 5.0
	_director.start(2, 0.0)
	assert_int(_director.pirates.size()).is_equal(1)
	assert_int(_director.remaining()).is_equal(3)
	_director.advance(4.9)
	assert_int(_director.pirates.size()).is_equal(1)
	_director.advance(0.2)
	assert_int(_director.pirates.size()).is_equal(2)
	_director.advance(5.1)
	assert_int(_director.pirates.size()).is_equal(3)
	assert_int(_director.remaining()).is_equal(3)
	assert_array(_events).contains_exactly(["start 2 x3"])


func test_a_staggered_wave_is_not_cleared_while_pirates_are_still_to_arrive() -> void:
	_def.stagger_seconds = 5.0
	_director.start(1, 0.0)
	_kill_all()
	assert_int(_director.state).is_equal(EncounterDirector.State.ACTIVE)
	assert_int(_director.remaining()).is_equal(1)
	_director.advance(5.1)
	assert_int(_director.pirates.size()).is_equal(1)
	_kill_all()
	assert_int(_director.state).is_equal(EncounterDirector.State.CLEARED)


func test_restarting_a_staggered_wave_forgets_the_pirates_still_to_arrive() -> void:
	_def.stagger_seconds = 5.0
	_director.start(2, 0.0)
	_director.restart_wave(-1, 10.0)
	assert_int(_director.remaining()).is_equal(0)
