class_name RunSummaryPanel
extends Control
## The end-of-run screen (Run over / Victory): headline, run totals, and one card
## per player with their numbers, build and co-op awards. Built in code because
## the number of player cards changes. Numbers count up when it opens.

const DEFEAT_COLOR: Color = Color(0.95, 0.4, 0.38)
const VICTORY_COLOR: Color = Color(0.95, 0.85, 0.55)
const LABEL_COLOR: Color = Color(0.6, 0.57, 0.68)
const VALUE_COLOR: Color = Color(0.95, 0.93, 1.0)
const AWARD_COLOR: Color = Color(0.95, 0.78, 0.4)
const DIVIDER_COLOR: Color = Color(0.3, 0.24, 0.4)
const CARD_BG: Color = Color(0.1, 0.08, 0.14, 1.0)
const COUNT_UP_SECONDS: float = 1.2
## Card width by player count (index = players - 1); fits 640 px wide.
const CARD_WIDTHS: Array[int] = [250, 210, 170, 138]

## Labels that count up: label -> [final value, is_time]
var _counters: Dictionary[Label, Array] = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds and shows the screen. `players` are the Player nodes still in the game.
func open(stats: RunStats, players: Array[Player], stage_title: String, stage_count: int, hint: String) -> void:
	for child: Node in get_children():
		child.queue_free()
	_counters.clear()
	var accent := VICTORY_COLOR if stats.victory else DEFEAT_COLOR

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color(0.06, 0.04, 0.09, 0.97), accent.darkened(0.35), 10))
	center.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	frame.add_child(column)

	column.add_child(_label("VICTORY" if stats.victory else "RUN OVER", 27, accent, true))
	column.add_child(_label(_headline(stats, stage_title, stage_count), 9, LABEL_COLOR, true))
	column.add_child(_divider())
	column.add_child(_summary_row(stats, stage_count))
	column.add_child(_divider())

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 6)
	column.add_child(cards)
	var width := CARD_WIDTHS[clampi(players.size(), 1, CARD_WIDTHS.size()) - 1]
	for player: Player in players:
		cards.add_child(_player_card(player, stats, width, players.size()))

	var hint_label := _label(hint, 9, LABEL_COLOR, true)
	column.add_child(hint_label)
	show()
	_animate_in(hint_label)


func _headline(stats: RunStats, stage_title: String, stage_count: int) -> String:
	if stats.victory:
		return "All %d stages cleansed. The dark recedes... for now." % stage_count
	var where := "Stage %d: %s" % [stats.stage_reached, stage_title]
	if stats.fell_to.is_empty():
		return "Overrun by the horde in %s" % where
	var foe := stats.fell_to
	if foe.begins_with("The "):
		foe = "the " + foe.substr(4)  # "Fell to the Mire Hag"
	return "Fell to %s in %s" % [foe, where]


func _summary_row(stats: RunStats, stage_count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.add_child(_chip("TIME", stats.run_seconds, true))
	row.add_child(_chip_text("STAGE", "%d/%d" % [stats.stage_reached, stage_count]))
	row.add_child(_chip("LEVEL", stats.team_level))
	row.add_child(_chip("KILLS", stats.total(RunStats.Stat.KILLS)))
	row.add_child(_chip_text("BOSSES", "%d/%d" % [stats.bosses_defeated, stage_count]))
	return row


func _chip(title: String, value: float, is_time: bool = false) -> VBoxContainer:
	var chip := _chip_text(title, "")
	_count_up(chip.get_child(0) as Label, value, is_time)
	return chip


func _chip_text(title: String, value: String) -> VBoxContainer:
	var chip := VBoxContainer.new()
	chip.add_theme_constant_override("separation", 0)
	chip.add_child(_label(value, 18, VALUE_COLOR, true))
	chip.add_child(_label(title, 9, LABEL_COLOR, true))
	return chip


func _player_card(player: Player, stats: RunStats, width: int, player_count: int) -> PanelContainer:
	var color: Color = Player.SLOT_COLORS[player.slot % Player.SLOT_COLORS.size()]
	var card := PanelContainer.new()
	card.custom_minimum_size.x = width
	card.add_theme_stylebox_override("panel", _box(CARD_BG, color.darkened(0.2), 6))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	card.add_child(lines)

	# Header: portrait, color name, character.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	lines.add_child(header)
	var portrait := CharacterPortrait.new()
	portrait.character_id = player.character_id
	portrait.color = color
	portrait.scale_factor = 2.0
	portrait.custom_minimum_size = Vector2(28, 28)
	header.add_child(portrait)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 1)
	header.add_child(names)
	var you := " (you)" if player.is_local() and player_count > 1 else ""
	names.add_child(_label(player.display_name() + you, 9, color, false))
	names.add_child(_label(player.stats.display_name, 9, LABEL_COLOR, false))

	# Numbers.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 1)
	lines.add_child(grid)
	for stat: int in RunStats.Stat.size():
		var name_label := _label(RunStats.STAT_LABELS[stat], 9, LABEL_COLOR, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var value_label := _label("0", 9, VALUE_COLOR, false)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value_label)
		_count_up(value_label, stats.get_stat(player.peer_id, stat as RunStats.Stat), false)

	# Build: weapons, upgrades, relics.
	lines.add_child(_divider())
	var detailed := player_count <= 2
	for text: String in _build_lines(player, detailed):
		var build_label := _label(text, 9, VALUE_COLOR, false)
		build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		build_label.custom_minimum_size.x = width - 12
		lines.add_child(build_label)

	for award: String in stats.awards_for(player.peer_id):
		lines.add_child(_label("* " + award + " *", 9, AWARD_COLOR, true))
	return card


## "Weapons: Orbiting Skulls 2", "Upgrades: Quick Hands x2, ..." (or just counts
## when space is tight), "Relics: ...".
func _build_lines(player: Player, detailed: bool) -> Array[String]:
	var result: Array[String] = []
	var weapons := PackedStringArray()
	for weapon_id: int in player.weapon_levels:
		weapons.append("%s %d" % [AutoWeapons.get_weapon(weapon_id).title, player.weapon_levels[weapon_id]])
	result.append("Weapons: " + (", ".join(weapons) if not weapons.is_empty() else "none"))
	if detailed:
		var counts: Dictionary[int, int] = {}
		for id: int in player.upgrade_ids:
			counts[id] = counts.get(id, 0) + 1
		var upgrades := PackedStringArray()
		for id: int in counts:
			var title := Upgrades.get_upgrade(id).title
			upgrades.append(title if counts[id] == 1 else "%s x%d" % [title, counts[id]])
		result.append("Upgrades: " + (", ".join(upgrades) if not upgrades.is_empty() else "none"))
		var relics := PackedStringArray()
		for id: int in player.relic_ids:
			relics.append(Relics.get_relic(id).title)
		result.append("Relics: " + (", ".join(relics) if not relics.is_empty() else "none"))
	else:
		result.append("Upgrades: %d   Relics: %d" % [player.upgrade_ids.size(), player.relic_ids.size()])
	return result


func _label(text: String, font_size: int, color: Color, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = DIVIDER_COLOR
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _box(background: Color, border: Color, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(margin)
	return box


func _count_up(label: Label, value: float, is_time: bool) -> void:
	_counters[label] = [value, is_time]


func _set_counters(progress: float) -> void:
	# Ease out so the numbers slow down as they land.
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	for label: Label in _counters:
		var value: float = _counters[label][0] * eased
		label.text = RunStats.format_time(value) if _counters[label][1] else str(roundi(value))


## Fade in, count the numbers up, then show the hint with a gentle pulse.
func _animate_in(hint_label: Label) -> void:
	_set_counters(0.0)
	modulate.a = 0.0
	hint_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.tween_method(_set_counters, 0.0, 1.0, COUNT_UP_SECONDS)
	tween.tween_property(hint_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func() -> void:
		var pulse := hint_label.create_tween().set_loops()
		pulse.tween_property(hint_label, "modulate:a", 0.45, 0.8)
		pulse.tween_property(hint_label, "modulate:a", 1.0, 0.8))
