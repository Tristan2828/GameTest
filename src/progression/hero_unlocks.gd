class_name HeroUnlocks
extends RefCounted
## Heroes unlock one at a time (owner request after v0.24.0): everyone starts
## with Kael the Wanderer, and winning a full run as a hero unlocks the next one
## in `Characters.ALL` order (Kael -> Mortimer -> Morwen -> Vesper). Kept on this
## PC (user://unlocks.cfg, like Records): in co-op each player picks from their
## own unlocks, and a team win counts for everyone on the team.
## A single-stage custom game doesn't count; easier difficulties do.
## Automated runs (autopilot) have every hero.

const PATH: String = "user://unlocks.cfg"
## Heroes open from the start (the first N of Characters.ALL).
const STARTING: int = 1

## Where unlocks are saved (tests point it elsewhere).
static var path: String = PATH
## Test aid: ignore LaunchOptions.autopilot (tests may run under it).
static var ignore_autopilot: bool = false


## How many heroes are open (the first N of Characters.ALL).
static func unlocked_count() -> int:
	var file := ConfigFile.new()
	var saved := STARTING
	if file.load(path) == OK:
		saved = int(file.get_value("heroes", "unlocked", STARTING))
	return clampi(saved, STARTING, Characters.ALL.size())


static func is_unlocked(character_id: int) -> bool:
	if LaunchOptions.autopilot and not ignore_autopilot:
		return true
	return character_id < unlocked_count()


## Whether a finished run unlocks anything (a victory over a full run).
static func run_counts(victory: bool, config: RunConfig) -> bool:
	return victory and not config.single_stage


## A run won as this hero: unlocks the next one. Returns the newly unlocked
## hero's id, or -1 (already open, or the last hero).
static func record_win(character_id: int) -> int:
	var next := character_id + 1
	if not Characters.is_valid_id(next) or next < unlocked_count():
		return -1
	var file := ConfigFile.new()
	file.load(path)  # A missing file is fine: it's created.
	file.set_value("heroes", "unlocked", next + 1)
	file.save(path)
	return next


## Shown on a locked hero: what unlocks it.
static func hint(character_id: int) -> String:
	if character_id <= 0:
		return ""
	return "Win a run as %s to unlock" % Characters.get_character(character_id - 1).hero_name
