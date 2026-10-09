class_name ShopPanel
extends Control
## The between-stages shop: relic cards with prices, Reroll and Ready.
## Works with mouse and gamepad (focus moves between buttons; A confirms).

signal buy_pressed(relic_id: int)
signal reroll_pressed
signal ready_pressed

@onready var _coins_label: Label = %ShopCoins
@onready var _cards: HBoxContainer = %ShopCards
@onready var _reroll_button: Button = %RerollButton
@onready var _ready_button: Button = %ReadyButton
@onready var _status: Label = %ShopStatus

const PRICE_COLOR: Color = Color(1.0, 0.85, 0.4)
const TOO_EXPENSIVE_COLOR: Color = Color(1.0, 0.5, 0.45)
const OWNED_COLOR: Color = Color(0.55, 0.9, 0.6)

var _offers: Array[int] = []
## The relic's icon at the top of each card.
var _icons: Array[SpriteIcon] = []
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


func open(offers: Array[int]) -> void:
	_offers = offers
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		button.visible = i < offers.size()
	show()
	var first: Button = buttons[0] if not offers.is_empty() else _ready_button
	first.grab_focus()
	if not _screenshot_taken and not LaunchOptions.screenshot_dir.is_empty():
		_screenshot_taken = true
		await get_tree().create_timer(0.2).timeout
		Main.save_screenshot(get_tree(), "shop.png")


## Updates prices/affordability and the status line (called every frame).
func refresh(coins: int, owned: Array[int], is_ready: bool, status: String, reroll_price: int) -> void:
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
