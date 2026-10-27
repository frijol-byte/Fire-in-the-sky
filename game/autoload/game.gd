extends Node
## Top-level flow (boot, menu, space, station), pause and scene transitions.
## Stub: only tracks the current flow state for now.

## The top-level flow states.
enum State { BOOT, MENU, SPACE, STATION }

## Scenes the flow switches between.
const BOOT_SCENE: String = "res://core/boot/boot.tscn"
const FLIGHT_TEST_SCENE: String = "res://world/arenas/flight_test.tscn"
const COMBAT_TEST_SCENE: String = "res://world/arenas/combat_test.tscn"

var state: State = State.BOOT


## Switches the flow state and announces it on the `Events` bus.
func set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	Events.game_state_changed.emit(StringName(State.keys()[new_state].to_lower()))


## Leaves the title screen for the flight test arena.
func go_to_flight_test() -> void:
	_change_scene(FLIGHT_TEST_SCENE)


## Leaves the title screen for the combat test arena (waves of pirates).
func go_to_combat_test() -> void:
	_change_scene(COMBAT_TEST_SCENE)


## Goes back to the title screen.
func go_to_boot() -> void:
	set_state(State.BOOT)
	_change_scene(BOOT_SCENE)


func _change_scene(path: String) -> void:
	# Deferred: this is called from input handlers, and a scene cannot free itself mid-event.
	get_tree().call_deferred("change_scene_to_file", path)
