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

## Emitted by `Durability` when a hit took health from a ship. `ship` is the ship that was hit,
## `info` the hit and `result` how much each layer lost. Hit markers, damage indicators, impact
## VFX and audio hook in here.
signal ship_damaged(ship: Node, info: DamageInfo, result: DamageResult)

## Emitted by `Durability` once, when a hit empties a ship's hull. `info` is the killing hit.
signal ship_destroyed(ship: Node, info: DamageInfo)

## Emitted by `LootManager` when the player's tractor beam collects a container. The wallet has
## already been paid (`GameState`).
signal loot_collected(ship: Node, drop: LootDrop)

## Emitted by `GameState` whenever the wallet changes (credits or materials).
signal wallet_changed

## Emitted by `AIPilot` when it changes behavior. `behavior` is an `AIUtility.Behavior` value. Radio
## barks hook in here.
signal ai_behavior_changed(ship: Node, behavior: int)
