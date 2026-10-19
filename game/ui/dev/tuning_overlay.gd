class_name TuningOverlay
extends CanvasLayer
## The flight-feel tuning overlay: a slider for every flight parameter of the player's
## `ShipDef` plus the camera lag and FOV. Sliders change the ship's `ShipDef` while it is open, so
## the next tick of flight (and the next camera frame) uses the new numbers. "Copy values"
## saves them as a `.tres` snippet (see `TuningSnippet`), puts the text on the clipboard and
## shows the file's path, so the owner can paste it into a playtest report.
##
## Opening the overlay pauses the game (the sticks would otherwise fly the ship while you
## navigate the sliders with the gamepad). The camera keeps updating, so FOV and lag changes show
## at once.

signal opened
signal closed

const PANEL_WIDTH: float = 620.0
const FONT_SIZE: int = 20
const BACKDROP_COLOR: Color = Color(0.02, 0.03, 0.06, 0.82)

var _ship: Ship = null
var _rig: CameraRig = null
var _baseline: ShipDef = null
var _params: Array[TuningParam] = TuningParam.all()
var _sliders: Array[HSlider] = []
var _value_labels: Array[Label] = []
var _status: Label = null
var _panel: PanelContainer = null
var _open: bool = false
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _saved_rig_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func _exit_tree() -> void:
	if _open:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Edits the `ShipDef` of `ship`; `rig` is the camera that should keep updating while open.
func bind(ship: Ship, rig: CameraRig) -> void:
	_ship = ship
	_rig = rig
	_baseline = ship.def.duplicate() as ShipDef
	_sync_sliders()


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	if _open or _ship == null:
		return
	_open = true
	_saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _rig != null:
		_saved_rig_mode = _rig.process_mode
		_rig.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = true
	_status.text = ""
	get_tree().paused = true
	if not _sliders.is_empty():
		_sliders[0].grab_focus()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = _saved_mouse_mode
	if _rig != null and is_instance_valid(_rig):
		_rig.process_mode = _saved_rig_mode
	closed.emit()


## Saves the current values as a snippet, copies it to the clipboard and shows where it went.
## Returns the saved file's `user://` path ("" if it could not be written).
func copy_values() -> String:
	var path: String = TuningSnippet.save(_ship.def, _params)
	if path.is_empty():
		_status.text = tr("TUNE_SAVE_FAILED")
		return ""
	DisplayServer.clipboard_set(TuningSnippet.build(_ship.def, _params))
	_status.text = tr("TUNE_SAVED") % ProjectSettings.globalize_path(path)
	Log.info(&"tuning", "tuning values saved to %s" % path)
	return path


## Puts every parameter back to the values the ship had when the overlay was bound.
func reset_values() -> void:
	for param: TuningParam in _params:
		param.write(_ship.def, param.read(_baseline))
	_ship.refresh_from_def()
	_sync_sliders()
	_status.text = tr("TUNE_RESET_DONE")


## Formats a slider value with as many decimals as its step needs: 6000, 0.12, 1.5.
static func format_value(value: float, step: float) -> String:
	return String.num(value, step_decimals(step))


func _on_slider_changed(value: float, index: int) -> void:
	var param: TuningParam = _params[index]
	param.write(_ship.def, value)
	_value_labels[index].text = format_value(value, param.step)
	_ship.refresh_from_def()


func _sync_sliders() -> void:
	for index: int in _sliders.size():
		var value: float = _params[index].read(_ship.def)
		_sliders[index].set_value_no_signal(value)
		_value_labels[index].text = format_value(value, _params[index].step)


func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE
	root.theme = theme
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -PANEL_WIDTH
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BACKDROP_COLOR
	style.set_content_margin_all(18.0)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var title: Label = Label.new()
	title.text = tr("TUNE_TITLE")
	title.add_theme_font_size_override("font_size", FONT_SIZE + 8)
	column.add_child(title)
	var hint: Label = Label.new()
	hint.text = tr("TUNE_HINT")
	hint.modulate = Color(1, 1, 1, 0.65)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	_build_rows(rows)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_status.custom_minimum_size = Vector2(0.0, 56.0)
	column.add_child(_status)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	buttons.add_child(_button(tr("TUNE_COPY"), copy_values))
	buttons.add_child(_button(tr("TUNE_RESET"), reset_values))
	buttons.add_child(_button(tr("TUNE_CLOSE"), close))


func _build_rows(rows: VBoxContainer) -> void:
	var current_group: StringName = &""
	for index: int in _params.size():
		var param: TuningParam = _params[index]
		if param.group_key != current_group:
			current_group = param.group_key
			var heading: Label = Label.new()
			heading.text = tr(param.group_key)
			heading.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
			rows.add_child(heading)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label: Label = Label.new()
		name_label.text = tr(param.label_key)
		name_label.custom_minimum_size = Vector2(230.0, 0.0)
		row.add_child(name_label)
		var slider: HSlider = HSlider.new()
		slider.min_value = param.min_value
		slider.max_value = param.max_value
		slider.step = param.step
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size = Vector2(180.0, 28.0)
		slider.value_changed.connect(_on_slider_changed.bind(index))
		row.add_child(slider)
		var value_label: Label = Label.new()
		value_label.custom_minimum_size = Vector2(90.0, 0.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		rows.add_child(row)
		_sliders.append(slider)
		_value_labels.append(value_label)


func _button(label: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.pressed.connect(action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
