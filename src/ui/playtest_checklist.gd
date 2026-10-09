class_name PlaytestChecklist
extends ListScreen
## The title menu's "what still needs playtesting" page, read from
## docs/PLAYTEST.md (see PlaytestDoc). Tick items as you test them; ticks are
## saved on this PC. "Copy what's left" puts the open items on the clipboard to
## paste back to Claude.

const DONE_COLOR: Color = Color(0.45, 0.62, 0.45)
const COPIED_SECONDS: float = 3.0

var doc: PlaytestDoc = null
var _hide_done: CheckBox
var _copy_button: Button
var _progress_label: Label
var _copied_left: float = 0.0


func _ready() -> void:
	_progress_label = label("", 9, DIM_COLOR)
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_progress_label)
	footer.move_child(_progress_label, 0)
	_hide_done = CheckBox.new()
	_hide_done.text = "Hide done"
	_hide_done.toggled.connect(func(_on: bool) -> void: _rebuild())
	footer.add_child(_hide_done)
	footer.move_child(_hide_done, 1)
	_copy_button = Button.new()
	_copy_button.text = "Copy what's left"
	_copy_button.pressed.connect(_copy_remaining)
	footer.add_child(_copy_button)
	footer.move_child(_copy_button, 2)


func open() -> void:
	if doc == null:
		doc = PlaytestDoc.load_default()
	_rebuild()
	super()


func _process(delta: float) -> void:
	if _copied_left > 0.0:
		_copied_left -= delta
		if _copied_left <= 0.0:
			_copy_button.text = "Copy what's left"


func _rebuild() -> void:
	clear_list()
	var progress := doc.progress()
	set_title("Playtest Checklist")
	_progress_label.text = "%d of %d checked" % [progress.x, progress.y]
	if progress.y == 0:
		add_heading("No checklist found (docs/PLAYTEST.md is missing from this build).")
		return
	for section: Dictionary in doc.sections:
		var items: Array = section["items"]
		var shown := items.filter(func(item: Dictionary) -> bool: return not (_hide_done.button_pressed and doc.is_done(item)))
		if shown.is_empty():
			continue
		var done := items.filter(func(item: Dictionary) -> bool: return doc.is_done(item)).size()
		add_heading("%s   (%d/%d)" % [section["title"], done, items.size()])
		for item: Dictionary in shown:
			_add_item(item)


## A row with a tick box and the wrapped question. Confirm / click toggles it.
func _add_item(item: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var box := CheckBox.new()
	box.focus_mode = Control.FOCUS_NONE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.button_pressed = doc.is_done(item)
	box.disabled = item["done_in_doc"]
	line.add_child(box)
	var text := label(String(item["text"]), 9, DONE_COLOR if doc.is_done(item) else TEXT_COLOR, true)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(text)
	var row := add_row(line)
	var toggle := func() -> void:
		if item["done_in_doc"]:
			return
		var now := not doc.is_done(item)
		doc.set_ticked(item, now)
		box.button_pressed = now
		text.add_theme_color_override("font_color", DONE_COLOR if now else TEXT_COLOR)
		var progress := doc.progress()
		_progress_label.text = "%d of %d checked" % [progress.x, progress.y]
	row.gui_input.connect(func(event: InputEvent) -> void:
		var mouse := event as InputEventMouseButton
		var clicked: bool = mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
		if clicked or event.is_action_pressed("ui_accept"):
			toggle.call()
			row.accept_event())


func _copy_remaining() -> void:
	DisplayServer.clipboard_set(doc.remaining_text())
	_copy_button.text = "Copied!"
	_copied_left = COPIED_SECONDS
