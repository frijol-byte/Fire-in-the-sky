extends GdUnitTestSuite
## The "Durability" group of `ShipDef`: every ship has sane numbers, and bad ones are caught.


func test_every_ship_has_valid_durability_numbers() -> void:
	for id: StringName in Content.ids(&"ship"):
		var def: ShipDef = Content.ship(id)
		assert_float(def.hull_capacity).is_greater(0.0)
		assert_float(def.shield_capacity).is_greater(0.0)
		assert_float(def.shield_regen_delay).is_equal(4.0)


func test_the_heavier_ships_are_tougher_than_the_light_fighter() -> void:
	var kestrel: ShipDef = Content.ship(&"kestrel")
	for id: StringName in [&"bulwark", &"drayman"]:
		var def: ShipDef = Content.ship(id)
		var tough: float = def.shield_capacity + def.armor_capacity + def.hull_capacity
		var light: float = kestrel.shield_capacity + kestrel.armor_capacity + kestrel.hull_capacity
		assert_float(tough).is_greater(light)


func test_bad_durability_values_are_rejected() -> void:
	var def: ShipDef = Content.ship(&"kestrel").duplicate() as ShipDef
	def.hull_capacity = 0.0
	def.armor_capacity = -1.0
	def.shield_regen = -1.0
	assert_array(def.problems()).has_size(3)
