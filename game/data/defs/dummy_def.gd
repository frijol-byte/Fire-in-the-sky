class_name DummyDef
extends ContentDef
## A target dummy: a round practice target with the same shield, armor and hull layers as a ship.
## Arenas place them (static, or sliding along a rail) from `ArenaDef`; the stats are here.

## `strings.csv` key of the dummy's name.
@export var display_name_key: String = ""
## Whose side the dummy is on. Hostile dummies are what "target nearest hostile" picks; the others
## let targeting and the HUD brackets be tried on neutral and friendly shapes too.
@export var stance: Targeting.Stance = Targeting.Stance.HOSTILE

@export_group("Durability")
@export var shield_capacity: float = 120.0
@export var armor_capacity: float = 100.0
@export var hull_capacity: float = 120.0
@export var shield_regen: float = 10.0
@export var shield_regen_delay: float = 4.0

@export_group("Destruction")
## `LootTableDef` id of the containers a destroyed dummy drops, or empty for none.
@export var loot_table_id: StringName = &""

@export_group("Body")
## Radius of the sphere that is both shown and hit, in metres.
@export var radius: float = 6.0
## Speed along its rail, in m/s (ignored by a dummy without a rail).
@export var rail_speed: float = 18.0
## A destroyed dummy comes back, fully repaired, after this many seconds.
@export var respawn_seconds: float = 4.0
@export var color: Color = Color(0.85, 0.45, 0.2)


func kind() -> StringName:
	return &"dummy"


## The three layers as (shield, armor, hull).
func capacities() -> Vector3:
	return Vector3(shield_capacity, armor_capacity, hull_capacity)


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if display_name_key.is_empty():
		result.append("display_name_key is empty")
	if shield_capacity < 0.0 or armor_capacity < 0.0:
		result.append("shield_capacity and armor_capacity must not be negative")
	if hull_capacity <= 0.0:
		result.append("hull_capacity must be above 0")
	if shield_regen < 0.0 or shield_regen_delay < 0.0:
		result.append("shield_regen and shield_regen_delay must not be negative")
	if radius <= 0.0:
		result.append("radius must be above 0")
	if rail_speed < 0.0 or respawn_seconds < 0.0:
		result.append("rail_speed and respawn_seconds must not be negative")
	return result
