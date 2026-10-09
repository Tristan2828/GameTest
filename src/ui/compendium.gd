class_name Compendium
extends ListScreen
## The title menu's info pages: heroes, auto weapons, level-up upgrades, relics,
## pickups, enemies and bosses. Everything is read from the game's own data
## (Characters, AutoWeapons, Upgrades, Relics, EnemyTypes, Stages), so it stays
## correct when numbers are tuned.

const ICON_SIZE: Vector2 = Vector2(40, 34)
const HERO_COLOR: Color = Color(0.36, 0.78, 0.95)


func _ready() -> void:
	set_title("Compendium")
	add_tab("Heroes", _show_heroes)
	add_tab("Weapons", _show_weapons)
	add_tab("Upgrades", _show_upgrades)
	add_tab("Relics", _show_relics)
	add_tab("Pickups", _show_pickups)
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
		var text := _entry(stats.sprite, stats.display_name, stats.blurb, hero_details(stats))
		text.add_child(label("Ability - %s: %s" % [stats.ability_name, stats.ability_description], 9, TITLE_COLOR, true))


static func hero_details(stats: CharacterStats) -> String:
	var bolts := "" if stats.projectile_count <= 1 else "  Bolts %d" % stats.projectile_count
	return "Hearts %d   Speed %d   Damage %d   Shots/s %.1f%s   Ability cooldown %.1fs" % [
		stats.max_hearts, roundi(stats.move_speed), stats.bullet_damage, 1.0 / stats.fire_interval, bolts,
		stats.ability_cooldown]


func _show_weapons() -> void:
	clear_list()
	add_heading("Found on glowing altars twice per stage. Touch one to take it; taking it again levels it up (max %d)." % AutoWeapons.MAX_LEVEL)
	for weapon: AutoWeapon in AutoWeapons.ALL:
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
		parts.append(text)
	return "   ".join(parts)


func _show_upgrades() -> void:
	clear_list()
	add_heading("Each level-up, every player picks 1 of 3. Squares on the card show how many you have.")
	for upgrade: Upgrade in Upgrades.ALL:
		var limit := "No limit" if upgrade.max_stacks <= 0 else "Up to %d times" % upgrade.max_stacks
		if upgrade.stat == Upgrade.Stat.HEAL:
			limit = "Only offered when you're hurt"
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
	_entry("wanderer", "Downed and revives", "At 0 hearts you're downed: you lie in a circle and can't move or shoot. A teammate standing in the circle revives you in %ds (faster with more helpers), with half your hearts back." % roundi(Revive.SECONDS),
		"While down, your screen follows a teammate (Fire / Ability switches). Everyone gets up at the next stage. The run ends when everyone is down.")


## Regular enemies (or bosses), with where they appear.
func _show_enemies(bosses: bool) -> void:
	clear_list()
	if bosses:
		add_heading("HP shown for a solo run in the boss's own stage. Each extra player adds the % shown.")
	else:
		add_heading("HP shown for stage 1. Every enemy gets +%d%% HP in each later stage." % roundi(Arena.STAGE_HP_GROWTH * 100.0))
	for type_id: int in EnemyTypes.ALL.size():
		var type := EnemyTypes.get_type(type_id)
		if type.is_boss != bosses:
			continue
		_entry(type.sprite, type.display_name, enemy_details(type, boss_stage(type_id) if bosses else 1),
			"Found in: %s" % ", ".join(stages_with(type_id)),
			Color(0.95, 0.45, 0.4) if bosses else NAME_COLOR)


## Stats line; HP as it is in stage `stage` (same growth as Arena._scaled_hp).
static func enemy_details(type: EnemyType, stage: int = 1) -> String:
	var hit_points := roundi(type.max_hp * (1.0 + Arena.STAGE_HP_GROWTH * (stage - 1)))
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
		var found := stage.boss_type == type_id or stage.pack_type == type_id
		for entry: SpawnEntry in stage.spawns:
			found = found or entry.enemy_type == type_id
		if found:
			titles.append(stage.title)
	return titles
