class_name SummaryPlayerCards
extends RefCounted
## The run summary's per-player cards: Overview (numbers with a star for the
## best player in each, score, weapons / passives / relics as icons, Records,
## Embers, unlocks and co-op awards; the MVP gets a crown) and Weapons (damage,
## share, DPS and kills of each damage source, one compact row each).
## Every card has a fixed width and its text wraps or clips (see RunSummaryPanel).

## Weapon rows on cards at least this wide also show DPS (2 players) and kills (solo).
const DPS_CARD: int = 200
const KILLS_CARD: int = 240

var stats: RunStats
var score_multiplier: float = 1.0
## Where this PC's run landed in its hero's Records (0 = new best, -1 = not kept).
var local_record_rank: int = -1
## Embers this PC's player earned (-1 = not counted, e.g. test runs).
var local_embers: int = -1
## The hero this run unlocked on this PC (HeroUnlocks), or -1.
var local_unlock: int = -1
## The panel's count-up labels: label -> [final value, is_time]. Shared, so the
## panel animates the numbers these cards add.
var counters: Dictionary[Label, Array] = {}


func _init(run_stats: RunStats, multiplier: float, panel_counters: Dictionary[Label, Array]) -> void:
	stats = run_stats
	score_multiplier = multiplier
	counters = panel_counters


## A player's score, as kept in Records.
static func score_of(run_stats: RunStats, peer_id: int, multiplier: float) -> int:
	return RunRecords.score_for(run_stats.get_stat(peer_id, RunStats.Stat.KILLS), run_stats.get_stat(peer_id, RunStats.Stat.DAMAGE),
		run_stats.bosses_defeated, run_stats.victory, multiplier)


## The player with the clearly highest score (co-op), or -1.
static func best_score(run_stats: RunStats, multiplier: float) -> int:
	if run_stats.by_peer.size() < 2:
		return -1
	var best_id := -1
	var best := -1
	var tied := false
	for peer_id: int in run_stats.by_peer:
		var score := score_of(run_stats, peer_id, multiplier)
		if score > best:
			best = score
			best_id = peer_id
			tied = false
		elif score == best:
			tied = true
	return -1 if tied else best_id


## [icon, title, level] for each passive, in the order first taken (filler
## cards like Blood Draught and Coin Pouch aren't passives).
static func passive_icons(player: Player) -> Array[Array]:
	var counts: Dictionary[int, int] = {}
	for id: int in player.upgrade_ids:
		if Upgrades.get_upgrade(id).passive:
			counts[id] = counts.get(id, 0) + 1
	var result: Array[Array] = []
	for id: int in counts:
		var upgrade := Upgrades.get_upgrade(id)
		result.append([upgrade.icon, upgrade.title, counts[id]])
	return result


## Overview page: one player's card.
func overview_card(player: Player, width: int, player_count: int) -> PanelContainer:
	var frame := _card_frame(player, width, player_count)
	var card: PanelContainer = frame[0]
	var lines: VBoxContainer = frame[1]
	var inner := width - SummaryStyle.CARD_INSET

	# The score (as kept in Records), big.
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 4)
	var score_label := SummaryStyle.label("0", 18, SummaryStyle.AWARD_COLOR, false)
	_count_up(score_label, score_of(stats, player.peer_id, score_multiplier))
	score_row.add_child(score_label)
	var score_name := SummaryStyle.label("score", 9, SummaryStyle.LABEL_COLOR, false)
	score_name.size_flags_vertical = Control.SIZE_SHRINK_END
	score_row.add_child(score_name)
	lines.add_child(score_row)

	# Numbers, with a star for the best player in each (co-op). Wide cards (1-2
	# players) fit two numbers per row.
	var grid := GridContainer.new()
	grid.columns = 6 if player_count <= 2 else 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 0)
	lines.add_child(grid)
	for stat: RunStats.Stat in RunStats.CARD_STATS:
		var is_best := stats.best(stat) == player.peer_id
		_grid_number(grid, RunStats.STAT_LABELS[stat], stats.get_stat(player.peer_id, stat), is_best)

	# Build: weapons (with level pips), passives (with their level) and relics.
	lines.add_child(SummaryStyle.divider())
	lines.add_child(_build_section("Weapons", inner, [], WeaponIcons.weapon_entries(player)))
	var passives := passive_icons(player)
	if not passives.is_empty():
		lines.add_child(_build_section("Passives", inner, passives))
	var relics := _relic_icons(player)
	if not relics.is_empty():
		lines.add_child(_build_section("Relics", inner, relics))

	# Records, Embers and co-op awards at the bottom.
	var notes: Array[Label] = []
	if player.is_local() and local_record_rank == 0:
		var best := SummaryStyle.label("NEW BEST %s RUN!" % player.stats.hero_name.to_upper(), 9, SummaryStyle.VICTORY_COLOR, true)
		SummaryStyle.pulse(best)
		notes.append(best)
	elif player.is_local() and local_record_rank > 0:
		notes.append(SummaryStyle.label("#%d of your %s runs" % [local_record_rank + 1, player.stats.hero_name], 9,
			SummaryStyle.LABEL_COLOR, true))
	if player.is_local() and local_embers >= 0:
		var embers := SummaryStyle.label("+%d Embers" % local_embers, 9, SummaryStyle.EMBER_COLOR, true)
		embers.tooltip_text = "Spend them at the Ember Shrine on the title menu"
		embers.mouse_filter = Control.MOUSE_FILTER_PASS
		notes.append(embers)
	if player.is_local() and Characters.is_valid_id(local_unlock):
		var hero := Characters.get_character(local_unlock)
		var unlocked := SummaryStyle.label("NEW HERO: %s THE %s!" % [hero.hero_name.to_upper(), hero.display_name.to_upper()], 9,
			SummaryStyle.VICTORY_COLOR, true)
		unlocked.tooltip_text = "Pick them in the lobby"
		unlocked.mouse_filter = Control.MOUSE_FILTER_PASS
		SummaryStyle.pulse(unlocked)
		notes.append(unlocked)
	var awards := stats.awards_for(player.peer_id)
	if not awards.is_empty():
		notes.append(SummaryStyle.label("* " + " * ".join(awards) + " *", 9, SummaryStyle.AWARD_COLOR, true))
	if not notes.is_empty():
		lines.add_child(SummaryStyle.divider())
		for note: Label in notes:
			lines.add_child(SummaryStyle.wrapped(note, inner))
	return card


## Weapons page: one compact row per damage source, most damage first: icon,
## name, share of this player's damage (with a bar), damage, and on wide cards
## DPS and kills. Hover a row for every number. Weapons that never dealt damage
## are listed as icons at the bottom.
func weapons_card(player: Player, width: int, player_count: int) -> PanelContainer:
	var frame := _card_frame(player, width, player_count)
	var card: PanelContainer = frame[0]
	var lines: VBoxContainer = frame[1]
	var rows := stats.sources_for(player.peer_id)
	var total := 0
	for row: Array in rows:
		total += int(row[1])
	var extra := (1 if width >= DPS_CARD else 0) + (1 if width >= KILLS_CARD else 0)
	var heading := _weapon_columns("Weapon", "Share", "Dmg", "DPS", "Kills", extra, SummaryStyle.LABEL_COLOR)
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
		var line := _weapon_columns(title, "%d%%" % roundi(share * 100.0), SummaryStyle.compact(damage),
			SummaryStyle.compact(roundi(RunStats.dps(damage, row[3]))), SummaryStyle.compact(row[2]), extra,
			SummaryStyle.VALUE_COLOR, DamageSource.icon(source, player.stats))
		entry.add_child(line)
		entry.add_child(SummaryStyle.share_bar(share, width - SummaryStyle.CARD_INSET))
		lines.add_child(entry)
	if total <= 0:
		lines.add_child(SummaryStyle.label("No damage dealt", 9, SummaryStyle.LABEL_COLOR, false))
	if not unused.is_empty():
		var idle := HFlowContainer.new()
		idle.custom_minimum_size.x = width - SummaryStyle.CARD_INSET
		idle.add_theme_constant_override("h_separation", 3)
		idle.add_child(SummaryStyle.label("No damage:", 9, SummaryStyle.LABEL_COLOR, false))
		for source: int in unused:
			var icon := SpriteIcon.new(DamageSource.icon(source, player.stats), Vector2(11, 11))
			icon.max_scale = 1
			icon.modulate = Color(1, 1, 1, 0.5)
			icon.tooltip_text = DamageSource.title(source, player.stats)
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			idle.add_child(icon)
		lines.add_child(idle)
	lines.add_child(SummaryStyle.divider())
	lines.add_child(SummaryStyle.wrapped(SummaryStyle.label("Total %s dmg  %s dps" % [SummaryStyle.compact(total),
		SummaryStyle.compact(roundi(RunStats.dps(total, roundi(stats.run_seconds))))], 9, SummaryStyle.VALUE_COLOR, false),
		width - SummaryStyle.CARD_INSET))
	return card


## An empty player card with the header (portrait, name, hero; a crown for the
## MVP) on a band of the player's color. Returns [card, the column to add lines to].
func _card_frame(player: Player, width: int, player_count: int) -> Array:
	var color: Color = Player.SLOT_COLORS[player.slot % Player.SLOT_COLORS.size()]
	var is_mvp := best_score(stats, score_multiplier) == player.peer_id
	var card := PanelContainer.new()
	card.custom_minimum_size.x = width
	card.add_theme_stylebox_override("panel", SummaryStyle.box(SummaryStyle.CARD_BG,
		SummaryStyle.AWARD_COLOR if is_mvp else color.darkened(0.2), 5))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	card.add_child(lines)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", SummaryStyle.box(color.darkened(0.72), color.darkened(0.45), 2))
	lines.add_child(band)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	band.add_child(header)
	var portrait := CharacterPortrait.new()
	portrait.character_id = player.character_id
	portrait.color = color
	portrait.scale_factor = 2.0
	portrait.custom_minimum_size = Vector2(28, 30)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stats.victory:
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
	names.add_child(SummaryStyle.clipped(SummaryStyle.label(player.display_name() + you, 9, color.lightened(0.2), false)))
	names.add_child(SummaryStyle.clipped(SummaryStyle.label(player.stats.hero_name, 9, SummaryStyle.VALUE_COLOR, false)))
	names.tooltip_text = "%s - %s" % [player.display_name(), player.stats.full_name()]
	names.mouse_filter = Control.MOUSE_FILTER_PASS
	if is_mvp:
		var mvp := VBoxContainer.new()
		mvp.alignment = BoxContainer.ALIGNMENT_CENTER
		mvp.add_theme_constant_override("separation", 0)
		var crown := SpriteIcon.new("crown", Vector2(14, 9))
		crown.max_scale = 1
		crown.tint = Color.WHITE
		mvp.add_child(crown)
		mvp.add_child(SummaryStyle.label("MVP", 9, SummaryStyle.AWARD_COLOR, true))
		mvp.tooltip_text = "Most valuable player: the highest score"
		mvp.mouse_filter = Control.MOUSE_FILTER_PASS
		header.add_child(mvp)
	return [card, lines]


## One "name  star  value" entry in the numbers grid (the value counts up).
func _grid_number(grid: GridContainer, title: String, value: int, is_best: bool) -> void:
	var name_label := SummaryStyle.label(title, 9, SummaryStyle.LABEL_COLOR, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	var star := SpriteIcon.new("star" if is_best else "", Vector2(9, 9))
	star.max_scale = 1
	grid.add_child(star)
	var value_label := SummaryStyle.label("0", 9, SummaryStyle.VALUE_COLOR, false)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 28
	grid.add_child(value_label)
	_count_up(value_label, value)


## A titled, wrapping row of icons: `icons` are [sprite, title, count] (the
## count shows as a small number when above 1); `weapons` adds the weapon row.
func _build_section(title: String, width: int, icons: Array[Array], weapons: Array[WeaponIcons.Entry] = []) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 1)
	section.add_child(SummaryStyle.label(title, 9, SummaryStyle.VALUE_COLOR, false))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size.x = width
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 1)
	section.add_child(flow)
	if not weapons.is_empty():
		var row := WeaponIcons.new()
		row.set_entries(weapons)
		flow.add_child(row)
	for entry: Array in icons:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 0)
		item.tooltip_text = entry[1] if entry[2] <= 1 else "%s (level %d)" % [entry[1], entry[2]]
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		var icon := SpriteIcon.new(entry[0], Vector2(11, 11))
		icon.max_scale = 1
		item.add_child(icon)
		if entry[2] > 1:
			item.add_child(SummaryStyle.label(str(entry[2]), 9, SummaryStyle.LABEL_COLOR, false))
		flow.add_child(item)
	return section


func _relic_icons(player: Player) -> Array[Array]:
	var result: Array[Array] = []
	for id: int in player.relic_ids:
		var relic := Relics.get_relic(id)
		result.append([relic.icon, relic.title, 1])
	return result


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
	var name_label := SummaryStyle.clipped(SummaryStyle.label(title, 9, color, false))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var columns: Array[Array] = [[share, 24, SummaryStyle.AWARD_COLOR], [damage, 30, color]]
	if extra >= 1:
		columns.append([dps, 24, color])
	if extra >= 2:
		columns.append([kills, 26, color])
	for column: Array in columns:
		var cell := SummaryStyle.label(column[0], 9, column[2] if color != SummaryStyle.LABEL_COLOR else SummaryStyle.LABEL_COLOR, false)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.custom_minimum_size.x = column[1]
		line.add_child(cell)
	return line


func _count_up(label: Label, value: float) -> void:
	counters[label] = [value, false]
