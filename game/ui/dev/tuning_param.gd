class_name TuningParam
extends RefCounted
## One slider of the tuning overlay: a `ShipDef` field (or one component of a `Vector3` field)
## with the range the slider covers. `TuningParam.all()` is the full list, in display order.

## Which part of a `Vector3` field this slider edits; `WHOLE` for a plain float field.
const WHOLE: int = -1

## The `ShipDef` property name.
var field: StringName
## 0, 1, 2 (x, y, z) for a `Vector3` field, or `WHOLE`.
var component: int
## `strings.csv` key of the slider's label.
var label_key: StringName
var min_value: float
var max_value: float
var step: float
## `strings.csv` key of the group heading this slider sits under.
var group_key: StringName


func _init(
	field_name: StringName,
	label: StringName,
	group: StringName,
	min_v: float,
	max_v: float,
	step_v: float,
	part: int = WHOLE
) -> void:
	field = field_name
	label_key = label
	group_key = group
	min_value = min_v
	max_value = max_v
	step = step_v
	component = part


## Reads this parameter's value from `def`.
func read(def: ShipDef) -> float:
	var value: Variant = def.get(field)
	if component == WHOLE:
		return float(value)
	return (value as Vector3)[component]


## Writes `value` into `def`.
func write(def: ShipDef, value: float) -> void:
	if component == WHOLE:
		def.set(field, value)
		return
	var vector: Vector3 = def.get(field)
	vector[component] = value
	def.set(field, vector)


## The `.tres` property name this parameter belongs to (the field, for both kinds).
func property_name() -> String:
	return str(field)


## Every tuning slider: the flight parameters of `ShipDef` plus the camera lag and FOV.
static func all() -> Array[TuningParam]:
	var mass: StringName = &"TUNE_GROUP_MASS"
	var speed: StringName = &"TUNE_GROUP_SPEED"
	var turn: StringName = &"TUNE_GROUP_TURN"
	var assist: StringName = &"TUNE_GROUP_ASSIST"
	var energy: StringName = &"TUNE_GROUP_ENERGY"
	var camera: StringName = &"TUNE_GROUP_CAMERA"
	var list: Array[TuningParam] = [
		TuningParam.new(&"mass", &"TUNE_MASS", mass, 500.0, 60000.0, 100.0),
		TuningParam.new(
			&"thrust_forward", &"TUNE_THRUST_FORWARD", mass, 20000.0, 4000000.0, 5000.0
		),
		TuningParam.new(
			&"thrust_reverse", &"TUNE_THRUST_REVERSE", mass, 20000.0, 4000000.0, 5000.0
		),
		TuningParam.new(
			&"thrust_lateral", &"TUNE_THRUST_LATERAL", mass, 20000.0, 4000000.0, 5000.0
		),
		TuningParam.new(
			&"thrust_vertical", &"TUNE_THRUST_VERTICAL", mass, 20000.0, 4000000.0, 5000.0
		),
		TuningParam.new(&"max_speed", &"TUNE_MAX_SPEED", speed, 30.0, 500.0, 1.0),
		TuningParam.new(&"max_reverse_speed", &"TUNE_MAX_REVERSE_SPEED", speed, 10.0, 300.0, 1.0),
		TuningParam.new(&"max_strafe_speed", &"TUNE_MAX_STRAFE_SPEED", speed, 10.0, 300.0, 1.0),
		TuningParam.new(&"max_vertical_speed", &"TUNE_MAX_VERTICAL_SPEED", speed, 10.0, 300.0, 1.0),
		TuningParam.new(&"max_angular_rate_deg", &"TUNE_PITCH_RATE", turn, 10.0, 360.0, 1.0, 0),
		TuningParam.new(&"max_angular_rate_deg", &"TUNE_YAW_RATE", turn, 10.0, 360.0, 1.0, 1),
		TuningParam.new(&"max_angular_rate_deg", &"TUNE_ROLL_RATE", turn, 10.0, 360.0, 1.0, 2),
		TuningParam.new(&"angular_accel_deg", &"TUNE_PITCH_ACCEL", turn, 20.0, 2000.0, 5.0, 0),
		TuningParam.new(&"angular_accel_deg", &"TUNE_YAW_ACCEL", turn, 20.0, 2000.0, 5.0, 1),
		TuningParam.new(&"angular_accel_deg", &"TUNE_ROLL_ACCEL", turn, 20.0, 2000.0, 5.0, 2),
		TuningParam.new(&"fa_linear_gain", &"TUNE_FA_LINEAR_GAIN", assist, 0.5, 30.0, 0.1),
		TuningParam.new(&"fa_angular_gain", &"TUNE_FA_ANGULAR_GAIN", assist, 0.5, 40.0, 0.1),
		TuningParam.new(&"fa_excess_bleed_time", &"TUNE_FA_BLEED_TIME", assist, 0.1, 5.0, 0.05),
		TuningParam.new(&"energy_capacity", &"TUNE_ENERGY_CAPACITY", energy, 20.0, 400.0, 1.0),
		TuningParam.new(&"energy_regen", &"TUNE_ENERGY_REGEN", energy, 0.0, 80.0, 0.5),
		TuningParam.new(&"energy_regen_delay", &"TUNE_ENERGY_REGEN_DELAY", energy, 0.0, 5.0, 0.05),
		TuningParam.new(&"boost_max_speed", &"TUNE_BOOST_MAX_SPEED", energy, 60.0, 900.0, 1.0),
		TuningParam.new(&"boost_thrust_multiplier", &"TUNE_BOOST_THRUST", energy, 1.0, 8.0, 0.05),
		TuningParam.new(&"boost_energy_per_second", &"TUNE_BOOST_DRAIN", energy, 1.0, 150.0, 0.5),
		TuningParam.new(&"boost_min_energy", &"TUNE_BOOST_MIN_ENERGY", energy, 0.0, 100.0, 0.5),
		TuningParam.new(&"chase_position_lag", &"TUNE_CAMERA_POSITION_LAG", camera, 0.0, 0.6, 0.01),
		TuningParam.new(&"chase_rotation_lag", &"TUNE_CAMERA_ROTATION_LAG", camera, 0.0, 0.8, 0.01),
		TuningParam.new(&"chase_speed_pullback", &"TUNE_CAMERA_PULLBACK", camera, 0.0, 20.0, 0.1),
		TuningParam.new(&"base_fov", &"TUNE_BASE_FOV", camera, 40.0, 110.0, 0.5),
		TuningParam.new(&"boost_fov_kick", &"TUNE_BOOST_FOV_KICK", camera, 0.0, 30.0, 0.5),
	]
	return list
