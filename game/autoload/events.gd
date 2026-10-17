extends Node
## Global signal bus. Carries cross-system notifications and holds no state.
##
## Add a signal here when two systems that are not parent and child need to talk. Keep every
## signal typed and document who emits it.

## Emitted by `Game` whenever the top-level flow state changes.
signal game_state_changed(new_state: StringName)
