class_name AIUtility
extends RefCounted
## The AI's utility selector (architecture 5.3): every behavior gets a score from what the pilot
## knows, and the best one flies the ship. The scores are pure functions of a `Situation`, so the
## choices are unit tested without any ships.
##
## A behavior that was just chosen keeps the controls for its minimum time unless something else
## is much more urgent, so the ship does not flutter between two behaviors every tick.

enum Behavior { PURSUE, ATTACK_RUN, BREAK_OFF, EVADE, USE_DEVICE }

## Scores are 0 (not at all) to about 1.3 (drop everything).
const URGENT_MARGIN: float = 0.2
## Pursue's score with no target: the pilot idles in it.
const PURSUE_FLOOR: float = 0.1
## How much a nearly dead target adds to the attack run's score (and, twice over, takes off the
## evade-when-shot score).
const KILL_PULL: float = 0.3
## Closing slower than this (m/s) is not closing: two ships flying side by side are not about to hit.
const MIN_CLOSING: float = 15.0
## Scores closer than this are a tie.
const EPSILON: float = 0.0001


## What the pilot knows about the fight right now.
class Situation:
	extends RefCounted
	var has_target: bool = false
	## Metres to the target, and the angle in radians between the nose and the target.
	var distance: float = 0.0
	var angle: float = 0.0
	## Metres per second the gap closes by (negative: opening).
	var closing: float = 0.0
	## The two ships will touch if both hold their course.
	var collision_course: bool = false
	## Own shield, 0..1.
	var shield_fraction: float = 1.0
	## The target's hull, 0..1. A target that is nearly dead pulls the pilot in for the kill.
	var target_hull_fraction: float = 1.0
	## Hit within the last second (after the reaction time).
	var under_fire: bool = false
	## An enemy has a missile lock building or complete on this ship.
	var locked_on: bool = false
	## The enemy's nose is on this ship and it is close enough to shoot.
	var in_sights: bool = false
	## A homing missile is steering at this ship (after the reaction time).
	var incoming_missile: bool = false
	## A flares device is fitted and ready.
	var flares_ready: bool = false
	## Distances that matter for this ship and profile.
	var engage_range: float = 700.0
	var break_range: float = 140.0
	var aggression: float = 0.5


## The score of `behavior` in `situation`.
static func score(behavior: Behavior, situation: Situation) -> float:
	match behavior:
		Behavior.PURSUE:
			return _pursue(situation)
		Behavior.ATTACK_RUN:
			return _attack_run(situation)
		Behavior.BREAK_OFF:
			return _break_off(situation)
		Behavior.EVADE:
			return _evade(situation)
		Behavior.USE_DEVICE:
			return _use_device(situation)
	return 0.0


## Every behavior's score, by behavior.
static func scores(situation: Situation) -> Dictionary[int, float]:
	var result: Dictionary[int, float] = {}
	for behavior: int in Behavior.values():
		result[behavior] = score(behavior as Behavior, situation)
	return result


## The behavior to fly. `current` keeps the job while it has had it for less than `min_time`
## (`elapsed` is how long it has had it), unless another score beats it by `URGENT_MARGIN`.
## Past that, the best score wins; ties go to the current behavior, then the lower enum value.
static func select(
	all_scores: Dictionary[int, float], current: Behavior, elapsed: float, min_time: float
) -> Behavior:
	var current_score: float = all_scores.get(current, 0.0)
	var best: int = current
	var best_score: float = current_score
	for behavior: int in Behavior.values():
		var value: float = all_scores.get(behavior, 0.0)
		if value > best_score + EPSILON:
			best = behavior
			best_score = value
	var margin: float = URGENT_MARGIN if elapsed < min_time else 0.0
	return (best if best_score > current_score + margin else current) as Behavior


## Closing in on a target that is far away or behind the ship. The fallback when nothing else
## scores; with no target the pilot just sits at the floor.
static func _pursue(s: Situation) -> float:
	if not s.has_target:
		return PURSUE_FLOOR
	var far: float = clampf((s.distance - s.engage_range) / s.engage_range, 0.0, 1.0)
	var behind: float = 0.0
	if s.angle > AIMath.BEHIND_ANGLE and s.distance > s.break_range * 1.2:
		behind = 0.3
	return 0.3 + 0.5 * far + behind


## Flying at a target that is ahead and inside the engage range, firing as the lead lines up.
static func _attack_run(s: Situation) -> float:
	if not s.has_target:
		return 0.0
	if s.distance > s.engage_range:
		return 0.0
	if s.angle > AIMath.BEHIND_ANGLE:
		return 0.0
	return 0.4 + 0.3 * s.aggression + KILL_PULL * _kill_instinct(s)


## Too close to the target (it would be a collision), or hurt and not reckless enough to carry on.
static func _break_off(s: Situation) -> float:
	if not s.has_target:
		return 0.0
	var result: float = 0.0
	# A collision course is a break-off; passing wide, or holding station in a tail chase, is not.
	var too_close: bool = s.distance <= s.break_range * 0.4 and s.closing > MIN_CLOSING
	if s.distance <= s.break_range and (s.collision_course or too_close):
		result = 0.9 + 0.1 * clampf(s.closing / 200.0, 0.0, 1.0)
	if s.shield_fraction < 0.3 and s.distance < s.engage_range:
		result = maxf(result, (1.0 - s.aggression) * 0.9)
	return result


## Being locked, shot at or aimed at: jink and flip instead of flying straight.
static func _evade(s: Situation) -> float:
	var result: float = 0.0
	if s.incoming_missile:
		result = 1.0
	if s.locked_on:
		result = maxf(result, 0.95)
	if s.under_fire:
		result = maxf(result, 0.9 - 0.4 * s.aggression - 2.0 * KILL_PULL * _kill_instinct(s))
	if s.in_sights and s.has_target and s.angle > AIMath.BEHIND_ANGLE:
		result = maxf(result, 0.95 - 0.5 * s.aggression)
	return result


## A missile is on its way and the flares are ready: throw them now.
static func _use_device(s: Situation) -> float:
	return 1.25 if s.incoming_missile and s.flares_ready else 0.0


## 0 (target undamaged) to 1 (target about to die): how much the pilot wants to finish it.
static func _kill_instinct(s: Situation) -> float:
	return clampf(1.0 - s.target_hull_fraction, 0.0, 1.0)
