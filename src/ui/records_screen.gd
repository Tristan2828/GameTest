class_name RecordsScreen
extends ListScreen
## Title menu page: your best runs on this PC (RunRecords), for all heroes or
## one hero at a time.

const GOLD: Color = Color(0.95, 0.78, 0.4)
const VICTORY_COLOR: Color = Color(0.55, 0.9, 0.45)


func _ready() -> void:
	set_title("Records")
	add_tab("All heroes", _show.bind(-1))
	for character: int in Characters.ALL.size():
		add_tab(Characters.get_character(character).display_name, _show.bind(character))


func _show(character: int) -> void:
	clear_list()
	var entries := RunRecords.load_all()
	if character >= 0:
		entries = RunRecords.for_character(entries, character)
	if entries.is_empty():
		add_heading("No runs yet. Finish a run and it shows up here (best %d per hero)." % RunRecords.KEEP_PER_CHARACTER)
		return
	add_heading("Score: 10 per kill, 1 per 10 damage, 3000 per boss, 5000 for a victory, times the difficulty.")
	for rank: int in entries.size():
		_add_entry(rank, entries[rank])


func _add_entry(rank: int, entry: RunRecords.Entry) -> void:
	var stats := Characters.get_character(entry.character)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.add_child(label("#%d" % (rank + 1), 18, GOLD if rank == 0 else DIM_COLOR))
	var icon := SpriteIcon.new(stats.sprite, Vector2(28, 28))
	line.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(label("%s pts" % RunSummaryPanel.compact(entry.score), 9, GOLD))
	top.add_child(label(entry.result_text(), 9, VICTORY_COLOR if entry.victory else NAME_COLOR))
	top.add_child(label(stats.display_name, 9, TEXT_COLOR))
	text.add_child(top)
	var team := "solo" if entry.players <= 1 else "%d players" % entry.players
	text.add_child(label("%s   %d kills   %s damage   Lv %d   %s   %s   %s" % [
		RunStats.format_time(entry.seconds), entry.kills, RunSummaryPanel.compact(entry.damage), entry.level, team,
		entry.difficulty, entry.date], 9, DIM_COLOR, true))
	line.add_child(text)
	add_row(line)
