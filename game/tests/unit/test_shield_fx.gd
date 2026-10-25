extends GdUnitTestSuite
## `ShieldFx`: ripples start where a hit landed, fade, and the bubble hides when none is left.


func _bubble() -> ShieldFx:
	var host: Node3D = auto_free(Node3D.new())
	add_child(host)
	var bubble: ShieldFx = ShieldFx.new()
	host.add_child(bubble)
	bubble.setup(host, Vector3.ZERO, Vector3(2, 1, 4))
	return bubble


func test_the_bubble_starts_hidden() -> void:
	assert_bool(_bubble().visible).is_false()


func test_setup_sizes_the_bubble_with_a_margin() -> void:
	var bubble: ShieldFx = _bubble()
	assert_vector(bubble.scale).is_equal_approx(
		Vector3(2, 1, 4) * ShieldFx.BOUNDS_MARGIN, Vector3(0.0001, 0.0001, 0.0001)
	)


func test_a_ripple_shows_the_bubble_and_then_fades() -> void:
	var bubble: ShieldFx = _bubble()
	bubble.ripple_at(Vector3(0, 0, -5))
	assert_bool(bubble.visible).is_true()
	assert_int(bubble.active_ripples()).is_equal(1)
	bubble.advance(ShieldFx.DURATION * 0.5)
	assert_int(bubble.active_ripples()).is_equal(1)
	bubble.advance(ShieldFx.DURATION)
	assert_int(bubble.active_ripples()).is_equal(0)
	assert_bool(bubble.visible).is_false()


func test_only_four_ripples_show_at_once() -> void:
	var bubble: ShieldFx = _bubble()
	for index: int in 9:
		bubble.ripple_at(Vector3(index, 0, -5))
	assert_int(bubble.active_ripples()).is_equal(ShieldFx.RIPPLES)


func test_a_damage_event_with_shield_loss_starts_a_ripple_for_its_own_ship_only() -> void:
	var host: Node3D = auto_free(Node3D.new())
	add_child(host)
	var other: Node3D = auto_free(Node3D.new())
	add_child(other)
	var bubble: ShieldFx = ShieldFx.new()
	host.add_child(bubble)
	bubble.setup(host, Vector3.ZERO, Vector3.ONE)
	var info: DamageInfo = DamageInfo.make(5.0, DamageInfo.Type.ENERGY, null, Vector3(0, 0, 3))
	var shield_hit: DamageResult = DamageResult.new()
	shield_hit.shield_damage = 5.0
	Events.ship_damaged.emit(other, info, shield_hit)
	assert_int(bubble.active_ripples()).is_equal(0)
	var hull_hit: DamageResult = DamageResult.new()
	hull_hit.hull_damage = 5.0
	Events.ship_damaged.emit(host, info, hull_hit)
	assert_int(bubble.active_ripples()).is_equal(0)
	Events.ship_damaged.emit(host, info, shield_hit)
	assert_int(bubble.active_ripples()).is_equal(1)


func test_bounds_cover_the_meshes_of_a_ship_model() -> void:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	var bounds: AABB = ShieldFx.bounds_of(ship.model, ship)
	# The Kestrel is a few metres wide and about 14 m long, nose along -Z.
	assert_float(bounds.size.z).is_between(8.0, 30.0)
	assert_float(bounds.size.x).is_between(3.0, 30.0)


func test_bounds_of_an_empty_node_fall_back_to_a_default_box() -> void:
	var empty: Node3D = auto_free(Node3D.new())
	add_child(empty)
	assert_float(ShieldFx.bounds_of(empty, empty).size.x).is_greater(0.0)
