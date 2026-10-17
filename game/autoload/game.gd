extends Node
## Top-level flow (boot, menu, space, station), pause and scene transitions.
## Stub: only tracks the current flow state for now.

## The top-level flow states.
enum State { BOOT, MENU, SPACE, STATION }

var state: State = State.BOOT


## Switches the flow state and announces it on the `Events` bus.
func set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	Events.game_state_changed.emit(StringName(State.keys()[new_state].to_lower()))
