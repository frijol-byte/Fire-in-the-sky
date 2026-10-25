class_name AimAssist
extends RefCounted
## The pure rules of the gamepad aim assist (GDD 7.3): how strong it is, and how much the right
## stick slows down ("reticle friction") when the nose is near the locked target. The other half,
## magnetism (bending the shots up to a few degrees towards the lead point), is the weapon gimbal:
## `Targeting` scales `WeaponSystem.gimbal_scale` by the strength computed here.
##
## Strength is 0..1. It is the difficulty's scale (`DifficultyDef.aim_assist_scale`) times the
## player's accessibility slider, and it is zero for the mouse unless the player turned mouse
## assist on.

## Settings keys (see `Settings`) and their defaults.
const SETTING_STRENGTH: String = "accessibility/aim_assist"
const SETTING_MOUSE: String = "controls/aim_assist_mouse"
const SETTING_DIFFICULTY: String = "game/difficulty"
const DEFAULT_STRENGTH: float = 1.0
const DEFAULT_MOUSE: bool = false
const DEFAULT_DIFFICULTY: StringName = &"normal"


## The assist strength for the current input device. `difficulty_scale` is the difficulty's
## setting, `slider` the player's own 0..1 setting; `gamepad` says whether the player last used a
## gamepad, `mouse_assist` whether they asked for assist with the mouse as well.
static func strength(
	difficulty_scale: float, slider: float, gamepad: bool, mouse_assist: bool
) -> float:
	if not gamepad and not mouse_assist:
		return 0.0
	return clampf(difficulty_scale, 0.0, 1.0) * clampf(slider, 0.0, 1.0)


## The strength from `Settings` and the difficulty in force, for a player on `gamepad` or not.
static func current_strength(gamepad: bool) -> float:
	var difficulty: DifficultyDef = Content.difficulty(
		StringName(Settings.get_value(SETTING_DIFFICULTY, DEFAULT_DIFFICULTY))
	)
	var scale: float = difficulty.aim_assist_scale if difficulty != null else 1.0
	return strength(
		scale,
		float(Settings.get_value(SETTING_STRENGTH, DEFAULT_STRENGTH)),
		gamepad,
		bool(Settings.get_value(SETTING_MOUSE, DEFAULT_MOUSE))
	)


## The factor (0..1) the aim stick is multiplied by when the nose is `angle` radians off the
## target. Outside `zone` radians, or with no strength, it is 1 (no friction). On the target it
## falls to `1 - (1 - min_factor) * strength`, easing in so there is no sudden edge.
static func friction_factor(
	angle: float, zone: float, min_factor: float, strength_now: float
) -> float:
	if strength_now <= 0.0 or zone <= 0.0 or angle >= zone:
		return 1.0
	var closeness: float = 1.0 - clampf(angle / zone, 0.0, 1.0)
	var eased: float = closeness * closeness * (3.0 - 2.0 * closeness)
	return 1.0 - (1.0 - clampf(min_factor, 0.0, 1.0)) * clampf(strength_now, 0.0, 1.0) * eased


## The friction zone around a target: `base` radians, plus the angle the target itself covers
## (`radius` metres at `distance`), so a big or close target is easy to stay on.
static func friction_zone(base: float, radius: float, distance: float) -> float:
	if distance <= 0.0:
		return base
	return base + atan2(maxf(radius, 0.0), distance)


## The gimbal limit in degrees for a weapon whose own limit is `gimbal_deg`, at assist `strength_now`.
static func gimbal_limit_deg(gimbal_deg: float, strength_now: float) -> float:
	return gimbal_deg * clampf(strength_now, 0.0, 1.0)
