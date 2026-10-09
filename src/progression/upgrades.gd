class_name Upgrades
extends RefCounted
## Registry of level-up upgrades, plus the rules for rolling and applying them.
## The index in ALL is the id sent over the network: only add new ones at the end.

const CHOICES_PER_LEVEL: int = 3

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
]


static func get_upgrade(id: int) -> Upgrade:
	return ALL[clampi(id, 0, ALL.size() - 1)]


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < ALL.size()


## Rolls up to CHOICES_PER_LEVEL different upgrade ids. Skips maxed-out ones,
## and only offers healing to a player who is missing hearts.
static func roll(rng: RandomNumberGenerator, owned: Array[int], is_hurt: bool) -> Array[int]:
	var pool: Array[int] = []
	for id: int in ALL.size():
		var upgrade := ALL[id]
		if upgrade.stat == Upgrade.Stat.HEAL and not is_hurt:
			continue
		if upgrade.max_stacks > 0 and owned.count(id) >= upgrade.max_stacks:
			continue
		pool.append(id)
	var result: Array[int] = []
	while not pool.is_empty() and result.size() < CHOICES_PER_LEVEL:
		result.append(pool.pop_at(rng.randi() % pool.size()))
	return result


## Applies a level-up upgrade to one player's stats (and health). Every peer runs
## this for every upgrade, so all copies of a player's stats stay identical.
static func apply(id: int, stats: CharacterStats, health: PlayerHealth) -> void:
	apply_effect(get_upgrade(id), stats, health)


## Applies one stat effect (from an upgrade or a relic).
static func apply_effect(upgrade: Upgrade, stats: CharacterStats, health: PlayerHealth) -> void:
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
## "Damage 13 -> 16". Applies the upgrade to copies, so it uses the same math.
static func preview_text(id: int, stats: CharacterStats, health: PlayerHealth) -> String:
	var upgrade := get_upgrade(id)
	var after_stats := stats.duplicate() as CharacterStats
	var after_health := PlayerHealth.new()
	after_health.max_hearts = health.max_hearts
	after_health.hearts = health.hearts
	apply_effect(upgrade, after_stats, after_health)
	match upgrade.stat:
		Upgrade.Stat.DAMAGE:
			return "Damage %d -> %d" % [stats.bullet_damage, after_stats.bullet_damage]
		Upgrade.Stat.FIRE_RATE:
			return "Shots/s %.1f -> %.1f" % [1.0 / stats.fire_interval, 1.0 / after_stats.fire_interval]
		Upgrade.Stat.MOVE_SPEED:
			return "Speed %d -> %d" % [roundi(stats.move_speed), roundi(after_stats.move_speed)]
		Upgrade.Stat.MAX_HEARTS:
			return "Max hearts %d -> %d" % [stats.max_hearts, after_stats.max_hearts]
		Upgrade.Stat.EXTRA_BOLT:
			return "Bolts %d -> %d" % [stats.projectile_count, after_stats.projectile_count]
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
	return ""
