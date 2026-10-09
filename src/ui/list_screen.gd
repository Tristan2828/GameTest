class_name ListScreen
extends PanelContainer
## A full-screen menu page: a title, an optional row of tabs, a scrolling list of
## rows and a footer with a Back button. Built in code; the Compendium and the
## Playtest Checklist extend it. Works with mouse, keyboard and gamepad: rows take
## focus (the list scrolls to follow it) and Esc / B goes back.

signal closed

const TITLE_COLOR: Color = Color(0.95, 0.78, 0.4)
const NAME_COLOR: Color = Color(0.55, 0.85, 1.0)
const TEXT_COLOR: Color = Color(0.9, 0.88, 0.95)
const DIM_COLOR: Color = Color(0.6, 0.57, 0.68)
const HEADING_COLOR: Color = Color(0.85, 0.75, 1.0)
const ROW_COLOR: Color = Color(0.1, 0.08, 0.14, 1.0)
const ROW_BORDER: Color = Color(0.24, 0.19, 0.32)
const ROW_FOCUS_BORDER: Color = Color(0.95, 0.78, 0.4)
const TAB_SELECTED_COLOR: Color = Color(0.95, 0.78, 0.4)

var _title_label: Label
var _tabs_row: HBoxContainer
var _scroll: ScrollContainer
## Rows go in here (cleared when the tab changes).
var list: VBoxContainer
## Extra footer controls go left of the Back button.
var footer: HBoxContainer
var back_button: Button
var _tab_buttons: Array[Button] = []
var _row_style: StyleBoxFlat
var _row_focus_style: StyleBoxFlat


const SCREEN_MARGIN: float = 12.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = SCREEN_MARGIN
	offset_top = SCREEN_MARGIN
	offset_right = -SCREEN_MARGIN
	offset_bottom = -SCREEN_MARGIN
	add_theme_stylebox_override("panel", _box(Color(0.06, 0.04, 0.09, 0.98), Color(0.42, 0.33, 0.55), 8))
	_row_style = _box(ROW_COLOR, ROW_BORDER, 4)
	_row_focus_style = _box(ROW_COLOR.lightened(0.06), ROW_FOCUS_BORDER, 4)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	add_child(column)
	_title_label = label("", 18, TITLE_COLOR)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)
	_tabs_row = HBoxContainer.new()
	_tabs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs_row.add_theme_constant_override("separation", 3)
	_tabs_row.visible = false
	column.add_child(_tabs_row)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	_scroll.add_child(list)
	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 6)
	column.add_child(footer)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(80, 0)
	back_button.pressed.connect(close)
	footer.add_child(back_button)
	hide()


func set_title(text: String) -> void:
	_title_label.text = text


## Adds a tab button; pressing it (or focusing it) calls `on_select`.
func add_tab(title: String, on_select: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(func() -> void: _select_tab(button, on_select))
	button.focus_entered.connect(func() -> void: _select_tab(button, on_select))
	_tabs_row.add_child(button)
	_tabs_row.visible = true
	_tab_buttons.append(button)
	return button


func _select_tab(button: Button, on_select: Callable) -> void:
	for tab: Button in _tab_buttons:
		var selected := tab == button
		if selected:
			tab.add_theme_color_override("font_color", TAB_SELECTED_COLOR)
			tab.add_theme_color_override("font_focus_color", TAB_SELECTED_COLOR)
		else:
			tab.remove_theme_color_override("font_color")
			tab.remove_theme_color_override("font_focus_color")
	on_select.call()
	_scroll.scroll_vertical = 0


func open() -> void:
	show()
	if not _tab_buttons.is_empty():
		_tab_buttons[0].grab_focus()
		_tab_buttons[0].pressed.emit()
	else:
		var first := first_focusable_row()
		(first if first != null else back_button).grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func clear_list() -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()


## A bordered row that can take focus (gold border when focused), so gamepad
## and keyboard users can scroll through the list.
func add_row(content: Control) -> PanelContainer:
	var row := PanelContainer.new()
	row.focus_mode = Control.FOCUS_ALL
	row.add_theme_stylebox_override("panel", _row_style)
	row.focus_entered.connect(func() -> void: row.add_theme_stylebox_override("panel", _row_focus_style))
	row.focus_exited.connect(func() -> void: row.add_theme_stylebox_override("panel", _row_style))
	row.add_child(content)
	list.add_child(row)
	return row


func add_heading(text: String) -> Label:
	var heading := label(text, 9, HEADING_COLOR)
	list.add_child(heading)
	return heading


func first_focusable_row() -> Control:
	for child: Node in list.get_children():
		var control := child as Control
		if control != null and control.focus_mode != Control.FOCUS_NONE and control.visible:
			return control
	return null


## A 9px label (wrapping when `wrap` is set, so long text fits the row).
static func label(text: String, font_size: int = 9, color: Color = TEXT_COLOR, wrap: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result


static func _box(background: Color, border: Color, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(margin)
	return box
