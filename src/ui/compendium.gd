class_name Compendium
extends ListScreen
## The title menu's "Game Guide" (called the Compendium until v0.18.0; the class
## keeps the old name): info pages on heroes, auto weapons, level-up upgrades, relics,
## pickups, map events and quests, enemies and bosses. Everything is read from the game's own data
## (Characters, AutoWeapons, Upgrades, Relics, EnemyTypes, Stages), so it stays
## correct when numbers are tuned.

const ICON_SIZE: Vector2 = Vector2(40, 34)
const HERO_COLOR: Color = Color(0.36, 0.78, 0.95)


func _ready() -> void:
	set_title("Game Guide")
	add_tab("Heroes", _show_heroes)
	add_tab("Weapons", _show_weapons)
	add_tab("Upgrades", _show_upgrades)
	add_tab("Relics", _show_relics)
	add_tab("Pickups", _show_pickups)
	add_tab("Events", _show_events)
	add_tab("Enemies", _show_enemies.bind(false))
	add_tab("Bosses", _show_enemies.bind(true))


## One entry: icon on the left, name, description and a dim stats line.
## Returns the text column so callers can add more lines.
func _entry(sprite: String, title: String, description: String, details: String,
		title_color: Color = NAME_COLOR, tint: Color = HERO_COLOR) -> VBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var icon := SpriteIcon.new(sprite, ICON_SIZE)
	icon.tint = tint
	line.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	text.add_child(label(title, 9, title_color))
	if not description.is_empty():
		text.add_child(label(description, 9, TEXT_COLOR, true))
	if not details.is_empty():
		text.add_child(label(details, 9, DIM_COLOR, true))
	line.add_child(text)
	add_row(line)
	return text


func _show_heroes() -> void:
	clear_list()
	for stats: CharacterStats in Characters.ALL:
		var text := _entry(stats.sprite, stats.full_name(), stats.blurb, hero_details(stats))
		text.add_child(label("Main weapon - %s: %s" % [stats.main_weapon_name, main_weapon_text(stats)], 9, TITLE_COLOR, true))
		text.add_child(label("Perk - %s: %s" % [stats.perk_name, stats.perk_description], 9, TITLE_COLOR, true))


static func hero_details(stats: CharacterStats) -> String:
	var count := ""
	if stats.projectile_count > 1:
		count = "  %s %d" % [Upgrades.COUNT_NAMES[stats.main_weapon], stats.projectile_count]
	return "HP %d   Speed %d   Damage %d   Attacks/s %.1f%s" % [
		stats.max_hp, roundi(stats.move_speed), stats.bullet_damage, 1.0 / stats.fire_interval, count]


## What the hero's main weapon does (it fires by itself; see AutoAim).
static func main_weapon_text(stats: CharacterStats) -> String:
	match stats.main_weapon:
		CharacterStats.MainWeapon.SCYTHE:
			return "Throws a scythe the way you face (your last move) and one behind you. They fly out and come back, cutting everything twice."
		CharacterStats.MainWeapon.LIGHTNING:
			return "Lightning strikes a random enemy near you, then leaps to the next ones."
		CharacterStats.MainWeapon.SPEARS:
			return "A row of bone spears bursts from the ground toward a random enemy near you, after a short warning."
	return "Fires a steady stream of bolts at the closest enemy."


func _show_weapons() -> void:
	clear_list()
	add_heading("On glowing altars (twice per stage) and in champions' chests. Taking one again levels it up (max %d). They fire on their own, next to your hero's main weapon." % AutoWeapons.MAX_LEVEL)
	for weapon_id: int in AutoWeapons.PICKUPS:
		var weapon := AutoWeapons.get_weapon(weapon_id)
		_entry(weapon.icon, weapon.title, weapon.description, weapon_details(weapon), weapon.color)


## "Lv 1: 8 dmg, 2 skulls   Lv 2: ..." for each level.
static func weapon_details(weapon: AutoWeapon) -> String:
	var parts := PackedStringArray()
	for level: int in range(1, AutoWeapons.MAX_LEVEL + 1):
		var text := "Lv %d: %d dmg" % [level, weapon.damage_at(level)]
		match weapon.kind:
			AutoWeapon.Kind.ORBIT:
				text += ", %d skulls" % weapon.count_at(level)
			AutoWeapon.Kind.SEEKER:
				text += ", %d bolts every %.1fs" % [weapon.count_at(level), weapon.interval_at(level)]
			AutoWeapon.Kind.AURA:
				text += " every %.1fs, radius %d" % [weapon.interval_at(level), roundi(weapon.radius_at(level))]
			AutoWeapon.Kind.CHAIN:
				text += ", %d jumps every %.1fs" % [weapon.count_at(level), weapon.interval_at(level)]
			AutoWeapon.Kind.BOOMERANG:
				text += ", %d scythe%s every %.1fs" % [weapon.count_at(level), "" if weapon.count_at(level) == 1 else "s", weapon.interval_at(level)]
			AutoWeapon.Kind.TRAIL:
				text += " every %.1fs, flames last %.0fs" % [weapon.interval_at(level), weapon.duration]
			AutoWeapon.Kind.ERUPTION:
				text += ", %d spears every %.1fs" % [weapon.count_at(level), weapon.interval_at(level)]
			AutoWeapon.Kind.BLAST:
				text += " every %.1fs, radius %d" % [weapon.interval_at(level), roundi(weapon.radius_at(level))]
			AutoWeapon.Kind.HEX:
				text = "Lv %d: every %.1fs, radius %d, %.0fs" % [level, weapon.interval_at(level), roundi(weapon.radius_at(level)),
					weapon.duration]
			AutoWeapon.Kind.EFFIGY:
				text += " burst every %.1fs, radius %d" % [weapon.interval_at(level), roundi(weapon.radius_at(level))]
		parts.append(text)
	return "   ".join(parts)


func _show_upgrades() -> void:
	clear_list()
	add_heading("Each level-up, every player picks 1 of 3. Squares on the card show how many you have.")
	for upgrade: Upgrade in Upgrades.ALL:
		if upgrade.retired:
			continue
		var limit := "No limit" if upgrade.max_stacks <= 0 else "Up to %d times" % upgrade.max_stacks
		if upgrade.stat == Upgrade.Stat.HEAL:
			limit = "Only offered when you're hurt"
		var hero := Upgrades.hero_text(upgrade)
		if not hero.is_empty():
			limit = "%s   %s" % [hero, limit]
		_entry(upgrade.icon, upgrade.title, upgrade.description, limit)


func _show_relics() -> void:
	clear_list()
	add_heading("Sold in the shop between stages. Each player sees their own offers; each relic can be bought once.")
	for relic: Relic in Relics.ALL:
		var details := "%d coins" % relic.price
		if relic.co_op_only:
			details += "   (co-op only)"
		_entry(relic.icon, relic.title, relic.description, details, TITLE_COLOR)


func _show_pickups() -> void:
	clear_list()
	_entry("gem", "XP gems", "Dropped by every enemy. Walk near to pull them in. They fill the shared team bar; each level-up, everyone picks an upgrade.",
		"Small / medium / big crystals are worth more XP.")
	_entry("coin", "Coins", "Some enemies drop coins. Whoever picks one up keeps it. Spend them in the shop between stages.",
		"Beating a boss also pays everyone a bounty.")
	_entry("icon_orbiting_skulls", "Weapon altars", "Appear twice per stage and show the weapon they hold. First player to touch one takes it.",
		"See the Weapons tab.")
	for kind: int in PowerUps.TITLES.size():
		_entry(PowerUps.SPRITES[kind], PowerUps.TITLES[kind], PowerUps.DESCRIPTIONS[kind],
			"Rare drop from enemies (at most one every %ds); champions always drop one. Whoever grabs it uses it." % roundi(PowerUps.DROP_COOLDOWN))
	_entry("wanderer", "Downed and revives", "At 0 HP you're downed: you lie in a circle and can't move or attack. A teammate standing in the circle revives you in %ds (faster with more helpers), with half your HP back." % roundi(Revive.SECONDS),
		"While down, your screen follows a teammate (Space / A switches). Everyone gets up at the next stage. The run ends when everyone is down.")


func _show_events() -> void:
	clear_list()
	add_heading("Events around the map. Edge arrows and blinking minimap squares point the way.")
	_entry("crown", "Champion lair", "A crowned champion sleeps somewhere in every stage and wakes when you come close. It's tough and shoots back. Beat it for coins, a power-up and a chest.",
		"Wakes within %d px. +%d%% HP per extra player." % [roundi(MapEvents.WAKE_RADIUS), roundi(EnemyTypes.get_type(EnemyTypes.Id.GHOUL_CHAMPION).hp_per_extra_player * 100.0)],
		MapEvents.CHAMPION_COLOR)
	_entry("chest", "Champion's chest", "First player to touch it gets an auto weapon they can still level up (or %d coins if they're all maxed)." % Arena.CHEST_COINS_WHEN_MAXED,
		"", MapEvents.CHEST_COLOR)
	_entry("icon_ritual", "Ritual circle", "Stand inside to start it. Enemies pour in while it fills; with nobody inside it slowly drains. When it's full: a ring of XP gems worth %d%% of a level, and everyone inside heals %d%% of their HP." % [roundi(Arena.RITUAL_XP_SHARE * 100.0), roundi(Arena.RITUAL_HEAL_SHARE * 100.0)],
		"%ds to fill. One is placed at the start of each stage, another pops up later and fades if nobody starts it." % roundi(MapEvents.RITUAL_SECONDS),
		MapEvents.RITUAL_COLOR)
	_entry("grave_robber", "Grave Robber", "A thief who runs from you, dropping stolen coins. Catch it within %ds for a shower of coins." % roundi(MapEvents.RUNNER_SECONDS),
		"Pops up twice per stage.", MapEvents.RUNNER_COLOR)
	add_heading("Quests: in the shop, each player picks 1 of 3 for the next stage (free). Finish it during that stage for the reward.")
	for quest_id: int in Quests.TITLES.size():
		var details := Quests.reward_text(quest_id)
		if Quests.CO_OP_ONLY[quest_id]:
			details += "   (co-op only)"
		_entry(Quests.ICONS[quest_id], Quests.TITLES[quest_id], Quests.description(quest_id), details, TITLE_COLOR)


## Regular enemies (or bosses), with where they appear.
func _show_enemies(bosses: bool) -> void:
	clear_list()
	if bosses:
		add_heading("HP shown for a solo run in the boss's own stage. Each extra player adds the % shown.")
	else:
		add_heading("HP shown for stage 1. In a full run, enemies have x%s HP in stage 2 and x%s in stage 3." % [
			str(Arena.ENEMY_HP_BY_DEPTH[1]), str(Arena.ENEMY_HP_BY_DEPTH[2])])
	for type_id: int in EnemyTypes.ALL.size():
		var type := EnemyTypes.get_type(type_id)
		if type.is_boss != bosses:
			continue
		var found := "Found in: %s" % ", ".join(stages_with(type_id))
		if type.is_elite:
			found = "Champion of %s (map event)" % ", ".join(stages_with(type_id))
		elif type.flees:
			found = "Every stage (map event)"
		_entry(type.sprite, type.display_name, enemy_details(type, boss_stage(type_id) if bosses else 1), found,
			Color(0.95, 0.45, 0.4) if bosses else NAME_COLOR)


## Stats line; HP as it is in stage `stage` (same growth as Arena._scaled_hp).
static func enemy_details(type: EnemyType, stage: int = 1) -> String:
	var hit_points := roundi(type.max_hp * Arena.hp_factor(type.is_boss, stage))
	var parts := PackedStringArray(["HP %d" % hit_points, "Speed %d" % roundi(type.move_speed), "XP %d" % type.xp_value])
	if type.shot_pattern >= 0 or type.is_boss:
		parts.append("Shoots bullets")
	if type.hp_per_extra_player > 0.0:
		parts.append("+%d%% HP per extra player" % roundi(type.hp_per_extra_player * 100.0))
	return "   ".join(parts)


## The stage number whose boss this is (1 if none).
static func boss_stage(type_id: int) -> int:
	for i: int in Stages.ALL.size():
		if Stages.ALL[i].boss_type == type_id:
			return i + 1
	return 1


## Stage titles whose spawn table or boss includes this enemy type.
static func stages_with(type_id: int) -> PackedStringArray:
	var titles := PackedStringArray()
	for stage: StageDef in Stages.ALL:
		var found := stage.boss_type == type_id or stage.pack_type == type_id or stage.champion_type == type_id
		for entry: SpawnEntry in stage.spawns:
			found = found or entry.enemy_type == type_id
		if found:
			titles.append(stage.title)
	return titles
