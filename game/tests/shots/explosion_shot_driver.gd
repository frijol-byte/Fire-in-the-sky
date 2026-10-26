extends Node3D
## Shot driver for the explosion up close (M2-T6): one Kestrel in open space is destroyed and the
## camera stands off to the side, so the shots follow the flash, the fireball and shockwave ring, the
## debris chunks (hot at first, then cooling) and the tumbling wreck shrinking away.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N.

const KILL_TICK: int = 20

var _tick: int = 0
var _ship: Ship = null


func _ready() -> void:
	var arena: ArenaDef = Content.get_def(&"arena", &"flight_test") as ArenaDef
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = FlightTest.make_environment(arena, null)
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.basis = Basis.looking_at(Vector3(-0.5, -0.6, -0.6), Vector3.UP)
	add_child(sun)
	var camera: Camera3D = Camera3D.new()
	camera.far = 4000.0
	add_child(camera)
	camera.make_current()
	add_child(DestructionManager.new())
	_ship = CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	_ship.stance = Targeting.Stance.HOSTILE


func _physics_process(_delta: float) -> void:
	_tick += 1
	# The director frees the scene's children before it quits.
	if _tick != KILL_TICK or not is_instance_valid(_ship):
		return
	_ship.linear_velocity = Vector3(0.0, 0.0, -25.0)
	_ship.durability().apply(DamageInfo.make(100000.0, DamageInfo.Type.EXPLOSIVE))
