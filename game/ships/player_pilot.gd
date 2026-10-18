class_name PlayerPilot
extends Node
## Feeds the player's controls to the `Ship` it is a child of. The AI's pilot does the same
## with its own `ShipControls`, so both fly through the same path.


func _physics_process(_delta: float) -> void:
	var ship: Ship = get_parent() as Ship
	if ship != null:
		ship.controls = InputRouter.controls
