extends GdUnitTestSuite
## `CombatFx`: what kind of hit a damage result is, flash maths, and the pools reusing their nodes.

const KINDS: Array = [
	[DamageTable.Layer.SHIELD, CombatFx.ImpactKind.SHIELD],
	[DamageTable.Layer.ARMOR, CombatFx.ImpactKind.ARMOR],
	[DamageTable.Layer.HULL, CombatFx.ImpactKind.HULL],
]


func _fx() -> CombatFx:
	var fx: CombatFx = auto_free(CombatFx.new())
	add_child(fx)
	return fx


func _result(layer: int) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	match layer:
		DamageTable.Layer.SHIELD:
			result.shield_damage = 5.0
		DamageTable.Layer.ARMOR:
			result.armor_damage = 5.0
		_:
			result.hull_damage = 5.0
	return result


func test_the_kind_of_a_hit_is_the_deepest_layer_it_reached() -> void:
	for pair: Array in KINDS:
		assert_int(CombatFx.impact_kind(_result(pair[0] as int))).is_equal(pair[1] as int)
	var through: DamageResult = _result(DamageTable.Layer.SHIELD)
	through.armor_damage = 3.0
	through.hull_damage = 1.0
	assert_int(CombatFx.impact_kind(through)).is_equal(CombatFx.ImpactKind.HULL)


func test_a_hit_with_no_result_or_no_damage_is_a_world_hit() -> void:
	assert_int(CombatFx.impact_kind(null)).is_equal(CombatFx.ImpactKind.WORLD)
	assert_int(CombatFx.impact_kind(DamageResult.new())).is_equal(CombatFx.ImpactKind.WORLD)


func test_every_kind_has_its_own_sound() -> void:
	var streams: Array = []
	for kind: int in CombatFx.ImpactKind.values():
		var stream: AudioStream = CombatFx.hit_stream(kind as CombatFx.ImpactKind)
		assert_object(stream).is_not_null()
		assert_array(streams).not_contains([stream])
		streams.append(stream)


func test_shield_hits_are_cool_and_armor_hits_use_the_weapon_colour() -> void:
	var weapon: WeaponDef = Content.weapon(&"autocannon")
	assert_object(CombatFx.impact_color(CombatFx.ImpactKind.SHIELD, weapon)).is_equal(
		CombatFx.SHIELD_COLOR
	)
	assert_object(CombatFx.impact_color(CombatFx.ImpactKind.ARMOR, weapon)).is_equal(
		weapon.impact_color
	)
	assert_object(CombatFx.impact_color(CombatFx.ImpactKind.HULL, weapon)).is_equal(
		weapon.impact_color
	)
	assert_object(CombatFx.impact_color(CombatFx.ImpactKind.WORLD, weapon)).is_equal(
		CombatFx.WORLD_COLOR
	)


func test_flash_scale_shrinks_to_nothing() -> void:
	assert_float(CombatFx.flash_scale(0.1, 0.1)).is_equal(1.0)
	assert_float(CombatFx.flash_scale(0.05, 0.1)).is_equal_approx(0.5, 0.0001)
	assert_float(CombatFx.flash_scale(0.0, 0.1)).is_equal(0.0)
	assert_float(CombatFx.flash_scale(1.0, 0.0)).is_equal(0.0)


func test_a_muzzle_flash_shows_and_then_fades() -> void:
	var fx: CombatFx = _fx()
	fx.muzzle(Vector3(1, 2, 3), Content.weapon(&"pulse_laser"))
	assert_int(fx.active_flashes()).is_equal(1)
	fx._process(CombatFx.FLASH_TIME + 0.01)
	assert_int(fx.active_flashes()).is_equal(0)


func test_armor_and_hull_hits_throw_sparks_but_shield_hits_do_not() -> void:
	var fx: CombatFx = _fx()
	var weapon: WeaponDef = Content.weapon(&"pulse_laser")
	fx.impact(Vector3.ZERO, Vector3.UP, weapon, _result(DamageTable.Layer.SHIELD))
	assert_int(fx.active_sparks()).is_equal(0)
	assert_int(fx.active_flashes()).is_equal(1)
	fx.impact(Vector3.ZERO, Vector3.UP, weapon, _result(DamageTable.Layer.ARMOR))
	assert_int(fx.active_sparks()).is_equal(1)
	fx.impact(Vector3.ZERO, Vector3.UP, weapon, null)
	assert_int(fx.active_sparks()).is_equal(2)


func test_the_pools_reuse_their_nodes_under_heavy_fire() -> void:
	var fx: CombatFx = _fx()
	var weapon: WeaponDef = Content.weapon(&"autocannon")
	var children_before: int = fx.get_child_count()
	for shot: int in 500:
		fx.muzzle(Vector3(shot, 0, 0), weapon)
		fx.impact(Vector3(0, shot, 0), Vector3.UP, weapon, _result(DamageTable.Layer.HULL))
	assert_int(fx.get_child_count()).is_equal(children_before)
	assert_int(fx.active_flashes()).is_less_equal(CombatFx.FLASH_POOL)
	assert_int(fx.active_sounds()).is_less_equal(CombatFx.SOUND_POOL)


func test_a_shot_sound_plays_at_the_muzzle() -> void:
	var fx: CombatFx = _fx()
	fx.muzzle(Vector3(4, 5, 6), Content.weapon(&"pulse_laser"))
	assert_int(fx.active_sounds()).is_equal(1)


func test_an_explosion_is_a_big_flash_over_a_core_with_sparks_and_a_sound() -> void:
	var fx: CombatFx = _fx()
	fx.explosion(Vector3(0, 0, -100), 16.0, Color(1.0, 0.6, 0.25))
	assert_int(fx.active_flashes()).is_equal(2)
	assert_int(fx.active_sparks()).is_equal(1)
	assert_int(fx.active_sounds()).is_equal(1)


func test_big_flashes_keep_their_size_and_small_ones_do_not() -> void:
	var fx: CombatFx = _fx()
	fx.flash(Vector3(0, 0, -50), Color.WHITE, 20.0, 0.5)
	var big: Array[MeshInstance3D] = []
	var small: Array[MeshInstance3D] = []
	for child: Node in fx.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			big.append(child as MeshInstance3D)
	assert_array(big).has_size(1)
	assert_float(big[0].scale.x).is_equal_approx(20.0 * (0.4 + 0.6), 0.001)
	var material: StandardMaterial3D = (big[0].mesh as QuadMesh).material as StandardMaterial3D
	assert_bool(material.billboard_keep_scale).is_true()
	# The muzzle flash pool is drawn at the billboard's unit size, as before.
	fx.muzzle(Vector3.ZERO, Content.weapon(&"pulse_laser"))
	for child: Node in fx.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible and child != big[0]:
			small.append(child as MeshInstance3D)
	assert_array(small).has_size(1)
	var small_material: StandardMaterial3D = (
		(small[0].mesh as QuadMesh).material as StandardMaterial3D
	)
	assert_bool(small_material.billboard_keep_scale).is_false()


func test_flashes_fade_and_free_their_slot() -> void:
	var fx: CombatFx = _fx()
	fx.flash(Vector3.ZERO, Color.WHITE, 10.0, 0.2)
	assert_int(fx.active_flashes()).is_equal(1)
	fx._process(0.25)
	assert_int(fx.active_flashes()).is_equal(0)


func test_play_sets_the_pitch() -> void:
	var fx: CombatFx = _fx()
	fx.play(CombatFx.SOUND_EXPLOSION, Vector3.ZERO, -6.0, 1.5)
	var pitches: Array[float] = []
	for child: Node in fx.get_children():
		if child is AudioStreamPlayer3D and (child as AudioStreamPlayer3D).playing:
			pitches.append((child as AudioStreamPlayer3D).pitch_scale)
	assert_array(pitches).is_equal([1.5])
