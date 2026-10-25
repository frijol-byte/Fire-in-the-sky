class_name DamageResult
extends RefCounted
## What `Durability.apply` did with one `DamageInfo`: the health each layer lost (after the
## type multipliers), for hit markers, impact VFX and sounds.

var shield_damage: float = 0.0
var armor_damage: float = 0.0
var hull_damage: float = 0.0
## True when this hit took the hull to 0.
var destroyed: bool = false
## True when this hit started or refreshed the ion disable.
var ion_disabled: bool = false


## Total health removed from all layers.
func total() -> float:
	return shield_damage + armor_damage + hull_damage


## The deepest layer this hit reached (`DamageTable.Layer`), or -1 when it did no damage.
func deepest_layer() -> int:
	if hull_damage > 0.0:
		return DamageTable.Layer.HULL
	if armor_damage > 0.0:
		return DamageTable.Layer.ARMOR
	if shield_damage > 0.0:
		return DamageTable.Layer.SHIELD
	return -1
