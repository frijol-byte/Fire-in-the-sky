class_name LootTableDef
extends ContentDef
## What a destroyed ship or dummy leaves behind (M2-T6): a few loot containers, each holding
## credits or a placeholder material. `roll` is the one place that turns this table into drops;
## it takes the random generator so sims can repeat a fight exactly. Real materials and prices
## come with the economy (M5).

@export_group("Containers")
## How many containers are dropped (inclusive range).
@export var containers_min: int = 1
@export var containers_max: int = 3
## Credits in a credits container (inclusive range).
@export var credits_min: int = 10
@export var credits_max: int = 40
## Chance (0..1) that a container holds a material instead of credits.
@export_range(0.0, 1.0) var material_chance: float = 0.3
## The materials a container can hold, and how many units (inclusive range).
@export var material_ids: Array[StringName] = []
@export var material_amount_min: int = 1
@export var material_amount_max: int = 3

@export_group("Containers in space")
## How long a container waits to be picked up before it is gone, in seconds.
@export var lifetime_seconds: float = 60.0
## Containers leave the wreck at a random speed up to this, in m/s, and slow down with drag.
@export var scatter_speed: float = 14.0
## How quickly the scatter dies away (the speed is multiplied by `exp(-drag * t)`).
@export var scatter_drag: float = 1.4


func kind() -> StringName:
	return &"loot_table"


## The containers this table drops on one kill. Uses `rng` for every roll, so the same seed gives
## the same loot.
func roll(rng: RandomNumberGenerator) -> Array[LootDrop]:
	var drops: Array[LootDrop] = []
	var count: int = rng.randi_range(containers_min, containers_max)
	for index: int in count:
		if not material_ids.is_empty() and rng.randf() < material_chance:
			var material_id: StringName = material_ids[rng.randi_range(0, material_ids.size() - 1)]
			drops.append(
				LootDrop.of_material(
					material_id, rng.randi_range(material_amount_min, material_amount_max)
				)
			)
		else:
			drops.append(LootDrop.of_credits(rng.randi_range(credits_min, credits_max)))
	return drops


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if containers_min < 0 or containers_max < containers_min:
		result.append("containers_min must be 0 or more and not above containers_max")
	if credits_min < 0 or credits_max < credits_min:
		result.append("credits_min must be 0 or more and not above credits_max")
	if material_chance < 0.0 or material_chance > 1.0:
		result.append("material_chance must be between 0 and 1")
	if material_chance > 0.0 and material_ids.is_empty():
		result.append("material_chance is above 0 but material_ids is empty")
	if material_amount_min < 1 or material_amount_max < material_amount_min:
		result.append("material_amount_min must be 1 or more and not above material_amount_max")
	for material_id: StringName in material_ids:
		if material_id == &"":
			result.append("material_ids has an empty id")
	if lifetime_seconds <= 0.0:
		result.append("lifetime_seconds must be above 0")
	if scatter_speed < 0.0 or scatter_drag < 0.0:
		result.append("scatter_speed and scatter_drag must not be negative")
	return result
