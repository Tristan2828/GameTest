class_name SummaryTeamPages
extends RefCounted
## The run summary's team pages: Stages (the team's numbers for each stage, for
## balancing) and Highlights (the team's standout moments: MVP, deadliest
## weapon, kill rate...). `highlights()` is pure and tested.


## Stages page: the team's numbers for each stage played, one row each, plus
## the run's totals. A bar under each row shows its share of the run's kills.
static func stages_card(stats: RunStats) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = SummaryStyle.WIDE_CARD
	card.add_theme_stylebox_override("panel", SummaryStyle.box(SummaryStyle.CARD_BG, SummaryStyle.DIVIDER_COLOR, 6))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	card.add_child(lines)
	if stats.stage_rows.is_empty():
		lines.add_child(SummaryStyle.label("No stage numbers for this run.", 9, SummaryStyle.LABEL_COLOR, true))
		return card
	var widths: Array[int] = [130, 36, 44, 40, 48, 34, 34, 40, 36, 54]
	lines.add_child(_table_row(["Stage", "Time", "Boss", "Kills", "Dmg taken", "Downs", "Level", "Events", "Peak", "Result"],
		widths, SummaryStyle.LABEL_COLOR, []))
	lines.add_child(SummaryStyle.divider())
	var total_kills := 0
	for row: PackedInt32Array in stats.stage_rows:
		total_kills += row[RunStats.StageField.KILLS]
	var totals: Array[int] = [0, 0, 0, 0, 0]  # seconds, kills, hp lost, downs, events
	for i: int in stats.stage_rows.size():
		var row := stats.stage_rows[i]
		var stage := Stages.get_stage(row[RunStats.StageField.MAP])
		var cleared := row[RunStats.StageField.CLEARED] == 1
		var boss_seconds := row[RunStats.StageField.BOSS_SECONDS]
		var cells: Array[String] = ["%d. %s" % [i + 1, stage.title], RunStats.format_time(row[RunStats.StageField.SECONDS]),
			RunStats.format_time(boss_seconds) if boss_seconds >= 0 else "-", SummaryStyle.compact(row[RunStats.StageField.KILLS]),
			SummaryStyle.compact(row[RunStats.StageField.HP_LOST]), str(row[RunStats.StageField.DOWNS]),
			str(row[RunStats.StageField.LEVEL]), str(row[RunStats.StageField.EVENTS]), str(row[RunStats.StageField.PEAK_ENEMIES]),
			"Cleared" if cleared else "Fell"]
		var colors: Array[Color] = []
		colors.resize(cells.size())
		colors.fill(SummaryStyle.VALUE_COLOR)
		colors[cells.size() - 1] = SummaryStyle.GOOD_COLOR if cleared else SummaryStyle.DEFEAT_COLOR
		var line := _table_row(cells, widths, SummaryStyle.VALUE_COLOR, colors)
		line.tooltip_text = "%s\nTime %s (boss fight %s)\n%d kills, %d damage taken, %d downs\nTeam level %d at the end\n%d events done (champions, rituals, thieves)\nUp to %d enemies at once" % [
			stage.title, cells[1], cells[2], row[RunStats.StageField.KILLS], row[RunStats.StageField.HP_LOST],
			row[RunStats.StageField.DOWNS], row[RunStats.StageField.LEVEL], row[RunStats.StageField.EVENTS],
			row[RunStats.StageField.PEAK_ENEMIES]]
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		lines.add_child(line)
		lines.add_child(SummaryStyle.share_bar(float(row[RunStats.StageField.KILLS]) / maxf(total_kills, 1.0),
			SummaryStyle.WIDE_CARD - SummaryStyle.CARD_INSET))
		totals[0] += row[RunStats.StageField.SECONDS]
		totals[1] += row[RunStats.StageField.KILLS]
		totals[2] += row[RunStats.StageField.HP_LOST]
		totals[3] += row[RunStats.StageField.DOWNS]
		totals[4] += row[RunStats.StageField.EVENTS]
	lines.add_child(SummaryStyle.divider())
	lines.add_child(_table_row(["Run", RunStats.format_time(totals[0]), "", SummaryStyle.compact(totals[1]),
		SummaryStyle.compact(totals[2]), str(totals[3]), str(stats.team_level), str(totals[4]), "",
		"VICTORY" if stats.victory else ""], widths, SummaryStyle.AWARD_COLOR, []))
	var note := SummaryStyle.label("Time counts only play (not level-ups or the shop). Boss = how long the boss fight took. Peak = most enemies alive at once.",
		9, SummaryStyle.LABEL_COLOR, false)
	lines.add_child(SummaryStyle.wrapped(note, SummaryStyle.WIDE_CARD - SummaryStyle.CARD_INSET))
	return card


## Highlights page: the team's standout numbers, one line each.
static func highlights_card(stats: RunStats, players: Array[Player], multiplier: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 460
	card.add_theme_stylebox_override("panel", SummaryStyle.box(SummaryStyle.CARD_BG, SummaryStyle.DIVIDER_COLOR, 8))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	card.add_child(lines)
	for entry: Array in highlights(stats, players, multiplier):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var icon := SpriteIcon.new(entry[0], Vector2(12, 11))
		icon.max_scale = 1
		icon.tint = entry[3]
		line.add_child(icon)
		var title := SummaryStyle.label(entry[1], 9, SummaryStyle.LABEL_COLOR, false)
		title.custom_minimum_size.x = 110
		line.add_child(title)
		var value := SummaryStyle.clipped(SummaryStyle.label(entry[2], 9, entry[3], false))
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.tooltip_text = entry[2]
		value.mouse_filter = Control.MOUSE_FILTER_PASS
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
		return Player.SLOT_COLORS[by_id[peer_id].slot % Player.SLOT_COLORS.size()] if by_id.has(peer_id) else SummaryStyle.VALUE_COLOR
	var co_op := stats.by_peer.size() > 1

	# MVP (co-op) or your score (solo).
	var best_id := -1
	var best_score := -1
	for peer_id: int in stats.by_peer:
		var score := SummaryPlayerCards.score_of(stats, peer_id, multiplier)
		if score > best_score:
			best_score = score
			best_id = peer_id
	if best_id >= 0:
		if co_op:
			result.append(["crown", "MVP", "%s  -  %d score" % [name_of.call(best_id), best_score], color_of.call(best_id)])
		else:
			result.append(["star", "Score", "%d" % best_score, SummaryStyle.AWARD_COLOR])

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
			weapon, SummaryStyle.compact(top[1]), top[2]], SummaryStyle.AWARD_COLOR])

	# Kill rate and the team's haul.
	var kills := stats.total(RunStats.Stat.KILLS)
	var minutes := maxf(stats.run_seconds / 60.0, 1.0 / 60.0)
	result.append(["skull", "Kill rate", "%d kills a minute (%d in all)" % [roundi(kills / minutes), kills], SummaryStyle.VALUE_COLOR])
	result.append(["coin", "Coins earned", "%d" % stats.total(RunStats.Stat.COINS_EARNED), Color(0.95, 0.85, 0.4)])
	result.append(["gem_big", "XP gathered", "%d  (team level %d)" % [stats.total(RunStats.Stat.XP_GATHERED), stats.team_level],
		Color(0.7, 0.55, 1.0)])

	# Stages: the quickest boss kill and the map events done.
	var fastest := -1
	var fastest_stage := ""
	var events := 0
	for row: PackedInt32Array in stats.stage_rows:
		events += row[RunStats.StageField.EVENTS]
		var boss_seconds := row[RunStats.StageField.BOSS_SECONDS]
		if row[RunStats.StageField.CLEARED] == 1 and boss_seconds >= 0 and (fastest < 0 or boss_seconds < fastest):
			fastest = boss_seconds
			fastest_stage = Stages.get_stage(row[RunStats.StageField.MAP]).title
	if fastest >= 0:
		result.append(["crown", "Fastest boss kill", "%s  (%s)" % [RunStats.format_time(fastest), fastest_stage], SummaryStyle.VICTORY_COLOR])
	if not stats.stage_rows.is_empty():
		result.append(["icon_ritual", "Map events", "%d done (champions, rituals, thieves)" % events, Color(0.75, 0.5, 1.0)])
	var extras := PackedStringArray()
	for entry: Array in [[RunStats.Stat.POWER_UPS, "power-up"], [RunStats.Stat.CHESTS, "chest"],
			[RunStats.Stat.QUESTS, "quest"], [RunStats.Stat.EVOLUTIONS, "evolution"]]:
		var amount := stats.total(entry[0])
		if amount > 0:
			extras.append("%d %s%s" % [amount, entry[1], "" if amount == 1 else "s"])
	if not extras.is_empty():
		result.append(["chest", "Loot", ", ".join(extras), Color(1.0, 0.9, 0.5)])

	if co_op:
		for entry: Array in [[RunStats.Stat.KILLS, "Most kills", "skull"], [RunStats.Stat.BOSS_DAMAGE, "Boss slayer", "crown"],
				[RunStats.Stat.REVIVES, "Lifesaver", "pickup_heart"], [RunStats.Stat.HP_LOST, "Untouchable", "star"],
				[RunStats.Stat.POWER_UPS, "Scavenger", "pickup_magnet"], [RunStats.Stat.CHESTS, "Treasure hunter", "chest"]]:
			var stat: RunStats.Stat = entry[0]
			var leader := stats.best(stat)
			if leader < 0:
				continue
			var detail := "%d" % stats.get_stat(leader, stat)
			if stat == RunStats.Stat.HP_LOST:
				var lost := stats.get_stat(leader, stat)
				detail = "not a scratch!" if lost == 0 else "only %d damage taken" % lost
			result.append([entry[2], entry[1], "%s  -  %s" % [name_of.call(leader), detail], color_of.call(leader)])
	else:
		var lost := stats.total(RunStats.Stat.HP_LOST)
		result.append(["pickup_heart", "Damage taken", "%d" % lost if lost > 0 else "none! Flawless.", Color(0.95, 0.45, 0.5)])
	return result


## One row of the Stages table: the first cell left-aligned (clipped), the rest
## right-aligned in fixed widths.
static func _table_row(cells: Array[String], widths: Array[int], color: Color, colors: Array[Color]) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 2)
	for i: int in cells.size():
		var cell := SummaryStyle.label(cells[i], 9, colors[i] if i < colors.size() else color, false)
		cell.custom_minimum_size.x = widths[i]
		if i == 0:
			SummaryStyle.clipped(cell)
		else:
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(cell)
	return line
