class_name RingGate
extends Node3D
## A ring to fly through. The rim glows amber and flashes when a ship passes through the
## opening. The frame is solid (so bumping it bounces), the opening is a trigger.
##
## The ring is the Blender prop `ring_gate` (60 m opening). It lies in the local XY plane, so a
## ship flying through it flies along the gate's local Z axis. The numbers below mirror the
## recipe (`tools/blender/recipes/props/ring_gate.py`).

## Emitted when a ship enters the opening.
signal passed(ship: Ship)

## Radius of the opening and of the frame's outer edge, at scale 1.
const INNER_RADIUS: float = 30.0
const OUTER_RADIUS: float = 34.0
## The pylons stick out a little further; nothing is placed closer than this to a gate's centre.
const CLEAR_RADIUS: float = 40.0
## Depth of the frame along the flight axis.
const DEPTH: float = 6.0
## Number of struts, and the fraction of each strut's arc the collider covers.
const STRUTS: int = 12
## The trigger is smaller than the opening, so grazing the frame does not count.
const TRIGGER_RADIUS: float = 26.0
const TRIGGER_DEPTH: float = 4.0
## Seconds the flash takes to fade.
const FLASH_TIME: float = 1.2
const RIM_NODE: String = "rim_light"

@export var idle_color: Color = Color(1.0, 0.6, 0.15)
@export var pass_color: Color = Color(0.7, 1.0, 0.9)
@export var idle_energy: float = 2.5
@export var pass_energy: float = 9.0

## How many ships have passed through so far.
var pass_count: int = 0

var _flash: float = 0.0
var _rim_material: StandardMaterial3D = StandardMaterial3D.new()

@onready var _model: Node3D = $Model
@onready var _trigger: Area3D = $Trigger


func _ready() -> void:
	_build_frame_colliders()
	_build_trigger()
	_style_rim()
	_trigger.body_entered.connect(_on_body_entered)
	set_process(true)


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	_apply_flash()


## Fraction of the flash still showing, 0..1.
func flash_amount() -> float:
	return _flash


func _on_body_entered(body: Node3D) -> void:
	var ship: Ship = body as Ship
	if ship == null:
		return
	pass_count += 1
	_flash = 1.0
	_apply_flash()
	passed.emit(ship)


func _apply_flash() -> void:
	_rim_material.emission = idle_color.lerp(pass_color, _flash)
	_rim_material.albedo_color = _rim_material.emission
	_rim_material.emission_energy_multiplier = lerpf(idle_energy, pass_energy, _flash)


func _style_rim() -> void:
	_rim_material.emission_enabled = true
	_rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_apply_flash()
	var rim: MeshInstance3D = _find_mesh(_model, RIM_NODE)
	if rim != null:
		rim.material_override = _rim_material


func _build_frame_colliders() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Frame"
	add_child(body)
	var radius: float = (INNER_RADIUS + OUTER_RADIUS) * 0.5
	var step: float = TAU / STRUTS
	var arc: float = 2.0 * radius * tan(step * 0.5)
	for index: int in STRUTS:
		var angle: float = (index + 0.5) * step
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(arc, OUTER_RADIUS - INNER_RADIUS, DEPTH)
		shape.shape = box
		shape.transform = Transform3D(
			Basis(Vector3.BACK, angle - PI * 0.5), Vector3(cos(angle), sin(angle), 0.0) * radius
		)
		body.add_child(shape)


func _build_trigger() -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = TRIGGER_RADIUS
	cylinder.height = TRIGGER_DEPTH
	shape.shape = cylinder
	# A cylinder's axis is Y; the ring's flight axis is Z.
	shape.basis = Basis(Vector3.RIGHT, PI * 0.5)
	_trigger.add_child(shape)


static func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name).begins_with(mesh_name):
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found: MeshInstance3D = _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null
