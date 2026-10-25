extends GdUnitTestSuite
## `DamageTable`: the GDD 7.1 multipliers as data, and its validation.

const TYPES: Array[DamageInfo.Type] = [
	DamageInfo.Type.ENERGY,
	DamageInfo.Type.KINETIC,
	DamageInfo.Type.EXPLOSIVE,
	DamageInfo.Type.ION,
]
const LAYERS: Array[DamageTable.Layer] = [
	DamageTable.Layer.SHIELD, DamageTable.Layer.ARMOR, DamageTable.Layer.HULL
]


func test_the_default_table_is_loaded_by_content() -> void:
	var table: DamageTable = Content.damage_table()
	assert_object(table).is_not_null()
	assert_array(table.problems()).is_empty()


func test_the_default_table_matches_the_gdd() -> void:
	# GDD 7.1, rows: type, then (vs shield, vs armor, vs hull).
	var gdd: Array = [
		[DamageInfo.Type.ENERGY, 1.5, 0.75, 1.0],
		[DamageInfo.Type.KINETIC, 0.75, 1.5, 1.0],
		[DamageInfo.Type.EXPLOSIVE, 1.0, 1.0, 1.25],
		[DamageInfo.Type.ION, 2.0, 0.25, 0.0],
	]
	var table: DamageTable = Content.damage_table()
	for row: Array in gdd:
		for layer: int in LAYERS.size():
			assert_float(table.multiplier(row[0], LAYERS[layer])).is_equal(row[layer + 1])


func test_every_type_and_layer_has_a_multiplier() -> void:
	var table: DamageTable = Content.damage_table()
	for type: DamageInfo.Type in TYPES:
		for layer: DamageTable.Layer in LAYERS:
			assert_float(table.multiplier(type, layer)).is_greater_equal(0.0)


func test_negative_multipliers_and_ion_time_are_rejected() -> void:
	var table: DamageTable = Content.damage_table().duplicate() as DamageTable
	table.kinetic = Vector3(0.75, -1.0, 1.0)
	table.ion_disable_seconds = -1.0
	assert_array(table.problems()).has_size(2)
