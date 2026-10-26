class_name LootDrop
extends RefCounted
## What one loot container holds: credits, or an amount of one material. `LootTableDef.roll`
## makes them; `GameState.collect` pays one out.

## Credits in the container (0 for a material container).
var credits: int = 0
## Which material the container holds (`&""` for a credits container).
var material_id: StringName = &""
## How many units of the material.
var amount: int = 0


static func of_credits(value: int) -> LootDrop:
	var drop: LootDrop = LootDrop.new()
	drop.credits = value
	return drop


static func of_material(id: StringName, units: int) -> LootDrop:
	var drop: LootDrop = LootDrop.new()
	drop.material_id = id
	drop.amount = units
	return drop


func is_credits() -> bool:
	return material_id == &""
