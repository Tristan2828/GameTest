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

var _offers: Array[int] = []
static var _screenshot_taken: bool = false


func _ready() -> void:
	var buttons := _cards.get_children()
	for i: int in buttons.size():
		(buttons[i] as Button).pressed.connect(_on_card_pressed.bind(i))
	_reroll_button.pressed.connect(func() -> void: reroll_pressed.emit())
	_ready_button.pressed.connect(func() -> void: ready_pressed.emit())
	_reroll_button.text = "Reroll (%d coins)" % Relics.REROLL_PRICE


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
func refresh(coins: int, owned: Array[int], is_ready: bool, status: String) -> void:
	_coins_label.text = "Coins: %d" % coins
	var buttons := _cards.get_children()
	for i: int in mini(buttons.size(), _offers.size()):
		var button := buttons[i] as Button
		var relic := Relics.get_relic(_offers[i])
		var owned_it := owned.has(_offers[i])
		var price_text := "OWNED" if owned_it else "%d coins" % relic.price
		button.text = "%s\n%s\n\n%s" % [relic.title, relic.description, price_text]
		button.disabled = is_ready or owned_it or coins < relic.price
	_reroll_button.disabled = is_ready or coins < Relics.REROLL_PRICE
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
