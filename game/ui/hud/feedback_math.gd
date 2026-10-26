class_name FeedbackMath
extends RefCounted
## The combat feedback's pure rules (GDD 7.4): which hit marker a hit earns, how hard it shakes the
## camera, where on the screen a damage indicator sits, when the low-shield alarm is on and how a
## marker fades. `FeedbackHud` draws and `HitFeedback` plays; this decides. Unit tested.

## What a hit on an enemy looks like, from the layer it reached. `KILL` is the hit that destroyed it.
enum Marker { SHIELD, ARMOR, HULL, KILL }


## The marker a hit on an enemy earns: the deepest layer it reached, or a kill.
static func marker_for(result: DamageResult) -> Marker:
	if result.destroyed:
		return Marker.KILL
	match result.deepest_layer():
		DamageTable.Layer.HULL:
			return Marker.HULL
		DamageTable.Layer.ARMOR:
			return Marker.ARMOR
	return Marker.SHIELD


## Camera shake (0..1) for the player taking a hit: health lost per layer, hull counting most,
## never above `shake_hit_max`.
static func hit_shake(result: DamageResult, def: FeedbackDef) -> float:
	var strength: float = (
		result.shield_damage * def.shake_per_shield_point
		+ result.armor_damage * def.shake_per_armor_point
		+ result.hull_damage * def.shake_per_hull_point
	)
	return minf(strength, def.shake_hit_max)


## Camera shake (0..1) from an explosion `distance` metres from the camera: full strength up close,
## fading in a straight line to nothing at `shake_explosion_range_m`.
static func explosion_shake(distance: float, def: FeedbackDef) -> float:
	if distance >= def.shake_explosion_range_m:
		return 0.0
	return def.shake_explosion_max * (1.0 - maxf(distance, 0.0) / def.shake_explosion_range_m)


## Where a damage indicator sits on a ring around the screen centre: the angle in radians, 0 at the
## top, growing clockwise (PI / 2 is the right edge, PI the bottom). `local` is the direction to the
## attacker in camera space (x right, y up, -z ahead). Straight ahead or straight behind has no
## sideways part: ahead reads as the top, behind as the bottom.
static func direction_angle(local: Vector3) -> float:
	if Vector2(local.x, local.y).length_squared() < 0.000001:
		return PI if local.z > 0.0 else 0.0
	return atan2(local.x, local.y)


## The world direction from `ship_position` towards whoever hurt it: the shooter if there is one,
## else the point the hit landed. Zero when neither says anything.
static func attacker_direction(ship_position: Vector3, info: DamageInfo) -> Vector3:
	var target: Vector3 = info.hit_point
	if info.source is Node3D and is_instance_valid(info.source):
		target = (info.source as Node3D).global_position
	var line: Vector3 = target - ship_position
	return line.normalized() if line.length_squared() > 0.000001 else Vector3.ZERO


## True while the low-shield alarm should sound. Hysteresis: it starts at `low_shield_fraction` and
## only stops once the shield has recovered to `low_shield_clear_fraction`. A ship with no shield
## has nothing to alarm about, and a destroyed one is past it.
static func alarm_on(
	was_on: bool, shield_fraction: float, capacity: float, def: FeedbackDef
) -> bool:
	if capacity <= 0.0:
		return false
	if was_on:
		return shield_fraction < def.low_shield_clear_fraction
	return shield_fraction <= def.low_shield_fraction


## 1 at the start of a marker, falling to 0 after `duration` seconds (and 0 beyond).
static func fade(age: float, duration: float) -> float:
	if duration <= 0.0 or age >= duration:
		return 0.0
	return 1.0 - maxf(age, 0.0) / duration


## The `strings.csv` key of a layer's bar label.
static func layer_key(layer: DamageTable.Layer) -> String:
	match layer:
		DamageTable.Layer.SHIELD:
			return "HUD_SHIELD"
		DamageTable.Layer.ARMOR:
			return "HUD_ARMOR"
	return "HUD_HULL"
