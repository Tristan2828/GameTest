class_name RunSummaryPanel
extends Control
## The end-of-run screen (Run over / Victory): an animated headline over falling
## confetti (victory) or rising embers (defeat), the bosses of the run as
## trophies, run totals, and three pages:
## - Overview: one card per player (numbers with a star for the best player in
##   each, build icons, co-op awards; the MVP gets a crown).
## - Weapons: damage, share, DPS and kills of each player's main gun, ability and
##   auto weapons, one compact row each.
## - Highlights: the team's standout moments (MVP, deadliest weapon, kill rate...).
## The cards sit in a scroll box sized to what's left of the screen, so a long
## Weapons page scrolls (mouse wheel, Up / Down) instead of pushing the tabs off
## the screen. Esc / B goes back to Overview. Built in code because the number
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
const PAGES: Array[String] = ["Overview", "Weapons", "Highlights"]
## Up / Down scroll the cards by this much.
const SCROLL_STEP: int = 24
## The scroll box never gets shorter than this, even on a tiny window.
const MIN_CARDS_HEIGHT: float = 60.0
## Weapon rows on cards at least this wide also show DPS (2 players) and kills (solo).
const DPS_CARD: int = 200
const KILLS_CARD: int = 240

var _stats: RunStats = null
var _players: Array[Player] = []
var _cards: HBoxContainer = null
var _scroll: ScrollContainer = null
var _frame: PanelContainer = null
var _page: int = 0
var _page_buttons: Array[Button] = []
## Set by the arena before open(): the difficulty's score factor and name, the
## run's first stage and whether bosses were on, and where this PC's run landed
## in its hero's Records (0 = new best, -1 = not kept).
var score_multiplier: float = 1.0
var difficulty_name: String = ""
var first_stage: int = 1
var bosses_enabled: bool = true
var local_record_rank: int = -1

var _stage_in_run: int = 1
var _stage_count: int = 1
## Labels that count up: label -> [final value, is_time]
var _counters: Dictionary[Label, Array] = {}
## Count-up ticks: the last eased progress a tick sound played at.
var _last_tick: float = 0.0


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
	_stage_count = stage_count
	for child: Node in get_children():
		child.queue_free()
	_counters.clear()
	_stats = stats
	_players = players
	_page = 0
	_page_buttons.clear()
	var accent := VICTORY_COLOR if stats.victory else DEFEAT_COLOR

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	add_child(SummaryParticles.new(stats.victory))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", _box(Color(0.06, 0.04, 0.09, 0.97), accent.darkened(0.35), 8))
	center.add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_frame.add_child(column)

	column.add_child(BannerText.new("VICTORY" if stats.victory else "RUN OVER", accent, stats.victory))
	column.add_child(_label(_headline(stats, stage_title, stage_count), 9, LABEL_COLOR, true))
	var trophies := _trophy_row(stats)
	if trophies != null:
		column.add_child(trophies)
	column.add_child(_divider())
	column.add_child(_summary_row(stats, stage_count))
	column.add_child(_divider())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	column.add_child(_scroll)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 6)
	_scroll.add_child(_cards)

	# Footer: page tabs, then the host's return button (always on screen).
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 4)
	column.add_child(footer)
	for page: int in PAGES.size():
		var tab := Button.new()
		tab.text = PAGES[page]
		tab.custom_minimum_size = Vector2(70, 20)
		tab.pressed.connect(_show_page.bind(page))
		footer.add_child(tab)
		_page_buttons.append(tab)
	_build_cards()
	var return_button: Button = null
	if can_return:
		return_button = Button.new()
		return_button.text = "Return to character select"
		return_button.custom_minimum_size = Vector2(190, 20)
		return_button.pressed.connect(func() -> void: return_requested.emit())
		footer.add_child(return_button)
	var hint_label := _label(hint + "   (Up / Down scroll, Esc back)", 9, LABEL_COLOR, true)
	column.add_child(hint_label)
	show()
	_fit_scroll.call_deferred()
	_animate_in(hint_label)
	if return_button != null:
		return_button.grab_focus()
	else:
		_page_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _scroll == null:
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var step := SCROLL_STEP if event.is_action_pressed("ui_down") else -SCROLL_STEP
		_scroll.scroll_vertical += step
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _page != 0:
		_show_page(0)
		_page_buttons[0].grab_focus()
		get_viewport().set_input_as_handled()


## Switch between the pages (numbers show their final values).
func _show_page(page: int) -> void:
	if page == _page:
		return
	_page = page
	_build_cards()
	_set_counters(1.0)
	_scroll.scroll_vertical = 0
	_fit_scroll.call_deferred()


## The scroll box takes the cards' height, but no more than the screen has left
## once the headline, totals, tabs and hint are in.
func _fit_scroll() -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	var content := _cards.get_combined_minimum_size().y
	var others := _frame.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var room := get_viewport_rect().size.y - others - 6.0
	_scroll.custom_minimum_size = Vector2(_cards.get_combined_minimum_size().x, clampf(content, MIN_CARDS_HEIGHT, maxf(room, MIN_CARDS_HEIGHT)))
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if content > room else ScrollContainer.SCROLL_MODE_DISABLED


func _build_cards() -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for label: Label in _counters.keys():
		if not is_instance_valid(label) or not label.is_inside_tree():
			_counters.erase(label)
	var width := CARD_WIDTHS[clampi(_players.size(), 1, CARD_WIDTHS.size()) - 1]
	if _page == 2:
		_cards.add_child(_highlights_card(_stats))
	else:
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


## The run's bosses side by side: slain ones in full color on a gold plinth, the
## one that ended the run tinted red, unreached ones as dark silhouettes.
func _trophy_row(stats: RunStats) -> HBoxContainer:
	if not bosses_enabled:
		return null
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for i: int in _stage_count:
		var boss := EnemyTypes.get_type(Stages.get_stage(first_stage + i).boss_type)
		var state := BossTrophy.State.UNREACHED
		if i < stats.bosses_defeated:
			state = BossTrophy.State.SLAIN
		elif i + 1 == _stage_in_run and not stats.victory and stats.fell_to == boss.display_name:
			state = BossTrophy.State.KILLER
		var trophy := BossTrophy.new(boss.sprite, state, i * 0.25)
		trophy.tooltip_text = "%s: %s" % [boss.display_name, ["not reached", "slain", "ended the run"][state]]
		row.add_child(trophy)
	return row


func _summary_row(stats: RunStats, stage_count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.add_child(_chip("TIME", stats.run_seconds, true))
	row.add_child(_chip_text("STAGE", "%d/%d" % [_stage_in_run, stage_count]))
	row.add_child(_chip("LEVEL", stats.team_level))
	row.add_child(_chip("KILLS", stats.total(RunStats.Stat.KILLS)))
	row.add_child(_chip_text("BOSSES", "%d/%d" % [stats.bosses_defeated, stage_count]))
	var team_score := 0
	for peer_id: int in stats.by_peer:
		team_score += _score(stats, peer_id)
	var score_chip := _chip("TEAM SCORE" if stats.by_peer.size() > 1 else "SCORE", team_score)
	(score_chip.get_child(0) as Label).add_theme_color_override("font_color", AWARD_COLOR)
	if not difficulty_name.is_empty():
		score_chip.tooltip_text = "%s difficulty: score x%.2f" % [difficulty_name, score_multiplier]
		score_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(score_chip)
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


## An empty player card with the header (portrait, name, character; a crown for
## the MVP). Returns [card, the column to add lines to].
func _card_frame(player: Player, width: int, player_count: int) -> Array:
	var color: Color = Player.SLOT_COLORS[player.slot % Player.SLOT_COLORS.size()]
	var is_mvp := _best_score(_stats) == player.peer_id
	var card := PanelContainer.new()
	card.custom_minimum_size.x = width
	card.add_theme_stylebox_override("panel", _box(CARD_BG, AWARD_COLOR if is_mvp else color.darkened(0.2), 6))
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
	portrait.custom_minimum_size = Vector2(28, 30)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _stats.victory:
		portrait.walk_offset = player.slot * 0.7
		portrait.animate = true  # A victory jig.
	else:
		portrait.modulate = Color(0.6, 0.58, 0.66)
	header.add_child(portrait)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 1)
	header.add_child(names)
	var you := " (you)" if player.is_local() and player_count > 1 else ""
	var name_label := _label(player.display_name() + you, 9, color, false)
	name_label.clip_text = true
	names.add_child(name_label)
	names.add_child(_label(player.stats.full_name(), 9, LABEL_COLOR, false))
	if is_mvp:
		var mvp := VBoxContainer.new()
		mvp.alignment = BoxContainer.ALIGNMENT_CENTER
		mvp.add_theme_constant_override("separation", 0)
		var crown := SpriteIcon.new("crown", Vector2(14, 9))
		crown.max_scale = 1
		crown.tint = Color.WHITE
		mvp.add_child(crown)
		mvp.add_child(_label("MVP", 9, AWARD_COLOR, true))
		mvp.tooltip_text = "Most valuable player: the highest score"
		mvp.mouse_filter = Control.MOUSE_FILTER_PASS
		header.add_child(mvp)
	return [card, lines]


func _player_card(player: Player, stats: RunStats, width: int, player_count: int) -> PanelContainer:
	var frame := _card_frame(player, width, player_count)
	var card: PanelContainer = frame[0]
	var lines: VBoxContainer = frame[1]

	# Numbers, with a star for the best player in each (co-op). Wide cards (1-2
	# players) fit two numbers per row; the score (as kept in Records) comes last.
	var grid := GridContainer.new()
	grid.columns = 6 if player_count <= 2 else 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 1)
	lines.add_child(grid)
	for stat: int in RunStats.Stat.size():
		var is_best := stats.best(stat as RunStats.Stat) == player.peer_id
		_grid_number(grid, RunStats.STAT_LABELS[stat], stats.get_stat(player.peer_id, stat as RunStats.Stat), is_best,
			LABEL_COLOR, VALUE_COLOR)
	_grid_number(grid, "Score", _score(stats, player.peer_id), _best_score(stats) == player.peer_id, AWARD_COLOR, AWARD_COLOR)
	if player.is_local() and local_record_rank == 0:
		var best := _label("NEW BEST %s RUN!" % player.stats.hero_name.to_upper(), 9, VICTORY_COLOR, true)
		lines.add_child(best)
		_pulse(best)
	elif player.is_local() and local_record_rank > 0:
		lines.add_child(_label("#%d of your %s runs" % [local_record_rank + 1, player.stats.hero_name], 9, LABEL_COLOR, true))

	# Build: auto weapons, upgrades and relics as icons (hover for names).
	lines.add_child(_divider())
	lines.add_child(_build_row(player, width))

	var awards := stats.awards_for(player.peer_id)
	if not awards.is_empty():
		var award_label := _label("* " + " * ".join(awards) + " *", 9, AWARD_COLOR, true)
		award_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		award_label.custom_minimum_size.x = width - 12
		lines.add_child(award_label)
	return card


## One "name  star  value" entry in the numbers grid (the value counts up).
func _grid_number(grid: GridContainer, title: String, value: int, is_best: bool, name_color: Color, value_color: Color) -> void:
	var name_label := _label(title, 9, name_color, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	var star := SpriteIcon.new("star" if is_best else "", Vector2(9, 9))
	star.max_scale = 1
	grid.add_child(star)
	var value_label := _label("0", 9, value_color, false)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 26
	grid.add_child(value_label)
	_count_up(value_label, value, false)


## The player with the clearly highest score (co-op), or -1.
func _best_score(stats: RunStats) -> int:
	if stats.by_peer.size() < 2:
		return -1
	var best_id := -1
	var best := -1
	var tied := false
	for peer_id: int in stats.by_peer:
		var score := _score(stats, peer_id)
		if score > best:
			best = score
			best_id = peer_id
			tied = false
		elif score == best:
			tied = true
	return -1 if tied else best_id


## "Build:" then one wrapping row of icons: auto weapons (with level pips),
## upgrades ("x2" when taken twice) and relics.
func _build_row(player: Player, width: int) -> VBoxContainer:
	var icons := _upgrade_icons(player)
	icons.append_array(_relic_icons(player))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var empty := icons.is_empty() and player.weapon_levels.is_empty()
	box.add_child(_label("Build:" + (" nothing yet" if empty else ""), 9, VALUE_COLOR, false))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size.x = width - 12
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 1)
	box.add_child(flow)
	if not player.weapon_levels.is_empty():
		var weapons := WeaponIcons.new()
		weapons.set_weapons(player.weapon_levels)
		flow.add_child(weapons)
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


## Weapons page: one compact row per damage source, most damage first: icon,
## name, share of this player's damage (with a bar), damage, and on wide cards
## DPS and kills. Hover a row for every number. Weapons that never dealt damage
## are listed as icons at the bottom.
func _weapon_card(player: Player, stats: RunStats, width: int, player_count: int) -> PanelContainer:
	var frame := _card_frame(player, width, player_count)
	var card: PanelContainer = frame[0]
	var lines: VBoxContainer = frame[1]
	var rows := stats.sources_for(player.peer_id)
	var total := 0
	for row: Array in rows:
		total += int(row[1])
	var extra := (1 if width >= DPS_CARD else 0) + (1 if width >= KILLS_CARD else 0)
	lines.add_child(_divider())
	var heading := _weapon_columns("Weapon", "Share", "Dmg", "DPS", "Kills", extra, LABEL_COLOR)
	lines.add_child(heading)
	var unused: Array[int] = []
	for row: Array in rows:
		var source: int = row[0]
		var damage: int = row[1]
		if damage <= 0:
			unused.append(source)
			continue
		var share := float(damage) / maxf(total, 1.0)
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 0)
		entry.mouse_filter = Control.MOUSE_FILTER_PASS
		var title := DamageSource.title(source, player.stats)
		entry.tooltip_text = "%s\n%d damage (%d%%)\n%d dps while owned\n%d kills" % [title, damage, roundi(share * 100.0),
			roundi(RunStats.dps(damage, row[3])), row[2]]
		var line := _weapon_columns(title, "%d%%" % roundi(share * 100.0), compact(damage),
			compact(roundi(RunStats.dps(damage, row[3]))), compact(row[2]), extra, VALUE_COLOR, DamageSource.icon(source, player.stats))
		entry.add_child(line)
		entry.add_child(_share_bar(share, width - 12))
		lines.add_child(entry)
	if total <= 0:
		lines.add_child(_label("No damage dealt", 9, LABEL_COLOR, false))
	if not unused.is_empty():
		var idle := HBoxContainer.new()
		idle.add_theme_constant_override("separation", 3)
		idle.add_child(_label("No damage:", 9, LABEL_COLOR, false))
		for source: int in unused:
			var icon := SpriteIcon.new(DamageSource.icon(source, player.stats), Vector2(11, 11))
			icon.max_scale = 1
			icon.modulate = Color(1, 1, 1, 0.5)
			icon.tooltip_text = DamageSource.title(source, player.stats)
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			idle.add_child(icon)
		lines.add_child(idle)
	lines.add_child(_divider())
	lines.add_child(_label("Total %s dmg  %s dps" % [compact(total), compact(roundi(RunStats.dps(total, roundi(stats.run_seconds))))],
		9, VALUE_COLOR, false))
	return card


## One aligned weapon row (or the heading): icon, name, share, damage, and
## `extra` more columns (1: DPS, 2: DPS and kills) on wider cards.
func _weapon_columns(title: String, share: String, damage: String, dps: String, kills: String, extra: int,
		color: Color, icon_name: String = "") -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := SpriteIcon.new(icon_name, Vector2(11, 11))
	icon.max_scale = 1
	line.add_child(icon)
	var name_label := _label(title, 9, color, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	line.add_child(name_label)
	var columns: Array[Array] = [[share, 24, AWARD_COLOR], [damage, 30, color]]
	if extra >= 1:
		columns.append([dps, 24, color])
	if extra >= 2:
		columns.append([kills, 26, color])
	for column: Array in columns:
		var cell := _label(column[0], 9, column[2] if color != LABEL_COLOR else LABEL_COLOR, false)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.custom_minimum_size.x = column[1]
		line.add_child(cell)
	return line


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


## Highlights page: the team's standout numbers, one line each.
func _highlights_card(stats: RunStats) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 420
	card.add_theme_stylebox_override("panel", _box(CARD_BG, DIVIDER_COLOR, 8))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	card.add_child(lines)
	for entry: Array in highlights(stats, _players, score_multiplier):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var icon := SpriteIcon.new(entry[0], Vector2(12, 11))
		icon.max_scale = 1
		icon.tint = entry[3]
		line.add_child(icon)
		var title := _label(entry[1], 9, LABEL_COLOR, false)
		title.custom_minimum_size.x = 110
		line.add_child(title)
		var value := _label(entry[2], 9, entry[3], false)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.clip_text = true
		line.add_child(value)
		lines.add_child(line)
	return card


## [icon, title, text, color] lines for the Highlights page (pure, testable).
static func highlights(stats: RunStats, players: Array[Player], multiplier: float) -> Array[Array]:
	var result: Array[Array] = []
	var by_id: Dictionary[int, Player] = {}
	for player: Player in players:
		by_id[player.peer_id] = player
	var name_of := func(peer_id: int) -> String:
		return by_id[peer_id].display_name() if by_id.has(peer_id) else "A friend who left"
	var color_of := func(peer_id: int) -> Color:
		return Player.SLOT_COLORS[by_id[peer_id].slot % Player.SLOT_COLORS.size()] if by_id.has(peer_id) else VALUE_COLOR
	var co_op := stats.by_peer.size() > 1

	# MVP (co-op) or your score (solo).
	var best_id := -1
	var best_score := -1
	for peer_id: int in stats.by_peer:
		var score := RunRecords.score_for(stats.get_stat(peer_id, RunStats.Stat.KILLS), stats.get_stat(peer_id, RunStats.Stat.DAMAGE),
			stats.bosses_defeated, stats.victory, multiplier)
		if score > best_score:
			best_score = score
			best_id = peer_id
	if best_id >= 0:
		if co_op:
			result.append(["crown", "MVP", "%s  -  %d score" % [name_of.call(best_id), best_score], color_of.call(best_id)])
		else:
			result.append(["star", "Score", "%d" % best_score, AWARD_COLOR])

	# Deadliest weapon: the single source that dealt the most damage.
	var top: Array = []
	var top_peer := -1
	for peer_id: int in stats.sources:
		for row: Array in stats.sources_for(peer_id):
			if top.is_empty() or int(row[1]) > int(top[1]):
				top = row
				top_peer = peer_id
	if not top.is_empty() and int(top[1]) > 0:
		var hero: CharacterStats = by_id[top_peer].stats if by_id.has(top_peer) else null
		var whose := "%s's " % name_of.call(top_peer) if co_op else ""
		var weapon := DamageSource.title(top[0], hero) if hero != null else "Their weapon"
		result.append([DamageSource.icon(top[0], hero), "Deadliest weapon", "%s%s  -  %s damage, %d kills" % [whose,
			weapon, compact(top[1]), top[2]], AWARD_COLOR])

	# Kill rate and the team's haul.
	var kills := stats.total(RunStats.Stat.KILLS)
	var minutes := maxf(stats.run_seconds / 60.0, 1.0 / 60.0)
	result.append(["skull", "Kill rate", "%d kills a minute (%d in all)" % [roundi(kills / minutes), kills], VALUE_COLOR])
	result.append(["coin", "Coins earned", "%d" % stats.total(RunStats.Stat.COINS_EARNED), Color(0.95, 0.85, 0.4)])
	result.append(["gem_big", "XP gathered", "%d  (team level %d)" % [stats.total(RunStats.Stat.XP_GATHERED), stats.team_level],
		Color(0.7, 0.55, 1.0)])

	if co_op:
		for entry: Array in [[RunStats.Stat.KILLS, "Most kills", "skull"], [RunStats.Stat.BOSS_DAMAGE, "Boss slayer", "crown"],
				[RunStats.Stat.REVIVES, "Lifesaver", "pickup_heart"], [RunStats.Stat.HEARTS_LOST, "Untouchable", "star"]]:
			var stat: RunStats.Stat = entry[0]
			var leader := stats.best(stat)
			if leader < 0:
				continue
			var detail := "%d" % stats.get_stat(leader, stat)
			if stat == RunStats.Stat.HEARTS_LOST:
				var lost := stats.get_stat(leader, stat)
				detail = "no hearts lost!" if lost == 0 else "only %d heart%s lost" % [lost, "" if lost == 1 else "s"]
			result.append([entry[2], entry[1], "%s  -  %s" % [name_of.call(leader), detail], color_of.call(leader)])
	else:
		var lost := stats.total(RunStats.Stat.HEARTS_LOST)
		result.append(["pickup_heart", "Hearts lost", "%d" % lost if lost > 0 else "none! Flawless.", Color(0.95, 0.45, 0.5)])
	return result


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
	# A soft tick while the numbers roll, slowing down with them.
	if progress < 1.0 and eased - _last_tick >= 0.07:
		_last_tick = eased
		Sfx.play(&"ui", -16.0)


func _pulse(label: Label) -> void:
	var tween := label.create_tween().set_loops()
	tween.tween_property(label, "modulate:a", 0.5, 0.5)
	tween.tween_property(label, "modulate:a", 1.0, 0.5)


## Fade in, count the numbers up, then show the hint with a gentle pulse.
func _animate_in(hint_label: Label) -> void:
	_last_tick = 0.0
	_set_counters(0.0)
	modulate.a = 0.0
	hint_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.tween_method(_set_counters, 0.0, 1.0, COUNT_UP_SECONDS)
	tween.tween_callback(func() -> void: Sfx.play(&"coin", -8.0))
	tween.tween_property(hint_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func() -> void:
		var pulse := hint_label.create_tween().set_loops()
		pulse.tween_property(hint_label, "modulate:a", 0.45, 0.8)
		pulse.tween_property(hint_label, "modulate:a", 1.0, 0.8))


## The big headline: letters drop in one by one with a bounce, then shimmer
## (a gold wave for victory, a slow red flicker for defeat).
class BannerText:
	extends Control

	const DROP_SECONDS: float = 0.35
	const LETTER_DELAY: float = 0.06
	const SIZE: int = 27

	var _text: String
	var _color: Color
	var _victory: bool
	var _age: float = 0.0

	func _init(text: String, color: Color, victory: bool) -> void:
		_text = text
		_color = color
		_victory = victory
		custom_minimum_size = Vector2(0, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_age += delta
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var total := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
		var x := roundf((size.x - total) / 2.0)
		var baseline := 25.0
		for i: int in _text.length():
			var letter := _text[i]
			var advance := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
			var t := clampf((_age - i * LETTER_DELAY) / DROP_SECONDS, 0.0, 1.0)
			if t > 0.0:
				# Drop from above and settle with a small bounce.
				var offset := -24.0 * pow(1.0 - t, 2.0) + sin(t * PI) * 3.0 * (1.0 - t)
				var color := _color
				if t >= 1.0:
					var wave := sin(_age * 3.0 - i * 0.6)
					color = _color.lerp(Color.WHITE, 0.25 * maxf(wave, 0.0)) if _victory else \
						_color.darkened(0.15 * (0.5 + 0.5 * sin(_age * 1.7 + i)))
				color.a = t
				var at := Vector2(x, baseline + roundf(offset))
				draw_string(font, at + Vector2(2, 2), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, Color(0.02, 0.01, 0.04, t))
				draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, color)
			x += advance


## One boss of the run: slain (full color, gold plinth and a gentle bob), the
## killer (red, shaking a little) or not reached (a dark silhouette).
class BossTrophy:
	extends Control

	enum State { UNREACHED, SLAIN, KILLER }

	var _sprite: String
	var _state: int
	var _phase: float

	func _init(sprite: String, state: int, phase: float) -> void:
		_sprite = sprite
		_state = state
		_phase = phase
		custom_minimum_size = Vector2(34, 30)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var now := Time.get_ticks_msec() / 1000.0 + _phase
		var sprite_size := Vector2(PixelArt.size_of(_sprite))
		var scale := clampf(floorf(minf(28.0 / sprite_size.x, 24.0 / sprite_size.y)), 1.0, 2.0)
		if sprite_size.x * scale > 32.0 or sprite_size.y * scale > 26.0:
			scale = 1.0
		var center := Vector2(size.x / 2.0, size.y / 2.0 - 2.0)
		var plinth := Rect2(Vector2(size.x / 2.0 - 12.0, size.y - 4.0), Vector2(24.0, 3.0))
		match _state:
			State.SLAIN:
				draw_rect(plinth, Color(0.95, 0.78, 0.4))
				draw_rect(Rect2(plinth.position + Vector2(2, 3), Vector2(20, 1)), Color(0.6, 0.45, 0.2))
				center.y -= roundf(absf(sin(now * 2.0)))
				PixelArt.draw(self, _sprite, center.round(), Color.WHITE, false, false, scale)
				var shine := 0.5 + 0.5 * sin(now * 3.0)
				PixelArt.draw(self, "star", (center + Vector2(sprite_size.x * scale / 2.0, -sprite_size.y * scale / 2.0)).round(),
					Color.WHITE, false, false, 1.0, Color(1, 1, 1, 0.5 + 0.5 * shine))
			State.KILLER:
				draw_rect(plinth, Color(0.5, 0.15, 0.15))
				center.x += roundf(sin(now * 23.0) * 0.6)
				PixelArt.draw(self, _sprite, center.round(), Color.WHITE, false, false, scale, Color(1.0, 0.45, 0.45))
			_:
				draw_rect(plinth, Color(0.2, 0.16, 0.26))
				PixelArt.draw(self, _sprite, center.round(), Color.WHITE, false, false, scale, Color(0.08, 0.06, 0.12, 0.9))


## Victory: gold and white confetti drifting down. Defeat: dim embers rising.
## One cheap draw call per speck (about 60 of them).
class SummaryParticles:
	extends Control

	const COUNT: int = 60

	var _victory: bool
	var _specks: Array[Vector4] = []  # x, y, speed, phase
	var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

	func _init(victory: bool) -> void:
		_victory = victory
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.randomize()

	func _ready() -> void:
		var area := get_viewport_rect().size
		for i: int in COUNT:
			_specks.append(Vector4(_rng.randf() * area.x, _rng.randf() * area.y, _rng.randf_range(14.0, 34.0), _rng.randf() * TAU))

	func _process(delta: float) -> void:
		var area := get_viewport_rect().size
		for i: int in _specks.size():
			var speck := _specks[i]
			speck.y += speck.z * delta * (1.0 if _victory else -0.7)
			speck.w += delta * 2.0
			if speck.y > area.y + 4.0:
				speck.y = -4.0
				speck.x = _rng.randf() * area.x
			elif speck.y < -4.0:
				speck.y = area.y + 4.0
				speck.x = _rng.randf() * area.x
			_specks[i] = speck
		queue_redraw()

	func _draw() -> void:
		for i: int in _specks.size():
			var speck := _specks[i]
			var at := Vector2(speck.x + sin(speck.w) * 6.0, speck.y).round()
			if _victory:
				var colors: Array[Color] = [Color(0.95, 0.85, 0.55), Color(1, 1, 1), Color(0.95, 0.6, 0.35), Color(0.6, 0.8, 1.0)]
				var flip := absf(sin(speck.w * 1.3)) > 0.5
				draw_rect(Rect2(at, Vector2(2, 1) if flip else Vector2(1, 2)), Color(colors[i % colors.size()], 0.8))
			else:
				var glow := 0.35 + 0.35 * sin(speck.w * 1.7)
				draw_rect(Rect2(at, Vector2(1, 1)), Color(0.95, 0.4 + 0.2 * glow, 0.25, glow))
