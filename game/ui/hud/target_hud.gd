class_name TargetHud
extends Control
## The targeting part of the flight HUD (GDD 7.3): a small marker on every target in range, with the
## selected one boxed in brackets whose shape tells whose side it is on, edge arrows that point
## towards targets you cannot see, the lead indicator (shoot where it says), and a panel with the
## selected target's name, distance and shield, armor and hull. It is a child of `FlightHud` and
## only needs a ship and the current 3D camera. `HudMath` decides, this draws.
##
## Positions are read from the interpolated transforms, like the camera, so everything stays glued
## to what is on screen at any frame rate.

const EDGE_MARGIN: float = 56.0
const LINE_WIDTH: float = 2.0
## Smallest and largest half-size of the selected target's brackets, and the room left around it.
const MIN_BRACKET: float = 24.0
const MAX_BRACKET: float = 150.0
const BRACKET_PADDING: float = 1.3
## Half-size of the marker on a target that is not selected.
const SMALL_BRACKET: float = 9.0
const ARROW_SIZE: float = 11.0
const SELECTED_ARROW_SIZE: float = 16.0
## Edge arrows for this many of the nearest hostile targets (the selected one always has one).
const MAX_ARROWS: int = 6
const LEAD_RADIUS: float = 10.0
## The lead indicator turns to the aligned colour when the nose ring is this close (pixels) to it,
## or inside the brackets, whichever is larger.
const ALIGNED_PIXELS: float = 14.0
const NOSE_EDGE_MARGIN: float = 56.0
const PANEL_WIDTH: float = 320.0
const PANEL_RIGHT_MARGIN: float = 56.0
const PANEL_TOP: float = 230.0
const PANEL_PADDING: float = 14.0
const BAR_HEIGHT: float = 8.0
const BAR_LABEL_WIDTH: float = 96.0
const NAME_FONT_SIZE: int = 26
const INFO_FONT_SIZE: int = 19
const COLOR_HOSTILE: Color = Color(1.0, 0.36, 0.28, 0.95)
const COLOR_NEUTRAL: Color = Color(1.0, 0.85, 0.3, 0.95)
const COLOR_FRIENDLY: Color = Color(0.4, 1.0, 0.6, 0.95)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.55)
const COLOR_LEAD: Color = Color(1.0, 0.95, 0.55, 0.95)
const COLOR_ALIGNED: Color = Color(0.55, 1.0, 0.7, 1.0)
const COLOR_PANEL: Color = Color(0.02, 0.03, 0.05, 0.55)
const COLOR_TEXT: Color = Color(0.92, 0.96, 1.0, 0.95)
const COLOR_WARN: Color = Color(1.0, 0.45, 0.25, 1.0)
const COLOR_BAR_BACK: Color = Color(1.0, 1.0, 1.0, 0.18)
const COLOR_SHIELD: Color = Color(0.4, 0.85, 1.0, 0.95)
const COLOR_ARMOR: Color = Color(1.0, 0.75, 0.3, 0.95)
const COLOR_HULL: Color = Color(0.95, 0.95, 0.95, 0.95)
## A target that is not locked is drawn this much fainter.
const UNLOCKED_ALPHA: float = 0.55

var ship: Ship = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the targets seen from `new_ship`.
func bind(new_ship: Ship) -> void:
	ship = new_ship


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if ship == null or not ship.is_inside_tree():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var targeting: Targeting = ship.targeting()
	var drawn: Transform3D = ship.get_global_transform_interpolated()
	var forward: Vector3 = -drawn.basis.z
	var selected: Node3D = targeting.target
	var others: Array[Targeting.Candidate] = []
	for candidate: Targeting.Candidate in targeting.candidates():
		if candidate.node != selected:
			candidate.position = candidate.node.get_global_transform_interpolated().origin
			others.append(candidate)
	_draw_others(camera, others)
	if selected != null:
		var chosen: Targeting.Candidate = Targeting.Candidate.from_node(
			selected, drawn.origin, forward
		)
		if chosen != null:
			chosen.position = selected.get_global_transform_interpolated().origin
			chosen.distance = drawn.origin.distance_to(chosen.position)
			_draw_selected(camera, targeting, chosen, drawn)
			_draw_panel(targeting, chosen)


## A small marker on every target in view, and arrows for the nearest hostile ones out of view.
func _draw_others(camera: Camera3D, others: Array[Targeting.Candidate]) -> void:
	others.sort_custom(
		func(a: Targeting.Candidate, b: Targeting.Candidate) -> bool: return a.distance < b.distance
	)
	var arrows: int = 0
	for candidate: Targeting.Candidate in others:
		var marker: HudMath.Marker = HudMath.marker_at(
			camera, candidate.position, size, EDGE_MARGIN
		)
		var color: Color = stance_color(candidate.stance)
		if marker.on_screen:
			_draw_strokes(
				HudMath.bracket_strokes(candidate.stance, SMALL_BRACKET),
				marker.position,
				Color(color, color.a * UNLOCKED_ALPHA)
			)
		elif candidate.stance == Targeting.Stance.HOSTILE and arrows < MAX_ARROWS:
			arrows += 1
			_draw_arrow(marker, Color(color, color.a * UNLOCKED_ALPHA), ARROW_SIZE)


func _draw_selected(
	camera: Camera3D, targeting: Targeting, chosen: Targeting.Candidate, drawn: Transform3D
) -> void:
	var color: Color = stance_color(chosen.stance)
	if not targeting.has_lock():
		color = Color(color, color.a * UNLOCKED_ALPHA)
	var marker: HudMath.Marker = HudMath.marker_at(camera, chosen.position, size, EDGE_MARGIN)
	if not marker.on_screen:
		_draw_arrow(marker, color, SELECTED_ARROW_SIZE)
		return
	var half: float = bracket_half_size(
		HudMath.projected_radius(chosen.radius, chosen.distance, camera.fov, size.y)
	)
	_draw_strokes(HudMath.bracket_strokes(chosen.stance, half), marker.position, color, 2.5)
	if targeting.has_lock() and targeting.has_lead:
		_draw_lead(camera, chosen, drawn, marker.position, half)


## The lead indicator: a small reticle where a shot fired now would meet the moving target.
func _draw_lead(
	camera: Camera3D,
	chosen: Targeting.Candidate,
	drawn: Transform3D,
	target_screen: Vector2,
	half: float
) -> void:
	var weapon: WeaponDef = ship.weapons().weapon_for(WeaponSystem.GROUP_PRIMARY)
	if weapon == null:
		return
	var point: Vector3 = Lead.solve(
		drawn.origin,
		ship.linear_velocity,
		chosen.position,
		chosen.velocity,
		weapon.projectile_speed
	)
	var lead: HudMath.Marker = HudMath.marker_at(camera, point, size, EDGE_MARGIN)
	if not lead.on_screen:
		return
	var nose: HudMath.Marker = HudMath.marker_for(
		camera, drawn.origin, -drawn.basis.z, size, NOSE_EDGE_MARGIN
	)
	var aligned: bool = (
		nose.on_screen and nose.position.distance_to(lead.position) <= maxf(half, ALIGNED_PIXELS)
	)
	var color: Color = COLOR_ALIGNED if aligned else COLOR_LEAD
	if chosen.distance > weapon.range_m:
		# The shot would be gone before it got there: show where, but fainter.
		color = Color(color, color.a * UNLOCKED_ALPHA)
	if target_screen.distance_to(lead.position) > half:
		draw_line(target_screen, lead.position, Color(color, color.a * 0.35), 1.0, true)
	draw_arc(lead.position, LEAD_RADIUS, 0.0, TAU, 24, COLOR_OUTLINE, LINE_WIDTH + 3.0, true)
	draw_arc(lead.position, LEAD_RADIUS, 0.0, TAU, 24, color, LINE_WIDTH, true)
	draw_circle(lead.position, 2.0, color)


func _draw_panel(targeting: Targeting, chosen: Targeting.Candidate) -> void:
	var font: Font = get_theme_default_font()
	var left: float = size.x - PANEL_WIDTH - PANEL_RIGHT_MARGIN
	var lines: int = 1 if targeting.has_lock() else 2
	var height: float = PANEL_PADDING * 2.0 + 30.0 + 26.0 * lines + 3.0 * 22.0
	draw_rect(Rect2(left, PANEL_TOP, PANEL_WIDTH, height), COLOR_PANEL)
	var color: Color = stance_color(chosen.stance)
	var x: float = left + PANEL_PADDING
	var y: float = PANEL_TOP + PANEL_PADDING + NAME_FONT_SIZE
	draw_string(
		font,
		Vector2(x, y),
		chosen.display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		NAME_FONT_SIZE,
		color
	)
	y += 26.0
	var info: String = (
		TranslationServer.translate(HudMath.stance_key(chosen.stance))
		+ "     "
		+ HudMath.distance_text(chosen.distance)
	)
	draw_string(
		font, Vector2(x, y), info, HORIZONTAL_ALIGNMENT_LEFT, -1, INFO_FONT_SIZE, COLOR_TEXT
	)
	if not targeting.has_lock():
		y += 26.0
		var why: String = TranslationServer.translate(HudMath.lock_key(targeting.lock))
		draw_string(
			font, Vector2(x, y), why, HORIZONTAL_ALIGNMENT_LEFT, -1, INFO_FONT_SIZE, COLOR_WARN
		)
	var durability: Durability = ProjectileManager.durability_of(chosen.node)
	if durability == null:
		return
	var fractions: Vector3 = health_fractions(durability)
	y += 14.0
	_draw_bar(font, x, y, "HUD_SHIELD", fractions.x, COLOR_SHIELD)
	_draw_bar(font, x, y + 22.0, "HUD_ARMOR", fractions.y, COLOR_ARMOR)
	_draw_bar(font, x, y + 44.0, "HUD_HULL", fractions.z, COLOR_HULL)


func _draw_bar(font: Font, x: float, y: float, key: String, fraction: float, color: Color) -> void:
	draw_string(
		font,
		Vector2(x, y + BAR_HEIGHT + 3.0),
		TranslationServer.translate(key),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		INFO_FONT_SIZE - 3,
		COLOR_TEXT
	)
	var bar_left: float = x + BAR_LABEL_WIDTH
	var bar_width: float = PANEL_WIDTH - PANEL_PADDING * 2.0 - BAR_LABEL_WIDTH
	draw_rect(Rect2(bar_left, y, bar_width, BAR_HEIGHT), COLOR_BAR_BACK)
	draw_rect(Rect2(bar_left, y, bar_width * clampf(fraction, 0.0, 1.0), BAR_HEIGHT), color)


func _draw_strokes(
	strokes: Array[PackedVector2Array], center: Vector2, color: Color, width: float = LINE_WIDTH
) -> void:
	for stroke: PackedVector2Array in strokes:
		var moved: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in stroke:
			moved.append(point + center)
		draw_polyline(moved, COLOR_OUTLINE, width + 3.0, true)
	for stroke: PackedVector2Array in strokes:
		var moved: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in stroke:
			moved.append(point + center)
		draw_polyline(moved, color, width, true)


func _draw_arrow(marker: HudMath.Marker, color: Color, arrow_size: float) -> void:
	var points: PackedVector2Array = HudMath.arrow_points(
		marker.position, marker.position - size * 0.5, arrow_size
	)
	draw_colored_polygon(points, color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, COLOR_OUTLINE, 1.5, true)


## The colour of a stance (hostile red, neutral yellow, friendly green).
static func stance_color(stance: Targeting.Stance) -> Color:
	match stance:
		Targeting.Stance.NEUTRAL:
			return COLOR_NEUTRAL
		Targeting.Stance.FRIENDLY:
			return COLOR_FRIENDLY
	return COLOR_HOSTILE


## Half-size in pixels of the selected target's brackets for a target covering `projected_radius`
## pixels: a little bigger than the target, never tiny and never filling the screen.
static func bracket_half_size(projected_radius: float) -> float:
	return clampf(projected_radius * BRACKET_PADDING, MIN_BRACKET, MAX_BRACKET)


## The fraction left of (shield, armor, hull) for the panel's bars.
static func health_fractions(durability: Durability) -> Vector3:
	return Vector3(
		durability.shield_fraction(), durability.armor_fraction(), durability.hull_fraction()
	)
