extends GdUnitTestSuite
## The flight HUD's text and its scene wiring.

const SHIP_SCENE: PackedScene = preload("res://ships/ship.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud/flight_hud.tscn")


func test_speed_text() -> void:
	assert_str(FlightHud.speed_text(183.6)).is_equal("184 m/s")


func test_state_text_shows_assist_and_boost() -> void:
	var text: String = FlightHud.state_text(true, HudMath.BoostState.ACTIVE)
	assert_str(text).contains("FA OFF")
	assert_str(text).contains("BOOST")
	var calm: String = FlightHud.state_text(false, HudMath.BoostState.READY)
	assert_str(calm).contains("FA ON")
	assert_str(calm).contains("READY")


func test_energy_text_is_a_percentage() -> void:
	assert_str(FlightHud.energy_text(25.0, 100.0)).is_equal("ENERGY 25")
	assert_str(FlightHud.energy_text(50.0, 200.0)).is_equal("ENERGY 25")
	assert_str(FlightHud.energy_text(1.0, 0.0)).is_equal("ENERGY 0")


func test_hud_shows_the_bound_ships_speed_and_state() -> void:
	var ship: Ship = auto_free(SHIP_SCENE.instantiate()) as Ship
	ship.def = Content.ship(&"kestrel")
	add_child(ship)
	ship.linear_velocity = Vector3(0, 0, -120)
	ship.controls.fa_off = true
	var hud: FlightHud = auto_free(HUD_SCENE.instantiate()) as FlightHud
	add_child(hud)
	hud.bind(ship)
	assert_str((hud.get_node("Speed") as Label).text).is_equal("120 m/s")
	assert_str((hud.get_node("State") as Label).text).contains("FA OFF")
	assert_str((hud.get_node("Energy") as Label).text).is_equal("ENERGY 100")


func test_depleted_boost_flashes_boost_empty() -> void:
	var ship: Ship = auto_free(SHIP_SCENE.instantiate()) as Ship
	ship.def = Content.ship(&"kestrel")
	add_child(ship)
	var hud: FlightHud = auto_free(HUD_SCENE.instantiate()) as FlightHud
	add_child(hud)
	hud.bind(ship)
	Events.boost_depleted.emit(ship)
	hud._process(0.0)
	assert_str((hud.get_node("State") as Label).text).contains("EMPTY")
	hud._process(FlightHud.DEPLETED_SECONDS + 0.1)
	assert_str((hud.get_node("State") as Label).text).not_contains("EMPTY")
