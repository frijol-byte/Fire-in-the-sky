class_name ShotDef
extends Resource
## One screenshot taken by a `ShotDirector`: which frame to keep and, optionally, where
## the camera stands and what it looks at.

## Used in the PNG file name (`<scene>_<label>.png`). Lowercase letters, digits, underscores.
@export var label: String = "shot"
## Frame number to capture (0-based). Allow a few frames for the scene to settle, so 2+.
@export var frame: int = 2
## When false the camera is left alone (use for UI scenes, or to keep the scene's own camera).
@export var move_camera: bool = true
@export var camera_position: Vector3 = Vector3(0.0, 0.0, 10.0)
@export var look_at_point: Vector3 = Vector3.ZERO
@export var fov: float = 60.0
