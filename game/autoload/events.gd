extends Node
## Global signal bus. Carries cross-system notifications and holds no state.
##
## Add a signal here when two systems that are not parent and child need to talk. Keep every
## signal typed and document who emits it.

## Emitted by `Game` whenever the top-level flow state changes.
signal game_state_changed(new_state: StringName)

## Emitted by `InputRouter` when the player switches between gamepad and keyboard/mouse.
## `device` is an `InputRouter.Device` value (0 keyboard/mouse, 1 gamepad).
signal input_device_changed(device: int)

## Emitted by `Ship` when boost stops because the capacitor ran dry (not when the pilot lets go).
## Audio and visual effects hook in here.
signal boost_depleted(ship: Node)

## Emitted by `CameraRig` when the player's view changes. `view` is a `CameraRig.View` value
## (0 chase, 1 cockpit).
signal camera_view_changed(view: int)
