extends Node
## Shot driver for the ship line-up: paints each ship in its own `ShipDef` colours, like the game
## does when it spawns one.

const SHIP_IDS: Array[StringName] = [&"kestrel", &"bulwark", &"drayman"]
## Each ship is turned this many degrees about the vertical axis, so the camera sees it 3/4 on.
const YAW_DEGREES: float = 38.0
## The camera is placed here, in `_ready`: `ShotDirector` moves a camera one frame late, which
## shows in a scene that only has one shot.
const CAMERA_POSITION: Vector3 = Vector3(6.0, 28.0, 50.0)
const CAMERA_FOV: float = 48.0
const CAMERA_TARGET: Vector3 = Vector3(8.0, 0.0, 0.0)


func _ready() -> void:
	var camera: Camera3D = get_node("../Camera3D") as Camera3D
	camera.fov = CAMERA_FOV
	camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)
	for ship_id: StringName in SHIP_IDS:
		var model: ShipModel = get_node_or_null("../%s" % ship_id) as ShipModel
		var def: ShipDef = Content.ship(ship_id)
		if model != null and def != null:
			model.rotation_degrees.y = YAW_DEGREES
			model.set_paint(def.paint_primary, def.paint_secondary)
