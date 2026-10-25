extends GdUnitTestSuite
## The physics layer plan (`PhysicsLayers`) and who uses which layer.


func test_the_layers_are_distinct_bits() -> void:
	assert_int(PhysicsLayers.WORLD & PhysicsLayers.SHIPS).is_equal(0)
	assert_int(PhysicsLayers.WORLD & PhysicsLayers.TARGETS).is_equal(0)
	assert_int(PhysicsLayers.SHIPS & PhysicsLayers.TARGETS).is_equal(0)


func test_the_camera_only_sees_the_world() -> void:
	assert_int(PhysicsLayers.CAMERA_MASK).is_equal(PhysicsLayers.WORLD)
	var rig: CameraRig = auto_free(load("res://ships/camera_rig.tscn").instantiate()) as CameraRig
	assert_int(rig.clearance_mask).is_equal(PhysicsLayers.CAMERA_MASK)


func test_projectiles_hit_the_world_ships_and_targets() -> void:
	assert_int(PhysicsLayers.PROJECTILE_MASK & PhysicsLayers.WORLD).is_not_equal(0)
	assert_int(PhysicsLayers.PROJECTILE_MASK & PhysicsLayers.SHIPS).is_not_equal(0)
	assert_int(PhysicsLayers.PROJECTILE_MASK & PhysicsLayers.TARGETS).is_not_equal(0)


func test_a_ship_is_on_the_ship_layer_and_collides_with_everything_solid() -> void:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	assert_int(ship.collision_layer).is_equal(PhysicsLayers.SHIPS)
	assert_int(ship.collision_mask).is_equal(PhysicsLayers.SHIP_MASK)
	assert_int(ship.collision_mask & PhysicsLayers.WORLD).is_not_equal(0)


func test_a_ship_behind_the_camera_does_not_pull_it_in() -> void:
	# The clearance ray only looks at the world layer, so another ship is invisible to it.
	var other: Ship = auto_free(FlightSim.spawn(self, &"bulwark"))
	assert_int(other.collision_layer & PhysicsLayers.CAMERA_MASK).is_equal(0)
