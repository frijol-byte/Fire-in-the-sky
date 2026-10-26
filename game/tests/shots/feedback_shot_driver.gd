extends Node
## Shot driver for the combat feedback (M2-T7): the player's Kestrel with two pirates standing off
## its nose, and a script of hits. Each marker kind in turn (shield, armor, hull, kill), then damage
## indicators from four sides with a wave banner and radio lines, then a low shield (the alarm).
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N. A hit marker lasts about 20 ticks, so each shot is taken a few ticks after its hit.

const SHIELD_TICK: int = 20
const ARMOR_TICK: int = 60
const HULL_TICK: int = 100
const KILL_TICK: int = 140
const INDICATOR_TICK: int = 200
const ALARM_TICK: int = 260

var _tick: int = 0
var _attackers: Array[Node3D] = []

@onready var ship: Ship = $"../Ship"
@onready var fighter: Ship = $"../Fighter"
@onready var dagger: Ship = $"../Dagger"
@onready var rig: CameraRig = $"../CameraRig"
@onready var hud: FlightHud = $"../Hud/FlightHud"


func _exit_tree() -> void:
	Settings.values.clear()


func _ready() -> void:
	ship.stance = Targeting.Stance.FRIENDLY
	fighter.global_position = Vector3(0.0, 8.0, -150.0)
	dagger.global_position = Vector3(-35.0, -6.0, -230.0)
	for pirate: Ship in [fighter, dagger]:
		pirate.global_transform = Transform3D(
			Basis.looking_at(ship.global_position - pirate.global_position, Vector3.UP),
			pirate.global_position
		)
	# Three more shooters: right, left and behind the player.
	for offset: Vector3 in [Vector3(120, 0, 0), Vector3(-120, 0, 0), Vector3(0, 0, 120)]:
		var shooter: Node3D = Node3D.new()
		shooter.position = offset
		add_child(shooter)
		_attackers.append(shooter)
	rig.attach(ship)
	hud.bind(ship)
	hud.comms().push("Ashjaw", tr("BARK_ATTACK_RUN_1"))
	hud.comms().push("Two-Knives", tr("BARK_EVADE_1"))


func _physics_process(_delta: float) -> void:
	_tick += 1
	var feedback: FeedbackHud = hud.feedback()
	match _tick:
		SHIELD_TICK:
			_hit_enemy(5.0, 0.0, 0.0, false)
		ARMOR_TICK:
			_hit_enemy(0.0, 6.0, 0.0, false)
		HULL_TICK:
			_hit_enemy(0.0, 0.0, 8.0, false)
		KILL_TICK:
			_hit_enemy(0.0, 0.0, 12.0, true)
		INDICATOR_TICK:
			feedback.show_banner(tr("COMBAT_BANNER_WAVE") % [2, 3, 2], 3.0)
			_hit_player(fighter, 6.0, 0.0, 0.0)
			_hit_player(_attackers[0], 0.0, 7.0, 0.0)
			_hit_player(_attackers[1], 0.0, 0.0, 9.0)
			_hit_player(_attackers[2], 5.0, 0.0, 0.0)
		ALARM_TICK:
			ship.durability().shield = ship.durability().shield_capacity * 0.15
			ship.durability().armor = ship.durability().armor_capacity * 0.6
			_hit_player(_attackers[2], 0.0, 4.0, 0.0)


func _result(shield: float, armor: float, hull: float, destroyed: bool = false) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	result.shield_damage = shield
	result.armor_damage = armor
	result.hull_damage = hull
	result.destroyed = destroyed
	return result


func _hit_enemy(shield: float, armor: float, hull: float, kill: bool) -> void:
	var info: DamageInfo = DamageInfo.make(
		5.0, DamageInfo.Type.ENERGY, ship, fighter.global_position
	)
	Events.ship_damaged.emit(fighter, info, _result(shield, armor, hull, kill))
	if kill:
		Events.ship_destroyed.emit(fighter, info)


func _hit_player(from: Node3D, shield: float, armor: float, hull: float) -> void:
	var info: DamageInfo = DamageInfo.make(5.0, DamageInfo.Type.ENERGY, from, ship.global_position)
	Events.ship_damaged.emit(ship, info, _result(shield, armor, hull))
