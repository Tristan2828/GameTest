class_name RunRecords
extends RefCounted
## Your best runs, kept on this PC (user://records.cfg, in %APPDATA%). At the
## end of every real run each player's game saves its own result; the title
## menu's Records page shows the best runs per hero.
##
## Score = 10 per kill + 1 per 10 damage + 3000 per boss + 5000 for a victory,
## times the difficulty (enemy/boss health and enemy count; easier custom
## settings lower it).

const PATH: String = "user://records.cfg"
## Runs kept per hero.
const KEEP_PER_CHARACTER: int = 10

## Where records are saved (tests point it elsewhere).
static var path: String = PATH


## One finished run, as stored.
class Entry:
	var character: int = 0
	var score: int = 0
	var victory: bool = false
	## How far into the run the last stage was, and the run's length.
	var stage: int = 1
	var stage_count: int = 3
	var map_title: String = ""
	var bosses: int = 0
	var seconds: float = 0.0
	var kills: int = 0
	var damage: int = 0
	var level: int = 1
	var players: int = 1
	var difficulty: String = "Normal"
	var date: String = ""

	func to_dict() -> Dictionary:
		return {
			"character": character, "score": score, "victory": victory, "stage": stage, "stage_count": stage_count,
			"map": map_title, "bosses": bosses, "seconds": seconds, "kills": kills, "damage": damage,
			"level": level, "players": players, "difficulty": difficulty, "date": date,
		}

	static func from_dict(data: Dictionary) -> Entry:
		var entry := Entry.new()
		entry.character = int(data.get("character", 0))
		entry.score = int(data.get("score", 0))
		entry.victory = bool(data.get("victory", false))
		entry.stage = int(data.get("stage", 1))
		entry.stage_count = int(data.get("stage_count", 3))
		entry.map_title = str(data.get("map", ""))
		entry.bosses = int(data.get("bosses", 0))
		entry.seconds = float(data.get("seconds", 0.0))
		entry.kills = int(data.get("kills", 0))
		entry.damage = int(data.get("damage", 0))
		entry.level = int(data.get("level", 1))
		entry.players = int(data.get("players", 1))
		entry.difficulty = str(data.get("difficulty", "Normal"))
		entry.date = str(data.get("date", ""))
		return entry

	## "Victory" or "Stage 2/3: The Bone Marsh".
	func result_text() -> String:
		if victory:
			return "Victory" if stage_count > 1 else "Victory (%s)" % map_title
		return "Stage %d/%d: %s" % [stage, stage_count, map_title]


## The score for these numbers (see the class comment).
static func score_for(kills: int, damage: int, bosses: int, victory: bool, multiplier: float) -> int:
	var base := kills * 10 + damage / 10 + bosses * 3000 + (5000 if victory else 0)
	return roundi(base * multiplier)


## Builds this player's entry from the end-of-run numbers.
static func entry_for(stats: RunStats, peer_id: int, character: int, config: RunConfig, stage_in_run: int,
		map_title: String, player_count: int) -> Entry:
	var entry := Entry.new()
	entry.character = character
	entry.victory = stats.victory
	entry.stage = stage_in_run
	entry.stage_count = config.stage_count()
	entry.map_title = map_title
	entry.bosses = stats.bosses_defeated
	entry.seconds = stats.run_seconds
	entry.kills = stats.get_stat(peer_id, RunStats.Stat.KILLS)
	entry.damage = stats.get_stat(peer_id, RunStats.Stat.DAMAGE)
	entry.level = stats.team_level
	entry.players = player_count
	entry.difficulty = config.difficulty_name()
	entry.date = Time.get_date_string_from_system()
	entry.score = score_for(entry.kills, entry.damage, entry.bosses, entry.victory, config.score_multiplier())
	return entry


## Every saved run, best first.
static func load_all() -> Array[Entry]:
	var result: Array[Entry] = []
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return result
	for data: Variant in file.get_value("records", "runs", []):
		if data is Dictionary:
			result.append(Entry.from_dict(data))
	_sort(result)
	return result


## The saved runs for one hero, best first.
static func for_character(entries: Array[Entry], character: int) -> Array[Entry]:
	var result: Array[Entry] = []
	for entry: Entry in entries:
		if entry.character == character:
			result.append(entry)
	return result


## Saves a run and returns its rank among this hero's runs (0 = new best), or
## -1 if it didn't make the list.
static func add(entry: Entry) -> int:
	var entries := load_all()
	entries.append(entry)
	_sort(entries)
	# Keep the best few per hero.
	var kept: Array[Entry] = []
	var counts: Dictionary[int, int] = {}
	for saved: Entry in entries:
		counts[saved.character] = counts.get(saved.character, 0) + 1
		if counts[saved.character] <= KEEP_PER_CHARACTER:
			kept.append(saved)
	var runs: Array[Dictionary] = []
	for saved: Entry in kept:
		runs.append(saved.to_dict())
	var file := ConfigFile.new()
	file.set_value("records", "runs", runs)
	file.save(path)
	return for_character(kept, entry.character).find(entry)


static func _sort(entries: Array[Entry]) -> void:
	entries.sort_custom(func(a: Entry, b: Entry) -> bool: return a.score > b.score)
