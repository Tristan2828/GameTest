class_name ShopPanel
extends Control
## The between-stages shop: relic cards with prices, a row of quests for the
## next stage (pick one, free), Reroll and Ready.
## Works with mouse and gamepad (focus moves between buttons; A confirms).

signal buy_pressed(relic_id: int)
signal reroll_pressed
signal ready_pressed
signal quest_pressed(quest_id: int)

@onready var _coins_label: Label = %ShopCoins
@onready var _cards: HBoxContainer = %ShopCards
@onready var _reroll_button: Button = %RerollButton
@onready var _ready_button: Button = %ReadyButton
@onready var _status: Label = %ShopStatus

const PRICE_COLOR: Color = Color(1.0, 0.85, 0.4)
const TOO_EXPENSIVE_COLOR: Color = Color(1.0, 0.5, 0.45)
const OWNED_COLOR: Color = Color(0.55, 0.9, 0.6)
const QUEST_CARD_SIZE: Vector2 = Vector2(190, 50)
const QUEST_CHOSEN_COLOR: Color = Color(1.0, 0.85, 0.4)
const QUEST_OTHER_COLOR: Color = Color(0.7, 0.68, 0.78)

var _offers: Array[int] = []
## The relic's icon at the top of each card.
var _icons: Array[SpriteIcon] = []
var _quest_offers: Array[int] = []
var _quest_buttons: Array[Button] = []
var _quest_icons: Array[SpriteIcon] = []
var _quest_lines: Array[VBoxContainer] = []
var _quest_title: Label = null
static var _screenshot_taken: bool = false


func _ready() -> void:
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		(buttons[i] as Button).pressed.connect(_on_card_pressed.bind(i))
		var icon := SpriteIcon.new("", Vector2(20, 20))
		var lines := buttons[i].get_node("Lines")
		lines.add_child(icon)
		lines.move_child(icon, 0)  # Above the title.
		_icons.append(icon)
	_reroll_button.pressed.connect(func() -> void: reroll_pressed.emit())
	_ready_button.pressed.connect(func() -> void: ready_pressed.emit())
	_build_quest_row()


## "Quest for the next stage" and three quest cards, above Reroll / Ready.
func _build_quest_row() -> void:
	var box := _cards.get_parent() as VBoxContainer
	box.offset_top = -152.0
	box.offset_bottom = 152.0
	_quest_title = Label.new()
	_quest_title.text = "Pick a quest for the next stage (free):"
	_quest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_title.add_theme_font_size_override("font_size", 9)
	_quest_title.add_theme_color_override("font_color", QUEST_CHOSEN_COLOR)
	box.add_child(_quest_title)
	box.move_child(_quest_title, _cards.get_index() + 1)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	box.move_child(row, _quest_title.get_index() + 1)
	for i: int in Quests.OFFERS_PER_SHOP:
		var button := Button.new()
		button.custom_minimum_size = QUEST_CARD_SIZE
		button.pressed.connect(_on_quest_pressed.bind(i))
		var line := HBoxContainer.new()
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 5)
		var icon := SpriteIcon.new("", Vector2(20, 20))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(icon)
		var lines := VBoxContainer.new()
		lines.name = "Lines"
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_theme_constant_override("separation", 1)
		for part: String in ["Title", "Description", "Reward"]:
			var label := Label.new()
			label.name = part
			label.add_theme_font_size_override("font_size", 9)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if part == "Description" else TextServer.AUTOWRAP_OFF
			lines.add_child(label)
		line.add_child(lines)
		button.add_child(line)
		row.add_child(button)
		_quest_buttons.append(button)
		_quest_icons.append(icon)
		_quest_lines.append(lines)


## `first_time` is false when only the relics changed (a reroll): focus stays put.
func open(offers: Array[int], quests: Array[int] = [], first_time: bool = true) -> void:
	_offers = offers
	_quest_offers = quests
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.visible = i < offers.size()
	for i: int in _quest_buttons.size():
		_quest_buttons[i].visible = i < quests.size()
	_quest_title.visible = not quests.is_empty()
	show()
	if not first_time:
		return
	var first: Button = buttons[0] if not offers.is_empty() else _ready_button
	first.grab_focus()
	if not _screenshot_taken and not LaunchOptions.screenshot_dir.is_empty():
		_screenshot_taken = true
		await get_tree().create_timer(0.2).timeout
		Main.save_screenshot(get_tree(), "shop.png")


## Updates prices/affordability and the status line (called every frame).
func refresh(coins: int, owned: Array[int], is_ready: bool, status: String, reroll_price: int, chosen_quest: int = -1) -> void:
	_refresh_quests(is_ready, chosen_quest)
	_coins_label.text = "Coins: %d" % coins
	var buttons := _cards.get_children()
	for i: int in mini(buttons.size(), _offers.size()):
		var button := buttons[i] as Button
		var relic := Relics.get_relic(_offers[i])
		var owned_it := owned.has(_offers[i])
		var affordable := coins >= relic.price
		(button.get_node("Lines/Title") as Label).text = relic.title
		if _icons[i].sprite != relic.icon:
			_icons[i].sprite = relic.icon
			_icons[i].queue_redraw()
		(button.get_node("Lines/Description") as Label).text = relic.description
		var price := button.get_node("Lines/Price") as Label
		if owned_it:
			price.text = "Owned"
			price.modulate = OWNED_COLOR
		elif affordable:
			price.text = "%d coins" % relic.price
			price.modulate = PRICE_COLOR
		else:
			price.text = "%d coins (need %d more)" % [relic.price, relic.price - coins]
			price.modulate = TOO_EXPENSIVE_COLOR
		button.disabled = is_ready or owned_it or not affordable
	_reroll_button.text = "Reroll (%d coins)" % reroll_price
	_reroll_button.disabled = is_ready or coins < reroll_price
	_ready_button.disabled = is_ready
	_ready_button.text = "Ready!" if is_ready else "Ready"
	_status.text = status
	# Keep gamepad focus on something usable after a button gets disabled.
	var focused := get_viewport().gui_get_focus_owner() as Button
	if (focused == null or focused.disabled) and not is_ready:
		_ready_button.grab_focus()


func _on_card_pressed(index: int) -> void:
	if index < _offers.size():
		buy_pressed.emit(_offers[index])


func _on_quest_pressed(index: int) -> void:
	if index < _quest_offers.size():
		quest_pressed.emit(_quest_offers[index])


## The picked quest is gold and says so; the others are dimmed once one is picked.
func _refresh_quests(is_ready: bool, chosen_quest: int) -> void:
	for i: int in mini(_quest_buttons.size(), _quest_offers.size()):
		var quest_id := _quest_offers[i]
		var button := _quest_buttons[i]
		var lines := _quest_lines[i]
		var chosen := quest_id == chosen_quest
		(lines.get_node("Title") as Label).text = ("> %s" if chosen else "%s") % Quests.TITLES[quest_id]
		(lines.get_node("Title") as Label).modulate = QUEST_CHOSEN_COLOR if chosen else Color.WHITE
		(lines.get_node("Description") as Label).text = Quests.description(quest_id)
		var reward := lines.get_node("Reward") as Label
		reward.text = "Chosen!  " + Quests.reward_text(quest_id).replace("Reward: ", "") if chosen else Quests.reward_text(quest_id)
		reward.modulate = QUEST_CHOSEN_COLOR if chosen else PRICE_COLOR
		button.modulate = Color.WHITE if chosen or chosen_quest < 0 else QUEST_OTHER_COLOR
		button.disabled = is_ready
		if _quest_icons[i].sprite != Quests.ICONS[quest_id]:
			_quest_icons[i].sprite = Quests.ICONS[quest_id]
			_quest_icons[i].queue_redraw()
	if _quest_title != null:
		_quest_title.text = "Quest for the next stage: %s" % Quests.TITLES[chosen_quest] if chosen_quest >= 0 \
			else "Pick a quest for the next stage (free; random if you don't):"
