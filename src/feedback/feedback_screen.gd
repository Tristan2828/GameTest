class_name FeedbackScreen
extends CanvasLayer
## "Send feedback": your name, the kind (suggestion / bug / praise), a message,
## and optionally a screenshot of the game. Sent to the team's Discord channel
## with game info (version, stage, time, hero...) added automatically.
## Opened from the title menu and the pause menu. Built in code.

signal closed

## Seconds between two sends (keeps an accidental double-press from posting twice).
const SEND_COOLDOWN: float = 20.0
const DIM_COLOR: Color = Color(0.6, 0.57, 0.68)
const OK_COLOR: Color = Color(0.55, 0.9, 0.45)
const ERROR_COLOR: Color = Color(0.95, 0.5, 0.45)

var _name_edit: LineEdit
var _kind_button: Button
var _message_edit: TextEdit
var _screenshot_check: CheckBox
var _thumbnail: TextureRect
var _context_label: Label
var _status_label: Label
var _send_button: Button
var _back_button: Button
var _http: HTTPRequest
var _kind: int = 0
var _screenshot: Image = null
var _context: String = ""
var _sending: bool = false
var _next_send_at: float = 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS  # Works while solo play is paused.
	_build()
	hide()


## `screenshot` may be null (title menu); `context` is the game info line(s).
func open(screenshot: Image, context: String) -> void:
	_screenshot = screenshot
	_context = context
	_name_edit.text = Settings.player_name
	_screenshot_check.disabled = screenshot == null
	_screenshot_check.button_pressed = screenshot != null
	_screenshot_check.text = "Include screenshot" if screenshot != null else "Include screenshot (only during a game)"
	_thumbnail.texture = ImageTexture.create_from_image(screenshot) if screenshot != null else null
	_thumbnail.visible = screenshot != null
	_context_label.text = "Sent with: " + context.replace("\n", "  |  ")
	if FeedbackReport.webhook_url().is_empty():
		_set_status("Sending isn't set up in this build: Send copies your message to the clipboard instead.", DIM_COLOR)
	else:
		_set_status("", DIM_COLOR)
	show()
	(_message_edit if not _name_edit.text.is_empty() else _name_edit).grab_focus()


func close() -> void:
	Settings.player_name = _name_edit.text.strip_edges().left(FeedbackReport.MAX_NAME)
	Settings.save()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _send() -> void:
	var message := _message_edit.text.strip_edges()
	if message.is_empty():
		_set_status("Write something first.", ERROR_COLOR)
		_message_edit.grab_focus()
		return
	if _sending:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_send_at:
		_set_status("Please wait %d s before sending again." % ceili(_next_send_at - now), ERROR_COLOR)
		return
	var text := FeedbackReport.message_text(_kind, _name_edit.text, message, _context)
	var url := FeedbackReport.webhook_url()
	if url.is_empty():
		DisplayServer.clipboard_set(text)
		_set_status("Copied to the clipboard: paste it in Discord #feedback.", OK_COLOR)
		return
	var png := FeedbackReport.screenshot_png(_screenshot) if _screenshot_check.button_pressed else PackedByteArray()
	var body := FeedbackReport.multipart_body(FeedbackReport.payload_json(text, not png.is_empty()), png)
	var error := _http.request_raw(url + "?wait=true", [FeedbackReport.content_type_header()], HTTPClient.METHOD_POST, body)
	if error != OK:
		_set_status("Couldn't send (error %d). Check your internet connection." % error, ERROR_COLOR)
		return
	_sending = true
	_send_button.disabled = true
	_set_status("Sending...", DIM_COLOR)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_sending = false
	_send_button.disabled = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_next_send_at = Time.get_ticks_msec() / 1000.0 + SEND_COOLDOWN
		_message_edit.text = ""
		_set_status("Sent! Thanks for the feedback.", OK_COLOR)
		print("Feedback sent")
	elif response_code == 429:
		_set_status("Too many messages right now. Try again in a minute.", ERROR_COLOR)
	else:
		_set_status("Couldn't send (result %d, code %d). Try again later." % [result, response_code], ERROR_COLOR)
		push_warning("Feedback failed: result %d, code %d" % [result, response_code])


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _cycle_kind(step: int) -> void:
	_kind = posmod(_kind + step, FeedbackReport.KINDS.size())
	_kind_button.text = "<  %s  >" % FeedbackReport.KINDS[_kind]


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	var title := _label("Send feedback", 18, Color(0.85, 0.75, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_label("Goes to the team's Discord. Ideas, bugs, anything!", 9, DIM_COLOR))

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = FeedbackReport.MAX_NAME
	_name_edit.custom_minimum_size.x = 200
	column.add_child(_row("Your name", _name_edit))

	_kind_button = Button.new()
	_kind_button.pressed.connect(_cycle_kind.bind(1))
	_kind_button.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_cycle_kind(-1 if event.is_action_pressed("ui_left") else 1)
			_kind_button.accept_event())
	column.add_child(_row("Kind", _kind_button))
	_cycle_kind(0)

	_message_edit = TextEdit.new()
	_message_edit.placeholder_text = "Your suggestion, bug or idea..."
	_message_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_message_edit.custom_minimum_size = Vector2(360, 80)
	_message_edit.text_changed.connect(func() -> void:
		if _message_edit.text.length() > FeedbackReport.MAX_MESSAGE:
			_message_edit.text = _message_edit.text.left(FeedbackReport.MAX_MESSAGE)
			_message_edit.set_caret_column(_message_edit.get_line(_message_edit.get_caret_line()).length()))
	column.add_child(_message_edit)

	var shot_row := HBoxContainer.new()
	shot_row.add_theme_constant_override("separation", 8)
	_screenshot_check = CheckBox.new()
	_screenshot_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screenshot_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shot_row.add_child(_screenshot_check)
	_thumbnail = TextureRect.new()
	_thumbnail.custom_minimum_size = Vector2(96, 54)
	_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shot_row.add_child(_thumbnail)
	_screenshot_check.toggled.connect(func(on: bool) -> void: _thumbnail.modulate.a = 1.0 if on else 0.3)
	column.add_child(shot_row)

	_context_label = _label("", 9, DIM_COLOR)
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_label.custom_minimum_size.x = 360
	column.add_child(_context_label)
	_status_label = _label("", 9, DIM_COLOR)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.x = 360
	column.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	_send_button = Button.new()
	_send_button.text = "Send"
	_send_button.custom_minimum_size.x = 100
	_send_button.pressed.connect(_send)
	buttons.add_child(_send_button)
	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size.x = 100
	_back_button.pressed.connect(close)
	buttons.add_child(_back_button)
	column.add_child(buttons)

	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)


func _row(title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := _label(title, 9, Color(0.9, 0.88, 0.95))
	name_label.custom_minimum_size.x = 70
	row.add_child(name_label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
