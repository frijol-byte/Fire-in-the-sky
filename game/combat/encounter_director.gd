class_name EncounterDirector
extends Node
## Runs an `EncounterDef`: waves of AI pirates, one after another, spawned around the player
## (M2-T7). A wave starts after a short delay, is over when every pirate in it is destroyed, and the
## next one follows after the intermission (the last is followed by the first again when the def
## loops). `restart_wave` is the respawn loop: when the player comes back, the wave they died in
## starts over.
##
## Pirates are ordinary `Ship`s flown by an `AIPilot`, the same as the F5 pirates of the flight
## arena. The director only decides who appears where and when. `EncounterMath` has the rules.

## A wave has just appeared. `index` is 0-based.
signal wave_started(index: int, count: int)
## The last pirate of wave `index` was destroyed.
signal wave_cleared(index: int)
## The last wave was cleared and the def does not loop.
signal encounter_complete
signal pirate_spawned(pirate: Ship)

enum State { IDLE, WAITING, ACTIVE, CLEARED }

const SHIP_SCENE: PackedScene = preload("res://ships/ship.tscn")
## Added to the wave number in the pilots' dice seeds, so waves differ.
const SEED_PER_WAVE: int = 10

var def: EncounterDef = null
var state: State = State.IDLE
## The wave in play (or about to start), 0-based; -1 before the first.
var wave_index: int = -1
## The pirates of the current wave that are still alive.
var pirates: Array[Ship] = []
var player: Ship = null

var _world: Node = null
var _countdown: float = 0.0
var _next_wave: int = -1
var _spawned_total: int = 0
## Slots of the current wave that have not appeared yet, and the time until the next one does.
var _queued_slots: Array[int] = []
var _stagger_left: float = 0.0
var _barks: BarkDef = null


func _ready() -> void:
	Events.ship_destroyed.connect(_on_ship_destroyed)


func _exit_tree() -> void:
	if Events.ship_destroyed.is_connected(_on_ship_destroyed):
		Events.ship_destroyed.disconnect(_on_ship_destroyed)


func _process(delta: float) -> void:
	advance(delta)


## Sets what to run and where the pirates are added (`world`). Does not start anything.
func setup(encounter: EncounterDef, world: Node) -> void:
	def = encounter
	_world = world
	_barks = Content.barks()


## Makes `ship` the player the pirates hunt, now and for the pirates already out.
func bind_player(ship: Ship) -> void:
	player = ship
	for pirate: Ship in pirates:
		_pilot_of(pirate).forced_target = ship


## Moves the countdowns on by `delta` seconds. `_process` calls it; tests call it directly.
func advance(delta: float) -> void:
	if state == State.ACTIVE and not _queued_slots.is_empty():
		_stagger_left -= delta
		if _stagger_left <= 0.0:
			_spawn_next_slot()
		return
	if state != State.WAITING and state != State.CLEARED:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_begin_wave(_next_wave)


## Starts the encounter at wave `first` (0-based) after `delay` seconds (the def's first-wave delay
## when negative). Whatever was in play goes away.
func start(first: int = 0, delay: float = -1.0) -> void:
	clear_pirates()
	_queue_wave(first, def.first_wave_delay if delay < 0.0 else delay)


## Starts wave `index` over again after `delay` seconds: the current pirates go away. Used when the
## player respawns and when a wave is picked from the debug menu.
func restart_wave(index: int = -1, delay: float = 1.5) -> void:
	clear_pirates()
	_queue_wave(wave_index if index < 0 else index, delay)


## Sends every pirate away and stops the countdown.
func stop() -> void:
	clear_pirates()
	state = State.IDLE
	_countdown = 0.0


## Removes every pirate of the current wave, without anyone being credited with a kill.
func clear_pirates() -> void:
	for pirate: Ship in pirates:
		if is_instance_valid(pirate):
			if pirate.tree_exiting.is_connected(_on_pirate_leaving):
				pirate.tree_exiting.disconnect(_on_pirate_leaving)
			if pirate.is_inside_tree():
				pirate.get_parent().remove_child(pirate)
			pirate.queue_free()
	pirates.clear()
	_queued_slots.clear()


## Pirates still to beat in the current wave: those in play and those still to arrive.
func remaining() -> int:
	return pirates.size() + _queued_slots.size()


## Seconds until the next wave appears while waiting, else 0.
func countdown() -> float:
	return maxf(_countdown, 0.0) if state == State.WAITING or state == State.CLEARED else 0.0


## How many pirates wave `index` has, 0 for a wave that does not exist.
func wave_size(index: int) -> int:
	if def == null or index < 0 or index >= def.waves.size():
		return 0
	return def.waves[index].count()


func _queue_wave(index: int, delay: float) -> void:
	_next_wave = clampi(index, 0, def.waves.size() - 1)
	wave_index = _next_wave
	_countdown = delay
	state = State.WAITING
	if delay <= 0.0:
		_begin_wave(_next_wave)


func _begin_wave(index: int) -> void:
	if player == null or not is_instance_valid(player):
		# Nobody to fight: wait for the player.
		_countdown = 0.5
		return
	wave_index = index
	var wave: WaveDef = def.waves[index]
	state = State.ACTIVE
	_queued_slots.clear()
	for slot: int in range(1, wave.count()):
		_queued_slots.append(slot)
	_stagger_left = def.stagger_seconds
	wave_started.emit(index, wave.count())
	_spawn_slot(0)
	# With no stagger everybody arrives together.
	while def.stagger_seconds <= 0.0 and not _queued_slots.is_empty():
		_spawn_next_slot()


func _spawn_next_slot() -> void:
	_spawn_slot(_queued_slots.pop_front() as int)
	_stagger_left = def.stagger_seconds


func _spawn_slot(slot: int) -> void:
	var pirate: Ship = _spawn(def.waves[wave_index], wave_index, slot)
	pirates.append(pirate)
	pirate_spawned.emit(pirate)


func _spawn(wave: WaveDef, index: int, slot: int) -> Ship:
	var pirate: Ship = SHIP_SCENE.instantiate() as Ship
	pirate.def = Content.ship(wave.ship_ids[slot])
	pirate.name = "Pirate%d" % (_spawned_total + 1)
	pirate.stance = Targeting.Stance.HOSTILE
	pirate.set_meta(&"callsign", _callsign())
	_spawned_total += 1
	_world.add_child(pirate)
	pirate.global_transform = EncounterMath.spawn_transform(
		player.global_transform, slot, wave.count(), def.spawn_distance_m, def.spawn_spread_deg
	)
	var pilot: AIPilot = AIPilot.new()
	pilot.name = "AIPilot"
	pilot.profile = Content.ai_profile(wave.profile_ids[slot])
	pilot.forced_target = player
	pirate.add_child(pilot)
	pilot.seed_rolls(def.seed_base + index * SEED_PER_WAVE + slot)
	pirate.tree_exiting.connect(_on_pirate_leaving.bind(pirate))
	return pirate


func _callsign() -> String:
	if _barks == null or _barks.callsign_keys.is_empty():
		return ""
	return tr(String(_barks.callsign_keys[_spawned_total % _barks.callsign_keys.size()]))


func _pilot_of(pirate: Ship) -> AIPilot:
	return pirate.get_node("AIPilot") as AIPilot


func _on_pirate_leaving(pirate: Ship) -> void:
	pirates.erase(pirate)


func _on_ship_destroyed(node: Node, _info: DamageInfo) -> void:
	if not (node is Ship) or not pirates.has(node as Ship):
		return
	var pirate: Ship = node as Ship
	pirate.tree_exiting.disconnect(_on_pirate_leaving)
	pirates.erase(pirate)
	if state != State.ACTIVE or remaining() > 0:
		return
	wave_cleared.emit(wave_index)
	var following: int = EncounterMath.next_wave(wave_index, def.waves.size(), def.loop)
	if following < 0:
		state = State.IDLE
		encounter_complete.emit()
		return
	_next_wave = following
	_countdown = def.intermission_seconds
	state = State.CLEARED
