extends Node
## Shot driver for the combat HUD (M2-T7): the combat test arena with the player's ship handed to
## a friendly AI pilot and wave 3 (three pirates) called up straight away, so hit markers, damage
## indicators, the shield / armor / hull bars, the kill banner and the comms strip all appear
## from a real fight. The camera is the arena's own chase camera.
##
## The screenshot harness renders at 30 fps against 60 physics ticks, so shot frame N is physics
## tick 2N.

var _placed: bool = false

@onready var arena: CombatTest = $"../Arena"


func _exit_tree() -> void:
	Settings.values.clear()


func _physics_process(_delta: float) -> void:
	if arena.ship == null or _placed:
		return
	_placed = true
	for child: Node in arena.ship.get_children():
		if child is PlayerPilot:
			child.queue_free()
	arena.ship.stance = Targeting.Stance.FRIENDLY
	var pilot: AIPilot = AIPilot.new()
	pilot.name = "AIPilot"
	pilot.profile = Content.ai_profile(&"standard")
	arena.ship.add_child(pilot)
	pilot.seed_rolls(21)
	arena.director.start(2, 1.0)
