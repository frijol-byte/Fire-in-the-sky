class_name DamageTable
extends ContentDef
## The damage type x layer multipliers of GDD 7.1, plus the ion status. Pure data: change the
## numbers in `data/combat/damage_table.tres`, never in code. `Durability` is the only reader.

## The three health layers, outermost first.
enum Layer { SHIELD, ARMOR, HULL }

## Status effect name of the ion disable (see `Durability.has_status`).
const STATUS_ION: StringName = &"ion"

## Multipliers per damage type, as (shield, armor, hull).
@export_group("Multipliers (shield, armor, hull)")
@export var energy: Vector3 = Vector3(1.5, 0.75, 1.0)
@export var kinetic: Vector3 = Vector3(0.75, 1.5, 1.0)
@export var explosive: Vector3 = Vector3(1.0, 1.0, 1.25)
@export var ion: Vector3 = Vector3(2.0, 0.25, 0.0)

@export_group("Ion")
## Seconds that devices and missiles stay disabled after an ion hit. A new hit restarts it.
@export var ion_disable_seconds: float = 3.0


func kind() -> StringName:
	return &"damage_table"


## The multiplier for a hit of `type` against `layer` (`Layer`).
func multiplier(type: DamageInfo.Type, layer: Layer) -> float:
	var row: Vector3 = _row(type)
	match layer:
		Layer.SHIELD:
			return row.x
		Layer.ARMOR:
			return row.y
		_:
			return row.z


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	for type: DamageInfo.Type in DamageInfo.Type.values():
		var row: Vector3 = _row(type)
		for axis: int in 3:
			if row[axis] < 0.0:
				result.append("%s multiplier %d must not be negative" % [type, axis])
	if ion_disable_seconds < 0.0:
		result.append("ion_disable_seconds must not be negative")
	return result


func _row(type: DamageInfo.Type) -> Vector3:
	match type:
		DamageInfo.Type.ENERGY:
			return energy
		DamageInfo.Type.KINETIC:
			return kinetic
		DamageInfo.Type.EXPLOSIVE:
			return explosive
		_:
			return ion
