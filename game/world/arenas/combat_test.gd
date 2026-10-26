class_name CombatTest
extends FlightTest
## The combat test arena (M2-T7): the flight arena's ship, camera, HUD, tools and respawn, in an
## open belt with waves of Cinder Clans pirates instead of a gate course. `EncounterDirector` runs
## waves of 1, then 2, then 3 pirates (`data/encounters/combat_test.tres`), each starting a few
## seconds after the last was cleared and looping round. Dying shows the "Ship destroyed" screen;
## respawning starts the wave you died in again (the respawn loop). F7 opens a debug menu to pick a
## wave, restart it, skip it or send the pirates away. Pirates call out their moves on the comms
## strip (`BarkDirector`). The numbers are in the encounter, arena, feedback and bark defs.

const ENCOUNTER_ID: StringName = &"combat_test"
## Seconds between the player coming back (or a wave being picked) and the pirates appearing.
const RESTART_DELAY: float = 3.0
## How long the wave banners stay up.
const BANNER_SECONDS: float = 3.0

var director: EncounterDirector = null

var _menu: WaveMenu = null


func _ready() -> void:
	super._ready()
	if def == null:
		return
	director = $EncounterDirector as EncounterDirector
	_menu = $WaveMenu as WaveMenu
	director.setup(Content.encounter(ENCOUNTER_ID), self)
	director.bind_player(ship)
	director.wave_started.connect(_on_wave_started)
	director.wave_cleared.connect(_on_wave_cleared)
	director.encounter_complete.connect(_on_encounter_complete)
	var sizes: PackedInt32Array = []
	for index: int in director.def.waves.size():
		sizes.append(director.wave_size(index))
	_menu.setup(sizes, Settings.get_value(HitFeedback.SETTING_SLOWMO, false))
	_menu.wave_chosen.connect(_on_wave_chosen)
	_menu.restart_requested.connect(func() -> void: director.restart_wave(-1, RESTART_DELAY))
	_menu.next_requested.connect(_on_next_requested)
	_menu.clear_requested.connect(director.stop)
	_menu.slowmo_changed.connect(_on_slowmo_changed)
	director.start(0)
	_update_help()


func readout_text() -> String:
	var wave: String = tr("COMBAT_WAVE_IDLE")
	if director.state != EncounterDirector.State.IDLE:
		wave = (
			tr("COMBAT_WAVE")
			% [director.wave_index + 1, director.def.waves.size(), director.remaining()]
		)
		if director.countdown() > 0.0:
			wave += "    " + tr("COMBAT_WAVE_COUNTDOWN") % ceili(director.countdown())
	return (
		"%s\n%s" % [tr("ARENA_SHIP") % [tr(ship.def.display_name_key), _switch_glyphs()], wave]
		+ "    "
		+ wallet_text()
	)


## Starts wave `index` (0-based) over from the start, after `RESTART_DELAY` seconds.
func pick_wave(index: int) -> void:
	director.restart_wave(index, RESTART_DELAY)
	_hud.feedback().show_banner(tr("COMBAT_GET_READY"), RESTART_DELAY)


func _on_player_spawned() -> void:
	# Called while the base class is still building the arena the first time.
	if director == null:
		return
	director.bind_player(ship)
	# The player is back: the wave they were in starts over.
	director.restart_wave(-1, RESTART_DELAY)
	_hud.feedback().show_banner(tr("COMBAT_GET_READY"), RESTART_DELAY)


func _on_wave_started(index: int, count: int) -> void:
	_hud.feedback().show_banner(
		tr("COMBAT_BANNER_WAVE") % [index + 1, director.def.waves.size(), count], BANNER_SECONDS
	)


func _on_wave_cleared(index: int) -> void:
	_hud.feedback().show_banner(tr("COMBAT_BANNER_CLEARED") % (index + 1), BANNER_SECONDS)


func _on_encounter_complete() -> void:
	_hud.feedback().show_banner(tr("COMBAT_BANNER_COMPLETE"), BANNER_SECONDS)


func _on_wave_chosen(index: int) -> void:
	pick_wave(index)


func _on_next_requested() -> void:
	pick_wave(EncounterMath.next_wave(director.wave_index, director.def.waves.size(), true))


func _on_slowmo_changed(enabled: bool) -> void:
	Settings.set_value(HitFeedback.SETTING_SLOWMO, enabled)


func _shows_pirate_help() -> bool:
	return false


func _update_help() -> void:
	super._update_help()
	_help.text += "\n" + tr("COMBAT_HELP") % OS.get_keycode_string(WaveMenu.MENU_KEY)
