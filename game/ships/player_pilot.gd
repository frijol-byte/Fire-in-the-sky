class_name PlayerPilot
extends Node
## Feeds the player's controls to the `Ship` it is a child of. The AI's pilot does the same
## with its own `ShipControls`, so both fly through the same path.
##
## It also marks the ship's `Targeting` as the player's, which switches on the gamepad aim assist.


func _ready() -> void:
	_set_player_targeting(true)


func _exit_tree() -> void:
	_set_player_targeting(false)
	InputRouter.aim_friction = 1.0


func _physics_process(_delta: float) -> void:
	var ship: Ship = get_parent() as Ship
	if ship != null:
		ship.controls = InputRouter.controls


func _set_player_targeting(is_player: bool) -> void:
	var targeting: Targeting = get_parent().get_node_or_null("Targeting") as Targeting
	if targeting != null:
		targeting.is_player = is_player
