class_name DamageInfo
extends RefCounted
## One hit, as handed to `Durability.apply`. Weapons, splash and (later) collisions all build one
## of these; nothing else reaches a ship's health (architecture 5.2).

## Damage types of GDD 7.1. The multipliers per layer are data: see `DamageTable`.
enum Type { ENERGY, KINETIC, EXPLOSIVE, ION }

## Raw damage before the layer multipliers.
var amount: float = 0.0
var type: Type = Type.ENERGY
## Who fired: the shooter's ship, or `null` for the environment.
var source: Node = null
## Where the hit landed, in world space (impact VFX and the damage-direction indicator use it).
var hit_point: Vector3 = Vector3.ZERO
## Which subsystem was hit on a capital ship (turret, engine...), or empty for the ship itself.
var subsystem: StringName = &""


static func make(
	damage: float,
	damage_type: Type,
	shooter: Node = null,
	point: Vector3 = Vector3.ZERO,
	part: StringName = &""
) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.amount = damage
	info.type = damage_type
	info.source = shooter
	info.hit_point = point
	info.subsystem = part
	return info
