class_name FeedbackDef
extends ContentDef
## The numbers behind the combat feedback (GDD 7.4, M2-T7): how long hit markers and damage
## indicators last, when the low-shield alarm sounds, how hard the camera shakes on hits and
## explosions, and the kill confirmation's slow-motion tick. The rules that use them are in
## `FeedbackMath`; `FeedbackHud` and `HitFeedback` play them.

@export_group("Hit markers and indicators")
## Seconds a hit marker stays on screen (it fades out), for an ordinary hit and for a kill.
@export var hit_marker_seconds: float = 0.35
@export var kill_marker_seconds: float = 0.9
## Seconds a damage-direction indicator stays on screen.
@export var indicator_seconds: float = 1.2
## The most indicators shown at once (the oldest is replaced).
@export var max_indicators: int = 6
## Seconds the kill banner ("<name> destroyed") stays on screen.
@export var kill_banner_seconds: float = 1.6

@export_group("Low shield alarm")
## The alarm starts when the shield falls to this fraction of its capacity and stops once it has
## recovered to `low_shield_clear_fraction` (higher, so the alarm does not flutter).
@export_range(0.0, 1.0) var low_shield_fraction: float = 0.25
@export_range(0.0, 1.0) var low_shield_clear_fraction: float = 0.4
## Seconds between alarm beeps.
@export var alarm_interval: float = 1.1

@export_group("Camera shake")
## Shake strength (0..1 of the camera's maximum) a hit gives per point of health lost, per layer.
## Shield hits barely shake, hull hits do.
@export var shake_per_shield_point: float = 0.002
@export var shake_per_armor_point: float = 0.006
@export var shake_per_hull_point: float = 0.012
## A single hit never shakes harder than this, and the shake lasts this long.
@export var shake_hit_max: float = 0.45
@export var shake_hit_seconds: float = 0.25
## The shake when the player's ship is destroyed.
@export var shake_death: float = 1.0
@export var shake_death_seconds: float = 1.4
## An explosion shakes the camera up to this hard when it is right next to it, fading to nothing
## at `shake_explosion_range_m`.
@export var shake_explosion_max: float = 0.55
@export var shake_explosion_range_m: float = 450.0
@export var shake_explosion_seconds: float = 0.7

@export_group("Kill slow-motion")
## Game speed during the tick that follows the last enemy's destruction (when the setting is on),
## and how long it lasts in real seconds.
@export_range(0.05, 1.0) var slowmo_scale: float = 0.3
@export var slowmo_seconds: float = 0.45


func kind() -> StringName:
	return &"feedback"


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	for value: float in [hit_marker_seconds, kill_marker_seconds, indicator_seconds]:
		if value <= 0.0:
			result.append("marker and indicator seconds must be above 0")
			break
	if kill_banner_seconds <= 0.0:
		result.append("kill_banner_seconds must be above 0")
	if max_indicators < 1:
		result.append("max_indicators must be at least 1")
	if low_shield_clear_fraction <= low_shield_fraction:
		result.append("low_shield_clear_fraction must be above low_shield_fraction")
	if alarm_interval <= 0.0:
		result.append("alarm_interval must be above 0")
	for value: float in [
		shake_per_shield_point,
		shake_per_armor_point,
		shake_per_hull_point,
		shake_hit_max,
		shake_death,
		shake_explosion_max
	]:
		if value < 0.0 or value > 1.0:
			result.append("shake strengths must be between 0 and 1")
			break
	if shake_hit_seconds <= 0.0 or shake_death_seconds <= 0.0 or shake_explosion_seconds <= 0.0:
		result.append("shake durations must be above 0")
	if shake_explosion_range_m <= 0.0:
		result.append("shake_explosion_range_m must be above 0")
	if slowmo_seconds <= 0.0:
		result.append("slowmo_seconds must be above 0")
	return result
