extends Node
## The current save's live data (player profile, wallet, cargo, reputation, missions, world
## state). Fields are added by the tasks that own them: so far the debug wallet (M2-T6).

## Bumped whenever the serialized shape changes; `SaveSystem` migrates between versions.
const SCHEMA_VERSION: int = 1

## Credits the player holds. Stations and prices arrive in M4/M5; for now loot fills it.
var credits: int = 0
## Material id -> units held (placeholder materials from loot, see `LootTableDef`).
var materials: Dictionary[StringName, int] = {}


## Resets all live data to a new game.
func reset() -> void:
	credits = 0
	materials.clear()
	Events.wallet_changed.emit()


## Adds `amount` credits (negative takes them away; the balance never goes below zero).
func add_credits(amount: int) -> void:
	credits = maxi(credits + amount, 0)
	Events.wallet_changed.emit()


## Adds `amount` units of the material `id`.
func add_material(id: StringName, amount: int) -> void:
	materials[id] = maxi(material_count(id) + amount, 0)
	Events.wallet_changed.emit()


## How many units of the material `id` the player holds.
func material_count(id: StringName) -> int:
	return materials.get(id, 0)


## Pays out one loot container.
func collect(drop: LootDrop) -> void:
	if drop.is_credits():
		add_credits(drop.credits)
	else:
		add_material(drop.material_id, drop.amount)


## Returns the live data as a plain, JSON-safe dictionary for `SaveSystem`.
func to_dict() -> Dictionary:
	var held: Dictionary = {}
	for id: StringName in materials:
		held[String(id)] = materials[id]
	return {"schema_version": SCHEMA_VERSION, "credits": credits, "materials": held}
