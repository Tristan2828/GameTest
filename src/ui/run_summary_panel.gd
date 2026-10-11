class_name RunSummaryPanel
extends Control
## The end-of-run screen (Run over / Victory): an animated headline over falling
## confetti (victory) or rising embers (defeat), the run's difficulty, the
## bosses of the run as trophies (with each stage's time), run totals, and four
## pages:
## - Overview: one card per player (numbers with a star for the best player in
##   each, their score, weapons / passives / relics as icons, co-op awards; the
##   MVP gets a crown).
## - Weapons: damage, share, DPS and kills of each player's main weapon and
##   auto weapons, one compact row each.
## - Stages: the team's numbers for each stage (time, boss fight, kills, damage
##   taken, downs, level, events, the busiest moment), for balancing.
## - Highlights: the team's standout moments (MVP, deadliest weapon, kill rate...).
## Every card has a fixed width and its text wraps or clips, so four players
## always fit side by side (v0.24.0: long lines used to push the 4th card off
## the screen). The cards sit in a scroll box sized to what's left of the
## screen (mouse wheel, Up / Down). Esc / B goes back to Overview. Built in code
## because the number of player cards changes. Numbers count up when it opens.
## The host gets a button back to character select; clients see a waiting line.
##
## This file runs the screen (opening, pages, the header and totals, the
## count-up). The pages are built by SummaryPlayerCards (Overview, Weapons) and
## SummaryTeamPages (Stages, Highlights); SummaryStyle has the shared colors and
## widgets; SummaryBanner, BossTrophy and SummaryParticles are the animated parts.

## Host: the "Return to character select" button was pressed.
signal return_requested

const COUNT_UP_SECONDS: float = 1.2
## Card width by player count (index = players - 1). Four cards plus gaps and
## the frame stay inside 640 px.
const CARD_WIDTHS: Array[int] = [250, 210, 170, 140]
const PAGES: Array[String] = ["Overview", "Weapons", "Stages", "Highlights"]
const PAGE_OVERVIEW: int = 0
const PAGE_WEAPONS: int = 1
const PAGE_STAGES: int = 2
const PAGE_HIGHLIGHTS: int = 3
## Up / Down scroll the cards by this much.
const SCROLL_STEP: int = 24
## The scroll box never gets shorter than this, even on a tiny window.
const MIN_CARDS_HEIGHT: float = 60.0
## The difficulty chip's color per preset ("Custom" for anything else).
const DIFFICULTY_COLORS: Dictionary[String, Color] = {
	"Easy": Color(0.55, 0.9, 0.45), "Normal": Color(0.9, 0.88, 0.95),
	"Hard": Color(0.95, 0.4, 0.38), "Custom": Color(0.95, 0.78, 0.4),
}

var _stats: RunStats = null
var _players: Array[Player] = []
var _cards: HBoxContainer = null
var _scroll: ScrollContainer = null
var _frame: PanelContainer = null
var _page: int = 0
var _page_buttons: Array[Button] = []
## Builds the Overview and Weapons cards (made in open()).
var _player_cards: SummaryPlayerCards = null
## Set by the arena before open(): the run's settings (difficulty, custom game;
## null = defaults), the run's first stage and whether bosses were on, and
## where this PC's run landed in its hero's Records (0 = new best, -1 = not kept).
var config: RunConfig = null
var score_multiplier: float = 1.0
var difficulty_name: String = ""
var first_stage: int = 1
var bosses_enabled: bool = true
var local_record_rank: int = -1
## Embers this PC's player earned (-1 = not counted, e.g. test runs).
var local_embers: int = -1
## The hero this run unlocked on this PC (HeroUnlocks), or -1.
var local_unlock: int = -1

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
	if config != null:
		score_multiplier = config.score_multiplier()
		difficulty_name = config.difficulty_name()
	for child: Node in get_children():
		child.queue_free()
	_counters.clear()
	_stats = stats
	_players = players
	_player_cards = SummaryPlayerCards.new(stats, score_multiplier, _counters)
	_player_cards.local_record_rank = local_record_rank
	_player_cards.local_embers = local_embers
	_player_cards.local_unlock = local_unlock
	_page = 0
	_page_buttons.clear()
	var accent := SummaryStyle.VICTORY_COLOR if stats.victory else SummaryStyle.DEFEAT_COLOR

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
	_frame.add_theme_stylebox_override("panel", SummaryStyle.box(Color(0.06, 0.04, 0.09, 0.97), accent.darkened(0.35), 6))
	center.add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_frame.add_child(column)

	column.add_child(SummaryBanner.new("VICTORY" if stats.victory else "RUN OVER", accent, stats.victory))
	column.add_child(SummaryStyle.label(_headline(stats, stage_title, stage_count), 9, SummaryStyle.LABEL_COLOR, true))
	column.add_child(_difficulty_ribbon())
	column.add_child(SummaryStyle.divider())
	column.add_child(_top_row(stats, stage_count))
	column.add_child(SummaryStyle.divider())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	column.add_child(_scroll)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 5)
	_scroll.add_child(_cards)

	# Footer: page tabs, then the host's return button (always on screen).
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 4)
	column.add_child(footer)
	for page: int in PAGES.size():
		var tab := Button.new()
		tab.text = PAGES[page]
		tab.custom_minimum_size = Vector2(66, 20)
		tab.pressed.connect(_show_page.bind(page))
		footer.add_child(tab)
		_page_buttons.append(tab)
	_build_cards()
	var return_button: Button = null
	if can_return:
		return_button = Button.new()
		return_button.text = "Return to character select"
		return_button.custom_minimum_size = Vector2(170, 20)
		return_button.pressed.connect(func() -> void: return_requested.emit())
		footer.add_child(return_button)
	var hint_label := SummaryStyle.label(hint + "   (Up / Down scroll, Esc back)", 9, SummaryStyle.LABEL_COLOR, true)
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
	var width := card_width(_players.size())
	match _page:
		PAGE_STAGES:
			_cards.add_child(SummaryTeamPages.stages_card(_stats))
		PAGE_HIGHLIGHTS:
			_cards.add_child(SummaryTeamPages.highlights_card(_stats, _players, score_multiplier))
		_:
			for player: Player in _players:
				if _page == PAGE_OVERVIEW:
					_cards.add_child(_player_cards.overview_card(player, width, _players.size()))
				else:
					_cards.add_child(_player_cards.weapons_card(player, width, _players.size()))
	for page: int in _page_buttons.size():
		var color := SummaryStyle.AWARD_COLOR if page == _page else SummaryStyle.VALUE_COLOR
		_page_buttons[page].add_theme_color_override("font_color", color)
		_page_buttons[page].add_theme_color_override("font_focus_color", color)


## A player card's width with this many players.
static func card_width(player_count: int) -> int:
	return CARD_WIDTHS[clampi(player_count, 1, CARD_WIDTHS.size()) - 1]


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


## The run's difficulty: a colored chip ("HARD"), the score factor and every
## difficulty value, then any custom game settings (so a run can be judged
## against the settings it was played on).
func _difficulty_ribbon() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var level_name := difficulty_name if not difficulty_name.is_empty() else "Normal"
	var color: Color = DIFFICULTY_COLORS.get(level_name, SummaryStyle.AWARD_COLOR)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var chip := PanelContainer.new()
	var chip_style := SummaryStyle.box(color.darkened(0.7), color, 0)
	chip_style.content_margin_left = 4
	chip_style.content_margin_right = 4
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.add_child(SummaryStyle.label(level_name.to_upper(), 9, color, true))
	chip.tooltip_text = "Difficulty (score x%.2f)" % score_multiplier
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(chip)
	var settings := config if config != null else RunConfig.new()
	row.add_child(SummaryStyle.label(settings.difficulty_details(true), 9, SummaryStyle.LABEL_COLOR, false))
	row.add_child(SummaryStyle.label("score x%.2f" % score_multiplier, 9, SummaryStyle.AWARD_COLOR, false))
	var custom := settings.custom_details()
	if not custom.is_empty():
		var extra := SummaryStyle.label(custom, 9, SummaryStyle.AWARD_COLOR, true)
		extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		extra.custom_minimum_size.x = SummaryStyle.WIDE_CARD
		box.add_child(extra)
	return box


## Trophies on the left, the run's totals on the right.
func _top_row(stats: RunStats, stage_count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var trophies := _trophy_row(stats)
	if trophies != null:
		row.add_child(trophies)
		var line := ColorRect.new()
		line.color = SummaryStyle.DIVIDER_COLOR
		line.custom_minimum_size = Vector2(1, 30)
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
	row.add_child(_summary_row(stats, stage_count))
	return row


## The run's bosses side by side: slain ones in full color on a gold plinth, the
## one that ended the run tinted red, unreached ones as dark silhouettes. Each
## shows how long its stage took.
func _trophy_row(stats: RunStats) -> HBoxContainer:
	if not bosses_enabled:
		return null
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for i: int in _stage_count:
		var stage := Stages.get_stage(first_stage + i)
		var boss := EnemyTypes.get_type(stage.boss_type)
		var state := BossTrophy.State.UNREACHED
		if i < stats.bosses_defeated:
			state = BossTrophy.State.SLAIN
		elif i + 1 == _stage_in_run and not stats.victory and stats.fell_to == boss.display_name:
			state = BossTrophy.State.KILLER
		var caption := "-"
		var tooltip := "%s: %s" % [boss.display_name, ["not reached", "slain", "ended the run"][state]]
		if i < stats.stage_rows.size():
			var stage_row := stats.stage_rows[i]
			caption = RunStats.format_time(stage_row[RunStats.StageField.SECONDS])
			tooltip += "\n%s: %s" % [stage.title, caption]
			if stage_row[RunStats.StageField.BOSS_SECONDS] >= 0:
				tooltip += " (boss fight %s)" % RunStats.format_time(stage_row[RunStats.StageField.BOSS_SECONDS])
		var trophy := BossTrophy.new(boss.sprite, state, i * 0.25, caption)
		trophy.tooltip_text = tooltip
		row.add_child(trophy)
	return row


func _summary_row(stats: RunStats, stage_count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_chip("TIME", stats.run_seconds, true))
	row.add_child(_chip_text("STAGE", "%d/%d" % [_stage_in_run, stage_count]))
	row.add_child(_chip("LEVEL", stats.team_level))
	row.add_child(_chip("KILLS", stats.total(RunStats.Stat.KILLS)))
	if bosses_enabled:
		row.add_child(_chip_text("BOSSES", "%d/%d" % [stats.bosses_defeated, stage_count]))
	var team_score := 0
	for peer_id: int in stats.by_peer:
		team_score += SummaryPlayerCards.score_of(stats, peer_id, score_multiplier)
	var score_chip := _chip("TEAM SCORE" if stats.by_peer.size() > 1 else "SCORE", team_score)
	(score_chip.get_child(0) as Label).add_theme_color_override("font_color", SummaryStyle.AWARD_COLOR)
	score_chip.tooltip_text = "%s difficulty: score x%.2f" % [difficulty_name if not difficulty_name.is_empty() else "Normal", score_multiplier]
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
	chip.add_child(SummaryStyle.label(value, 18, SummaryStyle.VALUE_COLOR, true))
	chip.add_child(SummaryStyle.label(title, 9, SummaryStyle.LABEL_COLOR, true))
	return chip


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
