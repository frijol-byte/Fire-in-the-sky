extends GdUnitTestSuite
## `PowerSystem.retune`: new capacitor numbers without a free refill.


func test_retune_keeps_the_energy_held() -> void:
	var power: PowerSystem = auto_free(PowerSystem.new())
	var def: ShipDef = Content.ship(&"kestrel").duplicate() as ShipDef
	power.configure(def)
	power.energy = 40.0
	def.energy_capacity = 200.0
	def.energy_regen = 30.0
	power.retune(def)
	assert_float(power.capacity).is_equal(200.0)
	assert_float(power.regen_per_second).is_equal(30.0)
	assert_float(power.energy).is_equal(40.0)


func test_retune_caps_energy_to_a_smaller_capacitor() -> void:
	var power: PowerSystem = auto_free(PowerSystem.new())
	var def: ShipDef = Content.ship(&"kestrel").duplicate() as ShipDef
	power.configure(def)
	def.energy_capacity = 50.0
	power.retune(def)
	assert_float(power.energy).is_equal(50.0)
