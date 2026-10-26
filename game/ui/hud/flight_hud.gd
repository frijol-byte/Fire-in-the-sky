class_name FlightHud
extends Control
## Flight HUD v0 (art bible 7: minimal modern). Bottom center: speed, flight assist and boost
## state, and the energy bar. In the view: a ring where the nose points and a flight-path marker
## where the ship is actually going. With flight assist on the two sit together; drifting (FA off)
## pulls them apart, which is how you read your momentum. With mouse flight, a faint ring in the
## center and a dot show where the mouse virtual stick points. The same HUD is later drawn on the
## cockpit's holo plane, so it only needs a camera, not a particular view. The target brackets, edge
## arrows, lead indicator and target panel are drawn by the `TargetHud` child; hit markers, damage
## indicators and the ship's shield / armor / hull bars by `FeedbackHud`; radio lines by `CommsStrip`.

const NOSE_RADIUS: float = 11.0
const VELOCITY_RADIUS: float = 18.0
const EDGE_MARGIN: float = 56.0
const LINE_WIDTH: float = 2.0
const BAR_WIDTH: float = 480.0
const BAR_HEIGHT: float = 8.0
const BAR_BOTTOM_OFFSET: float = 92.0
const HEAT_BAR_BOTTOM_OFFSET: float = 40.0
const MOUSE_DOT_RADIUS: float = 5.0
## How long "BOOST EMPTY" shows after the capacitor runs dry.
const DEPLETED_SECONDS: float = 1.5
const COLOR_MAIN: Color = Color(0.92, 0.96, 1.0, 0.95)
const COLOR_VELOCITY: Color = Color(0.4, 1.0, 0.85, 0.95)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.55)
const COLOR_WARN: Color = Color(1.0, 0.45, 0.25, 1.0)
const COLOR_BAR_BACK: Color = Color(1.0, 1.0, 1.0, 0.18)
const COLOR_MOUSE: Color = Color(0.92, 0.96, 1.0, 0.85)
const COLOR_MOUSE_RING: Color = Color(0.92, 0.96, 1.0, 0.35)

var ship: Ship = null

var _depleted_left: float = 0.0

@onready var _speed: Label = $Speed
@onready var _state: Label = $State
@onready var _energy: Label = $Energy
@onready var _weapon: Label = $Weapon
@onready var _secondary: Label = $Secondary
@onready var _device: Label = $Device
@onready var _targets: TargetHud = $TargetHud
@onready var _warning: MissileWarning = $MissileWarning
@onready var _feedback: FeedbackHud = $FeedbackHud
@onready var _comms: CommsStrip = $CommsStrip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.boost_depleted.connect(_on_boost_depleted)


## Shows the flight data of `new_ship`.
func bind(new_ship: Ship) -> void:
	ship = new_ship
	_targets.bind(new_ship)
	_warning.bind(new_ship)
	_feedback.bind(new_ship)
	_refresh()


## The combat feedback layer (hit markers, damage indicators, status bars, banners).
func feedback() -> FeedbackHud:
	return _feedback


## The radio strip.
func comms() -> CommsStrip:
	return _comms


func _process(delta: float) -> void:
	_depleted_left = maxf(_depleted_left - delta, 0.0)
	_refresh()
	queue_redraw()


func _draw() -> void:
	if ship == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	# Where the ship is drawn this frame (physics interpolation), like the camera that follows it.
	var drawn: Transform3D = ship.get_global_transform_interpolated()
	var origin: Vector3 = drawn.origin
	var nose: HudMath.Marker = HudMath.marker_for(camera, origin, -drawn.basis.z, size, EDGE_MARGIN)
	if nose.on_screen:
		draw_arc(nose.position, NOSE_RADIUS, 0.0, TAU, 32, COLOR_OUTLINE, LINE_WIDTH + 3.0, true)
		draw_arc(nose.position, NOSE_RADIUS, 0.0, TAU, 32, COLOR_MAIN, LINE_WIDTH, true)
		draw_circle(nose.position, 2.0, COLOR_MAIN)
	if ship.linear_velocity.length() >= HudMath.MIN_MARKER_SPEED:
		var velocity: HudMath.Marker = HudMath.marker_for(
			camera, origin, ship.linear_velocity, size, EDGE_MARGIN
		)
		_draw_velocity_marker(velocity)
	if InputRouter.mouse_flight_active():
		_draw_mouse_stick(InputRouter.mouse_offset(), InputRouter.mouse_deadzone_px())
	_draw_energy_bar()
	_draw_heat_bar()


## The mouse virtual stick: its deadzone ring in the center and a dot where it points.
func _draw_mouse_stick(offset: Vector2, deadzone: float) -> void:
	var center: Vector2 = size * 0.5
	draw_arc(center, deadzone, 0.0, TAU, 32, COLOR_MOUSE_RING, 1.5, true)
	draw_circle(center + offset, MOUSE_DOT_RADIUS + 2.0, COLOR_OUTLINE)
	draw_circle(center + offset, MOUSE_DOT_RADIUS, COLOR_MOUSE)


## The flight path marker: a ring with a wing on each side and a fin on top. Pinned to the screen
## edge and dimmed when the ship is going somewhere you cannot see.
func _draw_velocity_marker(marker: HudMath.Marker) -> void:
	var color: Color = COLOR_VELOCITY if marker.on_screen else COLOR_VELOCITY * Color(1, 1, 1, 0.55)
	var center: Vector2 = marker.position
	var radius: float = VELOCITY_RADIUS
	var strokes: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-radius, 0.0), Vector2(-radius * 2.0, 0.0)]),
		PackedVector2Array([Vector2(radius, 0.0), Vector2(radius * 2.0, 0.0)]),
		PackedVector2Array([Vector2(0.0, -radius), Vector2(0.0, -radius * 1.8)]),
	]
	# A dark outline first, so the marker stays readable on a bright background.
	draw_arc(center, radius, 0.0, TAU, 32, COLOR_OUTLINE, LINE_WIDTH + 3.0, true)
	for stroke: PackedVector2Array in strokes:
		draw_line(center + stroke[0], center + stroke[1], COLOR_OUTLINE, LINE_WIDTH + 3.0)
	draw_arc(center, radius, 0.0, TAU, 32, color, LINE_WIDTH, true)
	for stroke: PackedVector2Array in strokes:
		draw_line(center + stroke[0], center + stroke[1], color, LINE_WIDTH)


func _draw_energy_bar() -> void:
	var fraction: float = clampf(ship.power().fraction(), 0.0, 1.0)
	var left: float = (size.x - BAR_WIDTH) * 0.5
	var top: float = size.y - BAR_BOTTOM_OFFSET
	draw_rect(Rect2(left, top, BAR_WIDTH, BAR_HEIGHT), COLOR_BAR_BACK)
	var boost_ready: float = ship.def.boost_min_energy / ship.power().capacity
	var color: Color = COLOR_MAIN if fraction >= boost_ready else COLOR_WARN
	draw_rect(Rect2(left, top, BAR_WIDTH * fraction, BAR_HEIGHT), color)
	# A tick at the energy needed to start a boost.
	var tick_x: float = left + BAR_WIDTH * boost_ready
	draw_line(Vector2(tick_x, top - 4.0), Vector2(tick_x, top + BAR_HEIGHT + 4.0), COLOR_MAIN, 1.0)


## The primary guns' heat, under the energy readout. Only guns that build heat have one.
func _draw_heat_bar() -> void:
	var weapons: WeaponSystem = ship.weapons()
	var weapon: WeaponDef = weapons.weapon_for(WeaponSystem.GROUP_PRIMARY)
	if weapon == null or weapon.heat_per_shot <= 0.0:
		return
	var fraction: float = clampf(weapons.heat_fraction(WeaponSystem.GROUP_PRIMARY), 0.0, 1.0)
	var left: float = (size.x - BAR_WIDTH) * 0.5
	var top: float = size.y - HEAT_BAR_BOTTOM_OFFSET
	draw_rect(Rect2(left, top, BAR_WIDTH, BAR_HEIGHT), COLOR_BAR_BACK)
	var hot: bool = weapons.is_overheated(WeaponSystem.GROUP_PRIMARY)
	var color: Color = COLOR_WARN if hot else COLOR_MAIN.lerp(COLOR_WARN, fraction * fraction)
	draw_rect(Rect2(left, top, BAR_WIDTH * fraction, BAR_HEIGHT), color)
	# A tick where an overheated gun starts firing again.
	var tick_x: float = left + BAR_WIDTH * weapon.overheat_resume_fraction
	draw_line(Vector2(tick_x, top - 4.0), Vector2(tick_x, top + BAR_HEIGHT + 4.0), COLOR_MAIN, 1.0)


func _refresh() -> void:
	if ship == null:
		return
	var power: PowerSystem = ship.power()
	_speed.text = speed_text(ship.linear_velocity.length())
	var fa_off: bool = ship.controls.fa_off
	var boost: HudMath.BoostState = HudMath.boost_state(
		ship.is_boosting(), _depleted_left > 0.0, power.energy, ship.def.boost_min_energy
	)
	_state.text = state_text(fa_off, boost)
	var warn: bool = fa_off or boost == HudMath.BoostState.EMPTY
	_state.add_theme_color_override("font_color", COLOR_WARN if warn else COLOR_MAIN)
	_energy.text = energy_text(power.energy, power.capacity)
	var weapons: WeaponSystem = ship.weapons()
	var overheated: bool = weapons.is_overheated(WeaponSystem.GROUP_PRIMARY)
	var starved: bool = weapons.energy_starved and ship.controls.fire_primary
	_weapon.text = weapon_text(weapons.weapon_for(WeaponSystem.GROUP_PRIMARY), overheated, starved)
	_weapon.add_theme_color_override(
		"font_color", COLOR_WARN if overheated or starved else COLOR_MAIN
	)
	_refresh_secondary()
	_refresh_device()


## The secondary weapon's line (name, ammo and lock) at the bottom left.
func _refresh_secondary() -> void:
	var secondaries: SecondarySystem = ship.secondaries()
	var disabled: bool = ship.durability().devices_disabled()
	_secondary.text = secondary_text(
		secondaries.def,
		secondaries.ammo,
		secondaries.lock,
		secondaries.cooldown_left(),
		secondaries.is_firing_salvo(),
		disabled
	)
	var warn: bool = disabled or (secondaries.def != null and secondaries.ammo <= 0)
	_secondary.add_theme_color_override("font_color", COLOR_WARN if warn else COLOR_MAIN)


## The flares' line (name and ready or cooldown) at the bottom right.
func _refresh_device() -> void:
	var devices: DeviceSystem = ship.devices()
	_device.text = device_text(devices.device_in(1), devices.cooldown_left(1))
	var disabled: bool = ship.durability().devices_disabled()
	_device.add_theme_color_override("font_color", COLOR_WARN if disabled else COLOR_MAIN)


func _on_boost_depleted(depleted_ship: Node) -> void:
	if depleted_ship == ship:
		_depleted_left = DEPLETED_SECONDS


## "184 m/s".
static func speed_text(speed: float) -> String:
	return TranslationServer.translate("HUD_SPEED") % speed


## "PULSE LASER", with "OVERHEATED" or "NO ENERGY" after it while the guns cannot fire. Empty
## without a weapon.
static func weapon_text(weapon: WeaponDef, overheated: bool, starved: bool) -> String:
	if weapon == null:
		return ""
	var text: String = TranslationServer.translate(weapon.display_name_key)
	if overheated:
		text += "     " + TranslationServer.translate("HUD_OVERHEAT")
	elif starved:
		text += "     " + TranslationServer.translate("HUD_NO_ENERGY")
	return text


## "HOMING MISSILE  6", with the lock or reload state after it. Empty without a secondary.
static func secondary_text(
	def: SecondaryDef, ammo: int, lock: MissileLock, cooldown: float, salvo: bool, disabled: bool
) -> String:
	if def == null:
		return ""
	var text: String = (
		TranslationServer.translate("HUD_SECONDARY")
		% [TranslationServer.translate(def.display_name_key), ammo]
	)
	var note: String = ""
	if disabled:
		note = "HUD_DISABLED"
	elif ammo <= 0 and not salvo:
		note = "HUD_NO_AMMO"
	elif lock.state == MissileLock.State.LOCKED:
		note = "HUD_LOCKED"
	elif lock.state == MissileLock.State.LOCKING:
		return (
			text
			+ "     "
			+ TranslationServer.translate("HUD_LOCKING") % roundi(lock.progress * 100.0)
		)
	elif cooldown > 0.0 and not salvo:
		note = "HUD_RELOADING"
	return text if note.is_empty() else text + "     " + TranslationServer.translate(note)


## "FLARES  READY", or "FLARES  5 s" while it cools down. Empty without a device.
static func device_text(def: DeviceDef, cooldown: float) -> String:
	if def == null:
		return ""
	var state: String = TranslationServer.translate("HUD_DEVICE_READY")
	if cooldown > 0.0:
		state = TranslationServer.translate("HUD_DEVICE_COOLDOWN") % ceilf(cooldown)
	return (
		TranslationServer.translate("HUD_DEVICE")
		% [TranslationServer.translate(def.display_name_key), state]
	)


## "FA ON   BOOST READY".
static func state_text(fa_off: bool, boost: HudMath.BoostState) -> String:
	return (
		TranslationServer.translate(HudMath.assist_key(fa_off))
		+ "     "
		+ TranslationServer.translate(HudMath.boost_key(boost))
	)


## "ENERGY 72".
static func energy_text(energy: float, capacity: float) -> String:
	var percent: float = 100.0 * energy / capacity if capacity > 0.0 else 0.0
	return TranslationServer.translate("HUD_ENERGY") % percent
