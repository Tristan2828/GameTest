class_name RunSummaryPanel
extends Control
## The end-of-run screen (Run over / Victory): headline, run totals, and one card
## per player. Two pages: Overview (numbers with a star for the best player in
## each, build icons, co-op awards) and Weapons (damage, DPS and kills of each
## player's main gun, ability and auto weapons). Built in code because the number
## of player cards changes. Numbers count up when it opens.
## The host gets a button back to character select; clients see a waiting line.

## Host: the "Return to character select" button was pressed.
signal return_requested

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
const BAR_COLOR: Color = Color(0.95, 0.78, 0.4)
const BAR_BACK_COLOR: Color = Color(0.2, 0.16, 0.26)
const PAGES: Array[String] = ["Overview", "Weapons"]

var _stats: RunStats = null
var _players: Array[Player] = []
var _cards: HBoxContainer = null
var _page: int = 0
var _page_buttons: Array[Button] = []
## Set by the arena before open(): the difficulty's score factor, and where this
## PC's run landed in its hero's Records (0 = new best, -1 = not kept).
var score_multiplier: float = 1.0
var local_record_rank: int = -1

var _stage_in_run: int = 1
## Labels that count up: label -> [final value, is_time]
var _counters: Dictionary[Label, Array] = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds and shows the screen. `players` are the Player nodes still in the game.
## `can_return` shows the return button (the host); `hint` is the line under it.
## `stage_in_run` is how far into the run the last stage was (differs from
## stats.stage_reached in a single-stage custom game on a later map).
func open(stats: RunStats, players: Array[Player], stage_title: String, stage_count: int, hint: String,
		can_return: bool = false, stage_in_run: int = -1) -> void:
	_stage_in_run = stage_in_run if stage_in_run > 0 else stats.stage_reached
	for child: Node in get_children():
		child.queue_free()
	_counters.clear()
	_stats = stats
	_players = players
	_page = 0
	_page_buttons.clear()
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

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	for page: int in PAGES.size():
		var tab := Button.new()
		tab.text = PAGES[page]
		tab.custom_minimum_size.x = 80
		tab.pressed.connect(_show_page.bind(page))
		tabs.add_child(tab)
		_page_buttons.append(tab)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 6)
	column.add_child(_cards)
	_build_cards()

	var return_button: Button = null
	if can_return:
		return_button = Button.new()
		return_button.text = "Return to character select"
		return_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return_button.custom_minimum_size = Vector2(200, 20)
		return_button.pressed.connect(func() -> void: return_requested.emit())
		column.add_child(return_button)
	var hint_label := _label(hint, 9, LABEL_COLOR, true)
	column.add_child(hint_label)
	show()
	_animate_in(hint_label)
	if return_button != null:
		return_button.grab_focus()
	else:
		_page_buttons[0].grab_focus()


## Switch between Overview and Weapons (numbers show their final values).
func _show_page(page: int) -> void:
	if page == _page:
		return
	_page = page
	_build_cards()
	_set_counters(1.0)


func _build_cards() -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for label: Label in _counters.keys():
		if not is_instance_valid(label) or not label.is_inside_tree():
			_counters.erase(label)
	var width := CARD_WIDTHS[clampi(_players.size(), 1, CARD_WIDTHS.size()) - 1]
	for player: Player in _players:
		if _page == 0:
			_cards.add_child(_player_card(player, _stats, width, _players.size()))
		else:
			_cards.add_child(_weapon_card(player, _stats, width, _players.size()))
	for page: int in _page_buttons.size():
		var color := AWARD_COLOR if page == _page else VALUE_COLOR
		_page_buttons[page].add_theme_color_override("font_color", color)
		_page_buttons[page].add_theme_color_override("font_focus_color", color)


func _headline(stats: RunStats, stage_title: String, stage_count: int) -> String:
	if stats.victory:
		if stage_count == 1:
			return "%s cleansed. The dark recedes... for now." % stage_title
		return "All %d stages cleansed. The dark recedes... for now." % stage_count
	var where := "Stage %d: %s" % [_stage_in_run, stage_title]
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
	row.add_child(_chip_text("STAGE", "%d/%d" % [_stage_in_run, stage_count]))
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


## An empty player card with the header (portrait, color name, character).
## Returns [card, the column to add lines to].
func _card_frame(player: Player, width: int, player_count: int) -> Array:
	var color: Color = Player.SLOT_COLORS[player.slot % Player.SLOT_COLORS.size()]
	var card := PanelContainer.new()
	card.custom_minimum_size.x = width
	card.add_theme_stylebox_override("panel", _box(CARD_BG, color.darkened(0.2), 6))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	card.add_child(lines)
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
	return [card, lines]


func _player_card(player: Player, stats: RunStats, width: int, player_count: int) -> PanelContainer:
	var frame := _card_frame(player, width, player_count)
	var card: PanelContainer = frame[0]
	var lines: VBoxContainer = frame[1]

	# Numbers, with a star for the best player in each (co-op).
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 1)
	lines.add_child(grid)
	for stat: int in RunStats.Stat.size():
		var name_label := _label(RunStats.STAT_LABELS[stat], 9, LABEL_COLOR, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var star := SpriteIcon.new("star" if stats.best(stat as RunStats.Stat) == player.peer_id else "", Vector2(9, 9))
		star.max_scale = 1
		grid.add_child(star)
		var value_label := _label("0", 9, VALUE_COLOR, false)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value_label)
		_count_up(value_label, stats.get_stat(player.peer_id, stat as RunStats.Stat), false)

	# Score (as kept in Records), with this PC's placing.
	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 3)
	var score_name := _label("Score", 9, AWARD_COLOR, false)
	score_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_row.add_child(score_name)
	if player.is_local() and local_record_rank == 0:
		score_row.add_child(_label("NEW BEST!", 9, VICTORY_COLOR, false))
	elif player.is_local() and local_record_rank > 0:
		score_row.add_child(_label("#%d best" % (local_record_rank + 1), 9, LABEL_COLOR, false))
	var score_label := _label("0", 9, AWARD_COLOR, false)
	score_row.add_child(score_label)
	_count_up(score_label, _score(stats, player.peer_id), false)
	lines.add_child(score_row)

	# Build: weapon icons, upgrades, relics.
	lines.add_child(_divider())
	lines.add_child(_weapons_row(player))
	lines.add_child(_icon_row("Upgrades:", _upgrade_icons(player), width))
	lines.add_child(_icon_row("Relics:", _relic_icons(player), width))

	for award: String in stats.awards_for(player.peer_id):
		lines.add_child(_label("* " + award + " *", 9, AWARD_COLOR, true))
	return card


## "Weapons" followed by each weapon's icon and level pips (or "none").
func _weapons_row(player: Player) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_label("Weapons:", 9, VALUE_COLOR, false))
	if player.weapon_levels.is_empty():
		row.add_child(_label("none", 9, VALUE_COLOR, false))
	else:
		var icons := WeaponIcons.new()
		icons.icon_scale = 2.0
		icons.set_weapons(player.weapon_levels)
		row.add_child(icons)
	return row


func _score(stats: RunStats, peer_id: int) -> int:
	return RunRecords.score_for(stats.get_stat(peer_id, RunStats.Stat.KILLS), stats.get_stat(peer_id, RunStats.Stat.DAMAGE),
		stats.bosses_defeated, stats.victory, score_multiplier)


## [icon, title, count] for each different upgrade, in the order first taken.
func _upgrade_icons(player: Player) -> Array[Array]:
	var counts: Dictionary[int, int] = {}
	for id: int in player.upgrade_ids:
		counts[id] = counts.get(id, 0) + 1
	var result: Array[Array] = []
	for id: int in counts:
		var upgrade := Upgrades.get_upgrade(id)
		result.append([upgrade.icon, upgrade.title, counts[id]])
	return result


func _relic_icons(player: Player) -> Array[Array]:
	var result: Array[Array] = []
	for id: int in player.relic_ids:
		var relic := Relics.get_relic(id)
		result.append([relic.icon, relic.title, 1])
	return result


## "Upgrades:" then a wrapping row of icons, each with "x2" when taken more than
## once. Hovering an icon shows its name.
func _icon_row(title: String, icons: Array[Array], width: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.add_child(_label(title + (" none" if icons.is_empty() else ""), 9, VALUE_COLOR, false))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size.x = width - 12
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 1)
	box.add_child(flow)
	for entry: Array in icons:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 0)
		item.tooltip_text = entry[1]
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		var icon := SpriteIcon.new(entry[0], Vector2(11, 11))
		icon.max_scale = 1
		item.add_child(icon)
		if entry[2] > 1:
			item.add_child(_label("x%d" % entry[2], 9, LABEL_COLOR, false))
		flow.add_child(item)
	return box


## Weapons page: each damage source with its share of this player's damage,
## then damage / DPS / kills, most damage first.
func _weapon_card(player: Player, stats: RunStats, width: int, player_count: int) -> PanelContainer:
	var frame := _card_frame(player, width, player_count)
	var card: PanelContainer = frame[0]
	var lines: VBoxContainer = frame[1]
	var rows := stats.sources_for(player.peer_id)
	var total := 0
	for row: Array in rows:
		total += int(row[1])
	lines.add_child(_divider())
	if rows.is_empty():
		lines.add_child(_label("No damage dealt", 9, LABEL_COLOR, false))
	for row: Array in rows:
		var source: int = row[0]
		var damage: int = row[1]
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		var icon := SpriteIcon.new(DamageSource.icon(source), Vector2(11, 11))
		icon.max_scale = 1
		top.add_child(icon)
		var name_label := _label(DamageSource.title(source, player.stats), 9, VALUE_COLOR, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		top.add_child(name_label)
		var share := roundi(100.0 * damage / maxf(total, 1.0))
		top.add_child(_label("%d%%" % share, 9, AWARD_COLOR, false))
		lines.add_child(top)
		lines.add_child(_share_bar(float(damage) / maxf(total, 1.0), width - 12))
		var detail := "%s dmg  %s dps  %d kills" % [compact(damage), compact(roundi(RunStats.dps(damage, row[3]))), row[2]]
		lines.add_child(_label(detail, 9, LABEL_COLOR, false))
	lines.add_child(_divider())
	var total_label := _label("", 9, VALUE_COLOR, false)
	lines.add_child(total_label)
	total_label.text = "Total %s dmg  %s dps" % [compact(total), compact(roundi(RunStats.dps(total, roundi(stats.run_seconds))))]
	return card


func _share_bar(ratio: float, width: int) -> Control:
	var back := ColorRect.new()
	back.color = BAR_BACK_COLOR
	back.custom_minimum_size = Vector2(width, 2)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = BAR_COLOR
	fill.size = Vector2(roundf(width * clampf(ratio, 0.0, 1.0)), 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return back


## 950 -> "950", 12345 -> "12.3k", 2500000 -> "2.5M".
static func compact(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	if value >= 10000:
		return "%.1fk" % (value / 1000.0)
	return str(value)


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
		if not is_instance_valid(label):
			continue
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
