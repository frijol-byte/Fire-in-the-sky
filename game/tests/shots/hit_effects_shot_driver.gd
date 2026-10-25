extends Node3D
## Shot driver for the hit effects up close: a target dummy, a stream of laser shots coming in
## from the left and then autocannon rounds once the shield is gone. Shows the tracer, the
## muzzle-less impact flash, the shield ripple (shots 1-10 hit the shield), and the sparks (armor).
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N.

const SHOOT_FROM: Vector3 = Vector3(-90.0, 14.0, 60.0)
const HIT_POINT: Vector3 = Vector3(-7.0, 1.5, 4.0)
const LASER_EVERY: int = 4
const SWITCH_TICK: int = 80

var _tick: int = 0
var _manager: ProjectileManager = null
var _dummy: TargetDummy = null


func _ready() -> void:
	var arena: ArenaDef = Content.get_def(&"arena", &"flight_test") as ArenaDef
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = FlightTest.make_environment(arena, null)
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.basis = Basis.looking_at(Vector3(-0.5, -0.6, -0.6), Vector3.UP)
	add_child(sun)
	_manager = ProjectileManager.new()
	add_child(_manager)
	_dummy = CombatSim.spawn_dummy(self, &"standard", Vector3.ZERO)


func _physics_process(_delta: float) -> void:
	_tick += 1
	# The director frees the scene's children before it quits.
	if _tick < 6 or not is_instance_valid(_manager):
		return
	var laser: bool = _tick < SWITCH_TICK
	var every: int = LASER_EVERY if laser else 2
	if _tick % every == 0:
		var weapon: WeaponDef = Content.weapon(&"pulse_laser" if laser else &"autocannon")
		var aim: Vector3 = HIT_POINT + Vector3(0.0, sin(_tick * 0.7) * 2.0, cos(_tick * 1.3) * 2.0)
		_manager.spawn(weapon, null, SHOOT_FROM, aim - SHOOT_FROM)
