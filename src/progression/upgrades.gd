class_name Upgrades
extends RefCounted
## Registry of level-up upgrades, plus the rules for rolling and applying them.
## The index in ALL is the id sent over the network: only add new ones at the end.

const CHOICES_PER_LEVEL: int = 3
## Homing turn rate one Hunting Bolts pick adds (radians per second); cards count picks.
const HOMING_STEP: float = 2.5
## What "+1" counts for each main weapon (CharacterStats.MainWeapon) on cards.
const COUNT_NAMES: Array[String] = ["Bolts", "Scythes", "Jumps", "Spears"]

const ALL: Array[Upgrade] = [
	preload("res://src/progression/upgrades/sharpened_bolts.tres"),
	preload("res://src/progression/upgrades/quick_hands.tres"),
	preload("res://src/progression/upgrades/fleet_foot.tres"),
	preload("res://src/progression/upgrades/heart_container.tres"),
	preload("res://src/progression/upgrades/extra_bolt.tres"),
	preload("res://src/progression/upgrades/piercing_bolts.tres"),
	preload("res://src/progression/upgrades/grave_magnet.tres"),
	preload("res://src/progression/upgrades/shadow_step.tres"),
	preload("res://src/progression/upgrades/blood_draught.tres"),
	preload("res://src/progression/upgrades/long_shot.tres"),
	preload("res://src/progression/upgrades/steady_nerves.tres"),
	preload("res://src/progression/upgrades/swift_bolts.tres"),
	preload("res://src/progression/upgrades/arcane_focus.tres"),
	preload("res://src/progression/upgrades/keen_edge.tres"),
	preload("res://src/progression/upgrades/corpse_blast.tres"),
	preload("res://src/progression/upgrades/giant_slayer.tres"),
	preload("res://src/progression/upgrades/executioner.tres"),
	preload("res://src/progression/upgrades/ricochet.tres"),
	preload("res://src/progression/upgrades/hunting_bolts.tres"),
	preload("res://src/progression/upgrades/glass_cannon.tres"),
	preload("res://src/progression/upgrades/reckless_haste.tres"),
	preload("res://src/progression/upgrades/afterimage.tres"),
	preload("res://src/progression/upgrades/hallowed_blast.tres"),
	preload("res://src/progression/upgrades/deep_hex.tres"),
	preload("res://src/progression/upgrades/ossuary.tres"),
	preload("res://src/progression/upgrades/twin_scythes.tres"),
	preload("res://src/progression/upgrades/long_reach.tres"),
	preload("res://src/progression/upgrades/heavy_blade.tres"),
	preload("res://src/progression/upgrades/grim_harvest.tres"),
	preload("res://src/progression/upgrades/forked_lightning.tres"),
	preload("res://src/progression/upgrades/long_arc.tres"),
	preload("res://src/progression/upgrades/conductor.tres"),
	preload("res://src/progression/upgrades/split_bolt.tres"),
	preload("res://src/progression/upgrades/longer_row.tres"),
	preload("res://src/progression/upgrades/wide_spikes.tres"),
	preload("res://src/progression/upgrades/quick_rise.tres"),
	preload("res://src/progression/upgrades/splinters.tres"),
]


static func get_upgrade(id: int) -> Upgrade:
	return ALL[clampi(id, 0, ALL.size() - 1)]


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < ALL.size()


## Rolls up to CHOICES_PER_LEVEL different upgrade ids. Skips maxed-out ones,
## only offers healing to a player who is missing hearts, hero-only and
## weapon-only upgrades to that hero (`stats`; none without it), and never a
## max-heart cut at 1 max heart.
static func roll(rng: RandomNumberGenerator, owned: Array[int], is_hurt: bool,
		stats: CharacterStats = null) -> Array[int]:
	var pool: Array[int] = []
	for id: int in ALL.size():
		if is_offered(ALL[id], owned.count(id), is_hurt, stats):
			pool.append(id)
	var result: Array[int] = []
	while not pool.is_empty() and result.size() < CHOICES_PER_LEVEL:
		result.append(pool.pop_at(rng.randi() % pool.size()))
	return result


static func is_offered(upgrade: Upgrade, stacks: int, is_hurt: bool, stats: CharacterStats) -> bool:
	if upgrade.stat == Upgrade.Stat.HEAL and not is_hurt:
		return false
	if upgrade.max_stacks > 0 and stacks >= upgrade.max_stacks:
		return false
	if upgrade.for_ability >= 0 and (stats == null or stats.ability != upgrade.for_ability):
		return false
	if upgrade.for_weapon >= 0 and (stats == null or stats.main_weapon != upgrade.for_weapon):
		return false
	if stats != null and stats.max_hearts <= 1:
		for effect: Upgrade in effects_of(upgrade):
			if effect.stat == Upgrade.Stat.MAX_HEARTS and effect.amount < 0.0:
				return false
	return true


## The upgrade's own effect followed by its extra effects.
static func effects_of(upgrade: Upgrade) -> Array[Upgrade]:
	var effects: Array[Upgrade] = [upgrade]
	for extra: Resource in upgrade.extra_effects:
		effects.append(extra as Upgrade)
	return effects


## "Wanderer only" for hero and weapon upgrades (empty for everyone's).
static func hero_text(upgrade: Upgrade) -> String:
	if upgrade.for_ability < 0 and upgrade.for_weapon < 0:
		return ""
	for character: CharacterStats in Characters.ALL:
		if character.ability == upgrade.for_ability or character.main_weapon == upgrade.for_weapon:
			return "%s only" % character.display_name
	return ""


## Applies a level-up upgrade to one player's stats (and health). Every peer runs
## this for every upgrade, so all copies of a player's stats stay identical.
static func apply(id: int, stats: CharacterStats, health: PlayerHealth) -> void:
	apply_effect(get_upgrade(id), stats, health)


## Applies one upgrade or relic effect, including its extra effects.
static func apply_effect(upgrade: Upgrade, stats: CharacterStats, health: PlayerHealth) -> void:
	for effect: Upgrade in effects_of(upgrade):
		_apply_stat(effect, stats, health)


static func _apply_stat(upgrade: Upgrade, stats: CharacterStats, health: PlayerHealth) -> void:
	match upgrade.stat:
		Upgrade.Stat.DAMAGE:
			stats.bullet_damage += int(upgrade.amount)
		Upgrade.Stat.FIRE_RATE:
			stats.fire_interval *= 1.0 - upgrade.amount
		Upgrade.Stat.MOVE_SPEED:
			stats.move_speed *= 1.0 + upgrade.amount
		Upgrade.Stat.MAX_HEARTS:
			stats.max_hearts = maxi(stats.max_hearts + int(upgrade.amount), 1)
			health.max_hearts = stats.max_hearts
			if upgrade.amount > 0.0:
				health.heal(int(upgrade.amount))
			else:
				health.hearts = mini(health.hearts, health.max_hearts)
		Upgrade.Stat.EXTRA_BOLT:
			stats.projectile_count += int(upgrade.amount)
		Upgrade.Stat.PIERCE:
			stats.pierce += int(upgrade.amount)
		Upgrade.Stat.PICKUP_RADIUS:
			stats.pickup_radius *= 1.0 + upgrade.amount
		Upgrade.Stat.ABILITY_COOLDOWN:
			stats.ability_cooldown *= 1.0 - upgrade.amount
		Upgrade.Stat.HEAL:
			health.heal(int(upgrade.amount))
		Upgrade.Stat.ABILITY_POWER:
			stats.ability_power *= 1.0 + upgrade.amount
		Upgrade.Stat.BULLET_SPEED:
			stats.bullet_speed *= 1.0 + upgrade.amount
		Upgrade.Stat.KILL_HEAL:
			stats.heal_every_kills = int(upgrade.amount)
		Upgrade.Stat.REVIVE_SPEED:
			stats.revive_speed *= 1.0 + upgrade.amount
		Upgrade.Stat.BULLET_RANGE:
			stats.bullet_lifetime *= 1.0 + upgrade.amount
		Upgrade.Stat.HIT_INVULNERABILITY:
			stats.hit_invulnerability = maxf(stats.hit_invulnerability + upgrade.amount, 0.1)
		Upgrade.Stat.CRIT_CHANCE:
			stats.crit_chance = clampf(stats.crit_chance + upgrade.amount, 0.0, 1.0)
		Upgrade.Stat.KILL_BURST:
			stats.kill_burst_damage += int(upgrade.amount)
		Upgrade.Stat.BOSS_DAMAGE:
			stats.boss_damage_bonus += upgrade.amount
		Upgrade.Stat.WOUNDED_DAMAGE:
			stats.wounded_damage_bonus += upgrade.amount
		Upgrade.Stat.RICOCHET:
			stats.ricochet += int(upgrade.amount)
		Upgrade.Stat.HOMING:
			stats.homing += upgrade.amount
		Upgrade.Stat.DASH_GRACE:
			stats.dash_grace += upgrade.amount
		Upgrade.Stat.BLAST_DAMAGE:
			stats.blast_damage = roundi(stats.blast_damage * (1.0 + upgrade.amount))
		Upgrade.Stat.BLAST_HEAL:
			stats.blast_heal += int(upgrade.amount)
		Upgrade.Stat.HEX_DURATION:
			stats.hex_duration += upgrade.amount
		Upgrade.Stat.HEX_DAMAGE:
			stats.hex_damage_multiplier += upgrade.amount
		Upgrade.Stat.EFFIGY_DURATION:
			stats.effigy_duration += upgrade.amount
		Upgrade.Stat.EFFIGY_BURST:
			stats.effigy_burst_damage = roundi(stats.effigy_burst_damage * (1.0 + upgrade.amount))
		Upgrade.Stat.WEAPON_REACH:
			stats.weapon_reach *= 1.0 + upgrade.amount
		Upgrade.Stat.WEAPON_SIZE:
			stats.weapon_radius *= 1.0 + upgrade.amount
		Upgrade.Stat.WEAPON_DELAY:
			stats.weapon_duration *= 1.0 - upgrade.amount
		Upgrade.Stat.CHAIN_GROWTH:
			stats.chain_damage_growth += upgrade.amount
		Upgrade.Stat.CHAIN_FORK:
			stats.chain_forks += int(upgrade.amount)
		Upgrade.Stat.SCYTHE_CUTS:
			stats.scythe_cuts += int(upgrade.amount)
		Upgrade.Stat.SPEAR_SHARDS:
			stats.spear_shards += int(upgrade.amount)


## How many times this player already took this upgrade.
static func stacks_owned(id: int, owned: Array[int]) -> int:
	return owned.count(id)


## Card line like "Lv 2 -> 3 of 5" (empty for one-off effects like healing).
static func level_text(id: int, owned: Array[int]) -> String:
	var upgrade := get_upgrade(id)
	if upgrade.stat == Upgrade.Stat.HEAL:
		return ""
	var have := stacks_owned(id, owned)
	var text := "Lv %d -> %d" % [have, have + 1]
	if upgrade.max_stacks > 0:
		text += " of %d" % upgrade.max_stacks
	return text


## Card line with the player's real stat now and after taking it, e.g.
## "Damage 13 -> 16" (one line per effect). Applies the upgrade to copies, so
## it uses the same math.
static func preview_text(id: int, stats: CharacterStats, health: PlayerHealth) -> String:
	var upgrade := get_upgrade(id)
	var after_stats := stats.duplicate() as CharacterStats
	var after_health := PlayerHealth.new()
	after_health.max_hearts = health.max_hearts
	after_health.hearts = health.hearts
	apply_effect(upgrade, after_stats, after_health)
	var lines: PackedStringArray = []
	for effect: Upgrade in effects_of(upgrade):
		lines.append(_stat_preview(effect.stat, stats, after_stats, health, after_health))
	return "\n".join(lines)


static func _stat_preview(stat: Upgrade.Stat, stats: CharacterStats, after_stats: CharacterStats,
		health: PlayerHealth, after_health: PlayerHealth) -> String:
	match stat:
		Upgrade.Stat.DAMAGE:
			return "Damage %d -> %d" % [stats.bullet_damage, after_stats.bullet_damage]
		Upgrade.Stat.FIRE_RATE:
			var rate_name := "Shots/s" if stats.main_weapon == CharacterStats.MainWeapon.BOLTS else "Attacks/s"
			return "%s %.1f -> %.1f" % [rate_name, 1.0 / stats.fire_interval, 1.0 / after_stats.fire_interval]
		Upgrade.Stat.MOVE_SPEED:
			return "Speed %d -> %d" % [roundi(stats.move_speed), roundi(after_stats.move_speed)]
		Upgrade.Stat.MAX_HEARTS:
			return "Max hearts %d -> %d" % [stats.max_hearts, after_stats.max_hearts]
		Upgrade.Stat.EXTRA_BOLT:
			return "%s %d -> %d" % [COUNT_NAMES[stats.main_weapon], stats.projectile_count, after_stats.projectile_count]
		Upgrade.Stat.PIERCE:
			return "Pierce %d -> %d" % [stats.pierce, after_stats.pierce]
		Upgrade.Stat.PICKUP_RADIUS:
			return "Range %d -> %d" % [roundi(stats.pickup_radius), roundi(after_stats.pickup_radius)]
		Upgrade.Stat.ABILITY_COOLDOWN:
			return "Cooldown %.2fs -> %.2fs" % [stats.ability_cooldown, after_stats.ability_cooldown]
		Upgrade.Stat.HEAL:
			return "Hearts %d -> %d" % [health.hearts, after_health.hearts]
		Upgrade.Stat.ABILITY_POWER:
			return "Power %d%% -> %d%%" % [roundi(stats.ability_power * 100.0), roundi(after_stats.ability_power * 100.0)]
		Upgrade.Stat.BULLET_SPEED:
			return "Bolt speed %d -> %d" % [roundi(stats.bullet_speed), roundi(after_stats.bullet_speed)]
		Upgrade.Stat.KILL_HEAL:
			return "Heal every %d kills" % after_stats.heal_every_kills
		Upgrade.Stat.REVIVE_SPEED:
			return "Revive speed %d%% -> %d%%" % [roundi(stats.revive_speed * 100.0), roundi(after_stats.revive_speed * 100.0)]
		Upgrade.Stat.BULLET_RANGE:
			return "Bolt range %d -> %d" % [roundi(stats.bullet_speed * stats.bullet_lifetime),
				roundi(after_stats.bullet_speed * after_stats.bullet_lifetime)]
		Upgrade.Stat.HIT_INVULNERABILITY:
			return "Safe time %.1fs -> %.1fs" % [stats.hit_invulnerability, after_stats.hit_invulnerability]
		Upgrade.Stat.CRIT_CHANCE:
			return "Crit chance %d%% -> %d%%" % [roundi(stats.crit_chance * 100.0), roundi(after_stats.crit_chance * 100.0)]
		Upgrade.Stat.KILL_BURST:
			return "Burst damage %d -> %d" % [stats.kill_burst_damage, after_stats.kill_burst_damage]
		Upgrade.Stat.BOSS_DAMAGE:
			return "Vs bosses +%d%% -> +%d%%" % [roundi(stats.boss_damage_bonus * 100.0),
				roundi(after_stats.boss_damage_bonus * 100.0)]
		Upgrade.Stat.WOUNDED_DAMAGE:
			return "Vs wounded +%d%% -> +%d%%" % [roundi(stats.wounded_damage_bonus * 100.0),
				roundi(after_stats.wounded_damage_bonus * 100.0)]
		Upgrade.Stat.RICOCHET:
			return "Bounces %d -> %d" % [stats.ricochet, after_stats.ricochet]
		Upgrade.Stat.HOMING:
			return "Homing %d -> %d" % [roundi(stats.homing / HOMING_STEP), roundi(after_stats.homing / HOMING_STEP)]
		Upgrade.Stat.DASH_GRACE:
			return "Safe after Dash %.1fs -> %.1fs" % [stats.dash_grace, after_stats.dash_grace]
		Upgrade.Stat.BLAST_DAMAGE:
			return "Blast damage %d -> %d" % [roundi(stats.blast_damage * stats.ability_power),
				roundi(after_stats.blast_damage * after_stats.ability_power)]
		Upgrade.Stat.BLAST_HEAL:
			return "Blast heals %d -> %d" % [stats.blast_heal, after_stats.blast_heal]
		Upgrade.Stat.HEX_DURATION:
			return "Hex %.1fs -> %.1fs" % [stats.hex_duration * stats.ability_power,
				after_stats.hex_duration * after_stats.ability_power]
		Upgrade.Stat.HEX_DAMAGE:
			return "Vs hexed +%d%% -> +%d%%" % [roundi((stats.hex_damage_multiplier - 1.0) * 100.0),
				roundi((after_stats.hex_damage_multiplier - 1.0) * 100.0)]
		Upgrade.Stat.EFFIGY_DURATION:
			return "Effigy %.1fs -> %.1fs" % [stats.effigy_duration * stats.ability_power,
				after_stats.effigy_duration * after_stats.ability_power]
		Upgrade.Stat.EFFIGY_BURST:
			return "Burst %d -> %d" % [roundi(stats.effigy_burst_damage * stats.ability_power),
				roundi(after_stats.effigy_burst_damage * after_stats.ability_power)]
		Upgrade.Stat.WEAPON_REACH:
			return "Reach %d -> %d" % [roundi(stats.weapon_reach), roundi(after_stats.weapon_reach)]
		Upgrade.Stat.WEAPON_SIZE:
			var size_name := "Jump range" if stats.main_weapon == CharacterStats.MainWeapon.LIGHTNING else "Size"
			return "%s %d -> %d" % [size_name, roundi(stats.weapon_radius), roundi(after_stats.weapon_radius)]
		Upgrade.Stat.WEAPON_DELAY:
			return "Warning %.2fs -> %.2fs" % [stats.weapon_duration, after_stats.weapon_duration]
		Upgrade.Stat.CHAIN_GROWTH:
			return "Per jump +%d%% -> +%d%%" % [roundi(stats.chain_damage_growth * 100.0),
				roundi(after_stats.chain_damage_growth * 100.0)]
		Upgrade.Stat.CHAIN_FORK:
			return "Chains %d -> %d" % [stats.chain_forks + 1, after_stats.chain_forks + 1]
		Upgrade.Stat.SCYTHE_CUTS:
			return "Cuts per throw %d -> %d" % [stats.scythe_cuts, after_stats.scythe_cuts]
		Upgrade.Stat.SPEAR_SHARDS:
			return "Shards %d -> %d" % [stats.spear_shards, after_stats.spear_shards]
	return ""
