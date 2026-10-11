class_name RunConfig
extends RefCounted
## The host's lobby settings for the next run: difficulty sliders and custom
## game options. Pure data with limits, presets and a network encoding. The lobby
## sends it to every client, so all peers build the run from the same numbers.
## The host's last choice is saved in user://run_config.cfg.

const SAVE_PATH: String = "user://run_config.cfg"

## Name -> [min, max, step, default]. Multipliers are 1.0 = normal.
const LIMITS: Dictionary[String, Array] = {
	"enemy_health": [0.25, 3.0, 0.25, 1.0],
	"boss_health": [0.25, 3.0, 0.25, 1.0],
	"enemy_count": [0.25, 3.0, 0.25, 1.0],
	"xp_rate": [0.25, 3.0, 0.25, 1.0],
	"coin_rate": [0.0, 3.0, 0.25, 1.0],
	"hp_bonus": [-40, 60, 10, 0],
	"stage": [1, 3, 1, 1],
	"wave_seconds": [60.0, 600.0, 30.0, 240.0],
	"bonus_levels": [0, 10, 1, 0],
	"soundtrack": [0, 3, 1, 0],
}

## Difficulty presets (only the difficulty values; custom game options stay).
const PRESETS: Dictionary[String, Dictionary] = {
	"Easy": {"enemy_health": 0.75, "boss_health": 0.5, "enemy_count": 0.75, "xp_rate": 1.25, "coin_rate": 1.25, "hp_bonus": 20},
	"Normal": {"enemy_health": 1.0, "boss_health": 1.0, "enemy_count": 1.0, "xp_rate": 1.0, "coin_rate": 1.0, "hp_bonus": 0},
	"Hard": {"enemy_health": 1.5, "boss_health": 1.5, "enemy_count": 1.5, "xp_rate": 0.75, "coin_rate": 0.75, "hp_bonus": -20},
}

# --- Difficulty ---
## Regular enemy HP multiplier.
var enemy_health: float = 1.0
## Boss HP multiplier (on top of the per-player and per-stage scaling).
var boss_health: float = 1.0
## Spawn rate multiplier (how many enemies).
var enemy_count: float = 1.0
## Level-up speed: XP needed per level is divided by this.
var xp_rate: float = 1.0
## Coin drop chance multiplier.
var coin_rate: float = 1.0
## Extra (or less) max HP for every hero.
var hp_bonus: int = 0

# --- Custom game ---
## One stage (the chosen map) instead of the 3-stage run. Winning it is Victory.
var single_stage: bool = false
## Which map a single-stage game uses (1 Crypt, 2 Bone Marsh, 3 Burning Cathedral).
var stage: int = 1
## Horde time before the boss (or before the end, without a boss).
var wave_seconds: float = 240.0
## Off: the stage is won when the wave timer runs out instead.
var boss_enabled: bool = true
## Level-ups everyone picks right at the start.
var bonus_levels: int = 0
## Full arsenal: everyone starts with every weapon slot filled (5 random auto weapons at level 1).
var start_with_weapons: bool = false
## Music during the run (Tracks.SOUNDTRACKS index): classic, metal, ...
var soundtrack: int = 0
## Off: nobody's Ember Shrine boosts are used this run.
var ember_boosts: bool = true

const FLAGS: Array[String] = ["single_stage", "boss_enabled", "start_with_weapons", "ember_boosts"]

## Short names of the difficulty values, for summaries ("Enemy HP 150%").
const DIFFICULTY_NAMES: Dictionary[String, String] = {
	"enemy_health": "Enemy HP", "boss_health": "Boss HP", "enemy_count": "Enemies",
	"xp_rate": "XP", "coin_rate": "Coins", "hp_bonus": "Bonus HP",
}


## Sets a numeric setting, clamped and snapped to its slider step.
func set_value(key: String, value: float) -> void:
	var limits: Array = LIMITS[key]
	var snapped_value := clampf(snappedf(value, limits[2]), limits[0], limits[1])
	if typeof(get(key)) == TYPE_INT:
		set(key, roundi(snapped_value))
	else:
		set(key, snapped_value)


func apply_preset(preset_name: String) -> void:
	var preset: Dictionary = PRESETS.get(preset_name, PRESETS["Normal"])
	for key: String in preset:
		set_value(key, preset[key])


## "Easy", "Normal", "Hard" or "Custom" for the current difficulty values.
func difficulty_name() -> String:
	for preset_name: String in PRESETS:
		var matches := true
		for key: String in PRESETS[preset_name]:
			matches = matches and is_equal_approx(float(get(key)), float(PRESETS[preset_name][key]))
		if matches:
			return preset_name
	return "Custom"


## One difficulty value as shown to players: "150%" or "+20" / "-20" / "0".
func difficulty_value_text(key: String) -> String:
	if key == "hp_bonus":
		return "%+d" % hp_bonus if hp_bonus != 0 else "0"
	return "%d%%" % roundi(float(get(key)) * 100.0)


## True when this difficulty value isn't the Normal preset's.
func differs_from_normal(key: String) -> bool:
	return not is_equal_approx(float(get(key)), float(PRESETS["Normal"][key]))


## "Enemy HP 150%, XP 75%" for the values that differ from Normal (`every`:
## all six), or "" when none do.
func difficulty_details(every: bool = false) -> String:
	var parts := PackedStringArray()
	for key: String in DIFFICULTY_NAMES:
		if every or differs_from_normal(key):
			parts.append("%s %s" % [DIFFICULTY_NAMES[key], difficulty_value_text(key)])
	return ", ".join(parts)


## The run settings other than difficulty that change balance, e.g.
## "Single stage: The Crypt, 2:00 waves, +3 levels" ("" for a normal full run).
func custom_details() -> String:
	var parts := PackedStringArray()
	if single_stage:
		parts.append("Single stage: %s" % Stages.get_stage(stage).title)
	if not boss_enabled:
		parts.append("no boss")
	if not is_equal_approx(wave_seconds, float(LIMITS["wave_seconds"][3])):
		var whole := roundi(wave_seconds)
		parts.append("%d:%02d waves" % [whole / 60, whole % 60])
	if bonus_levels > 0:
		parts.append("+%d levels" % bonus_levels)
	if start_with_weapons:
		parts.append("full arsenal")
	if not ember_boosts:
		parts.append("no Ember boosts")
	return ", ".join(parts)


## Records: harder settings score more, easier ones less (1.0 = Normal).
func score_multiplier() -> float:
	var toughness := (enemy_health + boss_health + enemy_count) / 3.0
	toughness *= 1.0 - 0.005 * hp_bonus
	toughness *= 1.0 - 0.04 * bonus_levels
	toughness /= sqrt(maxf(xp_rate, 0.01))
	if start_with_weapons:
		toughness *= 0.7
	return clampf(toughness, 0.1, 5.0)


## How many stages this run has.
func stage_count() -> int:
	return 1 if single_stage else Stages.ALL.size()


## The first stage played.
func first_stage() -> int:
	return stage if single_stage else 1


## One line for the lobby, e.g. "Difficulty: Hard   Full run (3 stages)   4:00 waves".
func summary() -> String:
	var mode := "Full run (%d stages)" % Stages.ALL.size()
	if single_stage:
		mode = "Single stage: %s" % Stages.get_stage(stage).title
		if not boss_enabled:
			mode += " (no boss)"
	var whole := roundi(wave_seconds)
	var extras := ""
	if bonus_levels > 0:
		extras += "   +%d levels" % bonus_levels
	if start_with_weapons:
		extras += "   full arsenal"
	if not ember_boosts:
		extras += "   no Ember boosts"
	if soundtrack != 0:
		extras += "   %s music" % Tracks.SOUNDTRACKS[clampi(soundtrack, 0, Tracks.SOUNDTRACKS.size() - 1)]
	var difficulty := difficulty_name()
	if difficulty == "Custom":
		difficulty += " (%s)" % difficulty_details()
	return "Difficulty: %s   %s   %d:%02d waves%s" % [difficulty, mode, whole / 60, whole % 60, extras]


func to_dict() -> Dictionary:
	var data := {}
	for key: String in LIMITS:
		data[key] = get(key)
	for key: String in FLAGS:
		data[key] = get(key)
	return data


## Builds a config from untrusted data (network or file): unknown keys are
## ignored and every value is clamped to its limits.
static func from_dict(data: Dictionary) -> RunConfig:
	var config := RunConfig.new()
	for key: String in LIMITS:
		var value: Variant = data.get(key)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			config.set_value(key, float(value))
	for key: String in FLAGS:
		if typeof(data.get(key)) == TYPE_BOOL:
			config.set(key, data[key])
	return config


func duplicate_config() -> RunConfig:
	return RunConfig.from_dict(to_dict())


func save() -> void:
	var file := ConfigFile.new()
	var data := to_dict()
	for key: String in data:
		file.set_value("run", key, data[key])
	file.save(SAVE_PATH)


static func load_saved() -> RunConfig:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK or not file.has_section("run"):
		return RunConfig.new()
	var data := {}
	for key: String in file.get_section_keys("run"):
		data[key] = file.get_value("run", key)
	return RunConfig.from_dict(data)
