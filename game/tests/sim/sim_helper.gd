class_name SimHelper
extends RefCounted
## Helpers for headless, deterministic simulation tests.
##
## Pattern: build the scene under test, add it to the suite's tree, then call
## `step_physics` to advance exactly N physics ticks (60 Hz, see project.godot) and assert on
## the resulting state. Never use wall-clock timers in sim tests.
##
## `tools/check.sh` runs gdUnit with `--fixed-fps 60`, so each frame is exactly one physics
## tick and ticks run as fast as the CPU allows (a 10 s flight sim takes well under a second).

## Physics tick length in seconds (matches `physics/common/physics_ticks_per_second`).
const TICK: float = 1.0 / 60.0


## Waits for `ticks` physics frames. Must be awaited from a test.
static func step_physics(tree: SceneTree, ticks: int) -> void:
	for i: int in ticks:
		await tree.physics_frame


## Creates a zero-gravity, undamped Jolt rigid body moving at `velocity`.
static func make_drifting_body(velocity: Vector3) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp = 0.0
	body.linear_velocity = velocity
	return body
