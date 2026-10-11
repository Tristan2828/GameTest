class_name JoinDialog
extends PanelContainer
## The title menu's "Join Game" dialog: paste the invite your host sent you
## (e.g. 203.0.113.5:7777) and press Join. "Paste" fills the box from the
## clipboard, so a gamepad works too. Esc / B or Back closes it. Built in code.

## Join was pressed with a usable invite.
signal join_requested(address: String, port: int)
signal closed

const HINT_COLOR: Color = Color(0.75, 0.68, 0.85)
const ERROR_COLOR: Color = Color(0.95, 0.75, 0.55)

var _address_edit: LineEdit
var _message: Label
var _join_button: Button
var _paste_button: Button
var _back_button: Button


func _init() -> void:
	custom_minimum_size = Vector2(280, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var title := Label.new()
	title.text = "Join a game"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 260
	column.add_child(_message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "Paste invite (IP:port)"
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address_edit.text_submitted.connect(func(_text: String) -> void: _try_join())
	row.add_child(_address_edit)
	_paste_button = Button.new()
	_paste_button.text = "Paste"
	_paste_button.tooltip_text = "Paste the invite from the clipboard"
	_paste_button.pressed.connect(_paste)
	row.add_child(_paste_button)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	column.add_child(buttons)
	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_button.pressed.connect(close)
	buttons.add_child(_back_button)
	_join_button = Button.new()
	_join_button.text = "Join"
	_join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_button.pressed.connect(_try_join)
	buttons.add_child(_join_button)
	hide()


## Shows the dialog. An invite already on the clipboard is filled in for you.
func open() -> void:
	_show_hint()
	if _address_edit.text.strip_edges().is_empty() and _looks_like_invite(DisplayServer.clipboard_get()):
		_address_edit.text = DisplayServer.clipboard_get().strip_edges()
	show()
	if _address_edit.text.strip_edges().is_empty():
		_paste_button.grab_focus()
	else:
		_join_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _paste() -> void:
	var text := DisplayServer.clipboard_get().strip_edges()
	if text.is_empty():
		_show_error("The clipboard is empty. Copy the invite your host sent you first.")
		return
	_address_edit.text = text
	_show_hint()
	_join_button.grab_focus()


func _try_join() -> void:
	var invite: Dictionary = Net.parse_invite(_address_edit.text, Net.DEFAULT_PORT)
	var address: String = invite["address"]
	if address.is_empty():
		_show_error("That doesn't look like an invite. It looks like 203.0.113.5:7777.")
		_address_edit.grab_focus()
		return
	hide()
	join_requested.emit(address, invite["port"])


func _show_hint() -> void:
	_message.text = "Paste the invite your host sent you (looks like 203.0.113.5:7777)."
	_message.add_theme_color_override("font_color", HINT_COLOR)


func _show_error(text: String) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", ERROR_COLOR)


## True for text like "203.0.113.5:7777" or "my.host.net" (so a random
## clipboard isn't pasted into the box by itself).
static func _looks_like_invite(text: String) -> bool:
	var trimmed := text.strip_edges()
	if trimmed.length() > 64 or not trimmed.contains("."):
		return false
	var pattern := RegEx.create_from_string("^[A-Za-z0-9.-]+(:[0-9]{1,5})?$")
	return pattern.search(trimmed) != null
