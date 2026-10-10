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
	preload("res://src/progression/upgrades/ghoul_blood.tres"),
]
## A max-HP cut is never offered if it would leave the hero below this.
const MIN_MAX_HP_AFTER_CUT: int = 30


static func get_upgrade(id: int) -> Upgrade:
	return ALL[clampi(id, 0, ALL.size() - 1)]


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < ALL.size()


## Rolls up to CHOICES_PER_LEVEL different upgrade ids. Skips maxed-out and
## retired ones, only offers healing to a player who is hurt, weapon-only
## upgrades to that weapon's hero (`stats`; none without it), auto weapon boosts
## only to someone with an auto weapon, and never a max-HP cut that would leave
## too little.
static func roll(rng: RandomNumberGenerator, owned: Array[int], is_hurt: bool,
		stats: CharacterStats = null, has_auto_weapons: bool = true) -> Array[int]:
	var pool: Array[int] = []
	for id: int in ALL.size():
		if is_offered(ALL[id], owned.count(id), is_hurt, stats, has_auto_weapons):
			pool.append(id)
	var result: Array[int] = []
	while not pool.is_empty() and result.size() < CHOICES_PER_LEVEL:
		result.append(pool.pop_at(rng.randi() % pool.size()))
	return result


static func is_offered(upgrade: Upgrade, stacks: int, is_hurt: bool, stats: CharacterStats,
		has_auto_weapons: bool = true) -> bool:
	if upgrade.retired:
		return false
	if not has_auto_weapons and (upgrade.stat == Upgrade.Stat.AUTO_COOLDOWN or upgrade.stat == Upgrade.Stat.AUTO_POWER):
		return false
	if upgrade.stat == Upgrade.Stat.HEAL and not is_hurt:
		return false
	if upgrade.max_stacks > 0 and stacks >= upgrade.max_stacks:
		return false
	if upgrade.for_weapon >= 0 and (stats == null or stats.main_weapon != upgrade.for_weapon):
		return false
	if stats != null:
		for effect: Upgrade in effects_of(upgrade):
			if effect.stat == Upgrade.Stat.MAX_HP and effect.amount < 0.0 \
					and stats.max_hp + effect.amount < MIN_MAX_HP_AFTER_CUT:
				return false
	return true


## The upgrade's own effect followed by its extra effects.
static func effects_of(upgrade: Upgrade) -> Array[Upgrade]:
	var effects: Array[Upgrade] = [upgrade]
	for extra: Resource in upgrade.extra_effects:
		effects.append(extra as Upgrade)
	return effects


## "Kael only" for weapon upgrades (empty for everyone's).
static func hero_text(upgrade: Upgrade) -> String:
	if upgrade.for_weapon < 0:
		return ""
	for character: CharacterStats in Characters.ALL:
		if character.main_weapon == upgrade.for_weapon:
			return "%s only" % character.hero_name
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
		Upgrade.Stat.MAX_HP:
			stats.max_hp = maxi(stats.max_hp + int(upgrade.amount), 1)
			health.max_hp = stats.max_hp
			if upgrade.amount > 0.0:
				health.heal(int(upgrade.amount))
			else:
				health.hp = mini(health.hp, health.max_hp)
		Upgrade.Stat.EXTRA_BOLT:
			stats.projectile_count += int(upgrade.amount)
		Upgrade.Stat.PIERCE:
			stats.pierce += int(upgrade.amount)
		Upgrade.Stat.PICKUP_RADIUS:
			stats.pickup_radius *= 1.0 + upgrade.amount
		Upgrade.Stat.AUTO_COOLDOWN:
			stats.auto_cooldown_scale *= 1.0 - upgrade.amount
		Upgrade.Stat.HEAL:
			health.heal(int(upgrade.amount))
		Upgrade.Stat.AUTO_POWER:
			stats.auto_power *= 1.0 + upgrade.amount
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
		Upgrade.Stat.RECOVERY:
			stats.recovery += upgrade.amount
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
	after_health.max_hp = health.max_hp
	after_health.hp = health.hp
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
		Upgrade.Stat.MAX_HP:
			return "Max HP %d -> %d" % [stats.max_hp, after_stats.max_hp]
		Upgrade.Stat.EXTRA_BOLT:
			return "%s %d -> %d" % [COUNT_NAMES[stats.main_weapon], stats.projectile_count, after_stats.projectile_count]
		Upgrade.Stat.PIERCE:
			return "Pierce %d -> %d" % [stats.pierce, after_stats.pierce]
		Upgrade.Stat.PICKUP_RADIUS:
			return "Range %d -> %d" % [roundi(stats.pickup_radius), roundi(after_stats.pickup_radius)]
		Upgrade.Stat.AUTO_COOLDOWN:
			return "Auto cooldown %d%% -> %d%%" % [roundi(stats.auto_cooldown_scale * 100.0),
				roundi(after_stats.auto_cooldown_scale * 100.0)]
		Upgrade.Stat.HEAL:
			return "HP %d -> %d" % [health.hp, after_health.hp]
		Upgrade.Stat.AUTO_POWER:
			return "Auto damage %d%% -> %d%%" % [roundi(stats.auto_power * 100.0), roundi(after_stats.auto_power * 100.0)]
		Upgrade.Stat.BULLET_SPEED:
			return "Bolt speed %d -> %d" % [roundi(stats.bullet_speed), roundi(after_stats.bullet_speed)]
		Upgrade.Stat.KILL_HEAL:
			return "Heal 1 HP every %d kills" % after_stats.heal_every_kills
		Upgrade.Stat.RECOVERY:
			return "Recovery %.1f -> %.1f HP/s" % [stats.recovery, after_stats.recovery]
		Upgrade.Stat.REVIVE_SPEED:
			return "Revive speed %d%% -> %d%%" % [roundi(stats.revive_speed * 100.0), roundi(after_stats.revive_speed * 100.0)]
		Upgrade.Stat.BULLET_RANGE:
			return "Bolt range %d -> %d" % [roundi(stats.bullet_speed * stats.bullet_lifetime),
				roundi(after_stats.bullet_speed * after_stats.bullet_lifetime)]
		Upgrade.Stat.HIT_INVULNERABILITY:
			return "Bullet safety %.2fs -> %.2fs" % [stats.hit_invulnerability, after_stats.hit_invulnerability]
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
