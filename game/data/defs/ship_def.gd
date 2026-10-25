class_name ShipDef
extends ContentDef
## Everything the flight model, the energy system and the model loader need to know about a
## ship class. Tunable values are saved here (see the tuning overlay), never in code.
##
## Units: metres, seconds, kilograms, newtons. Angles are in degrees in the file (easier to
## read and tune) and converted by the `*_rad` helpers. Axis order for `Vector3`s that hold
## angular values is (pitch, yaw, roll).

## `strings.csv` key of the ship's name.
@export var display_name_key: String = ""
## The `.glb` built by the Blender recipe (its root has the `ShipModel` script).
@export_file("*.glb") var model_path: String = ""

@export_group("Mass and thrust")
@export var mass: float = 6000.0
## Thrust, in newtons, along each linear axis. Acceleration is thrust / mass.
@export var thrust_forward: float = 360000.0
@export var thrust_reverse: float = 240000.0
@export var thrust_lateral: float = 210000.0
@export var thrust_vertical: float = 210000.0

@export_group("Speed limits (flight assist on)")
## Cruise-combat top speed; the commanded velocity is never longer than this.
@export var max_speed: float = 180.0
@export var max_reverse_speed: float = 90.0
@export var max_strafe_speed: float = 90.0
@export var max_vertical_speed: float = 70.0

@export_group("Rotation")
## Top turn rates in degrees per second: (pitch, yaw, roll).
@export var max_angular_rate_deg: Vector3 = Vector3(90.0, 90.0, 150.0)
## Angular acceleration limits in degrees per second squared: (pitch, yaw, roll).
@export var angular_accel_deg: Vector3 = Vector3(450.0, 450.0, 600.0)

@export_group("Flight assist")
## How hard the flight computer corrects a velocity error, in 1/s. The time constant of the
## approach to the commanded velocity is 1 / gain, when thrust is not the limit.
@export var fa_linear_gain: float = 6.0
## Same for the turn rate error.
@export var fa_angular_gain: float = 12.0
## Design target (M1-F1): with flight assist on, full strafe or full vertical thrust reaches 90% of
## its speed limit within this many seconds, and letting go stops again (down to 10%) within the
## same time, with no overshoot. It is not read by the flight model: the thrust values above make
## it true and `tests/sim/test_flight_lateral.gd` checks it.
@export var strafe_response_time: float = 1.0

@export_group("Energy and boost")
@export var energy_capacity: float = 100.0
## Energy regained per second once the regen delay has passed.
@export var energy_regen: float = 12.0
@export var energy_regen_delay: float = 1.2
## Top speed while boosting.
@export var boost_max_speed: float = 320.0
## Multiplies forward thrust while boosting.
@export var boost_thrust_multiplier: float = 2.0
@export var boost_energy_per_second: float = 30.0
## Energy needed to start a boost, so that a nearly empty capacitor cannot stutter it on and off.
@export var boost_min_energy: float = 10.0

@export_group("Flight assist (excess speed)")
## Seconds flight assist takes to remove (95% of) any speed above the current cap, after boost
## ends or FA comes back on.
@export var fa_excess_bleed_time: float = 1.0

@export_group("Camera")
## Where the chase camera sits, in the ship's axes: +Y up, +Z behind the ship (camera -Z is forward).
@export var chase_offset: Vector3 = Vector3(0.0, 4.0, 15.0)
## The chase camera looks at the point this many metres ahead of the ship.
@export var chase_look_ahead: float = 60.0
## Time constant (seconds) of the camera's position lag when the ship turns. 0 = rigid.
@export var chase_position_lag: float = 0.12
## Same for the camera's rotation lag. 0 = rigid.
@export var chase_rotation_lag: float = 0.18
## The chase camera drops back this many extra metres at top speed.
@export var chase_speed_pullback: float = 3.0
## Field of view in degrees (vertical), cruising.
@export_range(20.0, 120.0) var base_fov: float = 75.0
## Degrees added to the field of view while boosting.
@export var boost_fov_kick: float = 8.0
## Canopy frame shown in the cockpit view (a prop `.glb`).
@export_file("*.glb") var canopy_path: String = ""

@export_group("Look")
## Faction paint, set on the model's `PAINT_PRIMARY` / `PAINT_SECONDARY` parts at spawn
## (the defaults are the paint shader's own).
@export var paint_primary: Color = Color(0.30, 0.38, 0.52)
@export var paint_secondary: Color = Color(0.86, 0.46, 0.12)

@export_group("Slots (placeholder)")
@export var primary_slots: int = 2
@export var secondary_slots: int = 1
@export var device_slots: int = 1


func kind() -> StringName:
	return &"ship"


## Forward acceleration in m/s^2.
func accel_forward() -> float:
	return thrust_forward / mass


## Reverse acceleration in m/s^2.
func accel_reverse() -> float:
	return thrust_reverse / mass


## Sideways acceleration in m/s^2.
func accel_lateral() -> float:
	return thrust_lateral / mass


## Up/down acceleration in m/s^2.
func accel_vertical() -> float:
	return thrust_vertical / mass


## Top turn rates in radians per second: (pitch, yaw, roll).
func max_angular_rate_rad() -> Vector3:
	return Vector3(
		deg_to_rad(max_angular_rate_deg.x),
		deg_to_rad(max_angular_rate_deg.y),
		deg_to_rad(max_angular_rate_deg.z)
	)


## Angular acceleration limits in radians per second squared: (pitch, yaw, roll).
func angular_accel_rad() -> Vector3:
	return Vector3(
		deg_to_rad(angular_accel_deg.x),
		deg_to_rad(angular_accel_deg.y),
		deg_to_rad(angular_accel_deg.z)
	)


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	var positive: Dictionary[String, float] = {
		"mass": mass,
		"thrust_forward": thrust_forward,
		"thrust_reverse": thrust_reverse,
		"thrust_lateral": thrust_lateral,
		"thrust_vertical": thrust_vertical,
		"max_speed": max_speed,
		"max_reverse_speed": max_reverse_speed,
		"max_strafe_speed": max_strafe_speed,
		"max_vertical_speed": max_vertical_speed,
		"fa_linear_gain": fa_linear_gain,
		"fa_angular_gain": fa_angular_gain,
		"strafe_response_time": strafe_response_time,
		"energy_capacity": energy_capacity,
		"boost_max_speed": boost_max_speed,
		"boost_thrust_multiplier": boost_thrust_multiplier,
		"boost_energy_per_second": boost_energy_per_second,
		"fa_excess_bleed_time": fa_excess_bleed_time,
	}
	for field: String in positive:
		if positive[field] <= 0.0:
			result.append("%s must be above 0" % field)
	for axis: int in 3:
		if max_angular_rate_deg[axis] <= 0.0:
			result.append("max_angular_rate_deg[%d] must be above 0" % axis)
		if angular_accel_deg[axis] <= 0.0:
			result.append("angular_accel_deg[%d] must be above 0" % axis)
	if chase_offset.z <= 0.0:
		result.append("chase_offset.z must be above 0 (the camera sits behind the ship)")
	if chase_position_lag < 0.0 or chase_rotation_lag < 0.0:
		result.append("camera lag must not be negative")
	if base_fov < 20.0 or base_fov > 120.0 or boost_fov_kick < 0.0:
		result.append("base_fov must be 20..120 and boost_fov_kick at least 0")
	if not canopy_path.is_empty() and not ResourceLoader.exists(canopy_path):
		result.append("canopy_path does not exist: %s" % canopy_path)
	if boost_max_speed < max_speed:
		result.append("boost_max_speed must not be below max_speed")
	if energy_regen < 0.0 or energy_regen_delay < 0.0:
		result.append("energy_regen and energy_regen_delay must not be negative")
	if boost_min_energy < 0.0 or boost_min_energy > energy_capacity:
		result.append("boost_min_energy must be between 0 and energy_capacity")
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		result.append("model_path does not exist: %s" % model_path)
	return result
