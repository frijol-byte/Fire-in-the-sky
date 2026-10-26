class_name WaveMenu
extends CanvasLayer
## The combat test arena's debug menu (M2-T7), on F7: pick a wave of pirates to fight (1, 2 or 3),
## restart the wave, skip to the next one, send the pirates away, and turn the kill slow-motion tick
## on or off. The game is paused while it is open. Usable with a gamepad (the first button has
## focus); the arena also runs the waves by itself, so a gamepad-only playtest never needs it.
## Esc / Start closes it.

signal wave_chosen(index: int)
signal restart_requested
signal next_requested
signal clear_requested
signal slowmo_changed(enabled: bool)

const MENU_KEY: Key = KEY_F7

var _open: bool = false
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _wave_buttons: Array[Button] = []

@onready var _panel: Control = $Panel
@onready var _waves: VBoxContainer = $Panel/Center/Column/Waves
@onready var _restart: Button = $Panel/Center/Column/Restart
@onready var _next: Button = $Panel/Center/Column/Next
@onready var _clear: Button = $Panel/Center/Column/Clear
@onready var _slowmo: CheckButton = $Panel/Center/Column/Slowmo
@onready var _close: Button = $Panel/Center/Column/Close


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_restart.pressed.connect(func() -> void: _act(restart_requested))
	_next.pressed.connect(func() -> void: _act(next_requested))
	_clear.pressed.connect(func() -> void: _act(clear_requested))
	_slowmo.toggled.connect(func(enabled: bool) -> void: slowmo_changed.emit(enabled))
	_close.pressed.connect(close)


func _exit_tree() -> void:
	if _open:
		close()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == MENU_KEY:
		toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("pause") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()


## Makes one button per wave; `sizes[i]` is how many pirates wave `i` has.
func setup(sizes: PackedInt32Array, slowmo_on: bool) -> void:
	for button: Button in _wave_buttons:
		_waves.remove_child(button)
		button.queue_free()
	_wave_buttons.clear()
	for index: int in sizes.size():
		var button: Button = Button.new()
		button.text = tr("WAVEMENU_WAVE") % [index + 1, sizes[index]]
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(_choose.bind(index))
		_waves.add_child(button)
		_wave_buttons.append(button)
	_slowmo.set_pressed_no_signal(slowmo_on)


func is_open() -> bool:
	return _open


func wave_button_count() -> int:
	return _wave_buttons.size()


## Presses wave button `index` (for tests; players press the button).
func choose_wave(index: int) -> void:
	_choose(index)


func toggle() -> void:
	if _open:
		close()
	elif not get_tree().paused:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	_saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.visible = true
	get_tree().paused = true
	if _wave_buttons.is_empty():
		_restart.grab_focus()
	else:
		_wave_buttons[0].grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = _saved_mouse_mode


func _choose(index: int) -> void:
	close()
	wave_chosen.emit(index)


func _act(action: Signal) -> void:
	close()
	action.emit()
