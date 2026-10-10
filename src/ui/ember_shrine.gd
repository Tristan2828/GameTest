class_name EmberShrine
extends ListScreen
## Title menu page: spend Embers (earned at the end of every run) on small
## permanent boosts (see Embers). Refunds are free, and your boosts can be
## switched off for a pure run. Saved on every change.

const EMBER_COLOR: Color = Color(0.98, 0.6, 0.25)
const RANK_ON_COLOR: Color = Color(0.98, 0.6, 0.25)
const RANK_OFF_COLOR: Color = Color(0.25, 0.2, 0.3)

var embers: Embers = Embers.new()
var _toggle_button: Button
var _refund_button: Button
## Buy buttons by Boost, so focus can stay on the one just pressed.
var _buy_buttons: Array[Button] = []


func _ready() -> void:
	set_title("Ember Shrine")
	_toggle_button = Button.new()
	_toggle_button.pressed.connect(func() -> void:
		embers.enabled = not embers.enabled
		_changed(_toggle_button))
	footer.add_child(_toggle_button)
	footer.move_child(_toggle_button, 0)
	_refund_button = Button.new()
	_refund_button.text = "Refund all"
	_refund_button.tooltip_text = "Get every Ember you spent back (free)"
	_refund_button.pressed.connect(func() -> void:
		embers.refund_all()
		_changed(_refund_button))
	footer.add_child(_refund_button)
	footer.move_child(_refund_button, 1)


func open() -> void:
	embers = Embers.load_saved()
	_rebuild()
	super()


func _changed(keep_focus: Button) -> void:
	embers.save()
	Sfx.play(&"ui")
	_rebuild()
	if keep_focus != null and keep_focus.is_inside_tree():
		keep_focus.grab_focus()


func _rebuild() -> void:
	clear_list()
	_buy_buttons.clear()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(SpriteIcon.new("ember", Vector2(20, 24)))
	top.add_child(label("%d Embers" % embers.balance, 18, EMBER_COLOR))
	top.add_child(label("   earned in total: %d" % embers.total_earned, 9, DIM_COLOR))
	list.add_child(top)
	add_heading("Every run earns Embers: %d per boss, %d for a victory, 1 per %d kills (max %d), times the difficulty." % [
		Embers.PER_BOSS, Embers.PER_VICTORY, Embers.KILLS_PER_EMBER, Embers.MAX_KILL_EMBERS])
	if not embers.enabled:
		add_heading("Your boosts are OFF: you play without them until you switch them back on.")
	for boost: int in Embers.BOOSTS.size():
		_add_boost(boost)
	_toggle_button.text = "My boosts: %s" % ("On" if embers.enabled else "Off")
	_refund_button.disabled = embers.spent() == 0


func _add_boost(boost: int) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.add_child(SpriteIcon.new(Embers.boost_icon(boost), Vector2(28, 28)))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	text.add_child(label(Embers.boost_name(boost), 9, NAME_COLOR))
	text.add_child(label("%s per rank" % Embers.boost_text(boost), 9, TEXT_COLOR, true))
	line.add_child(text)
	line.add_child(_rank_pips(embers.ranks[boost]))
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(90, 0)
	var price := embers.next_price(boost)
	buy.text = "Maxed" if price < 0 else "Buy: %d" % price
	buy.disabled = not embers.can_buy(boost)
	buy.focus_mode = Control.FOCUS_ALL
	buy.pressed.connect(func() -> void:
		if embers.buy(boost):
			_changed(null)
			# Stay on this row (or the next buyable one if this one is now maxed).
			var target := _buy_buttons[boost]
			if target.disabled:
				target = _first_enabled_buy()
			(target if target != null else back_button).grab_focus())
	_buy_buttons.append(buy)
	line.add_child(buy)
	add_row(line, false)


## "■■□" style rank pips.
func _rank_pips(rank: int) -> HBoxContainer:
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 2)
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	for i: int in Embers.MAX_RANK:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(6, 6)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = RANK_ON_COLOR if i < rank else RANK_OFF_COLOR
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	return pips


func _first_enabled_buy() -> Button:
	for button: Button in _buy_buttons:
		if not button.disabled:
			return button
	return null
