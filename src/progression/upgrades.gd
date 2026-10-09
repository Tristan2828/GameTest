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


## Applies an upgrade to one player's stats (and health). Every peer runs this
## for every upgrade, so all copies of a player's stats stay identical.
static func apply(id: int, stats: CharacterStats, health: PlayerHealth) -> void:
	var upgrade := get_upgrade(id)
	match upgrade.stat:
		Upgrade.Stat.DAMAGE:
			stats.bullet_damage += int(upgrade.amount)
		Upgrade.Stat.FIRE_RATE:
			stats.fire_interval *= 1.0 - upgrade.amount
		Upgrade.Stat.MOVE_SPEED:
			stats.move_speed *= 1.0 + upgrade.amount
		Upgrade.Stat.MAX_HEARTS:
			stats.max_hearts += int(upgrade.amount)
			health.max_hearts = stats.max_hearts
			health.heal(int(upgrade.amount))
		Upgrade.Stat.EXTRA_BOLT:
			stats.projectile_count += int(upgrade.amount)
		Upgrade.Stat.PIERCE:
			stats.pierce += int(upgrade.amount)
		Upgrade.Stat.PICKUP_RADIUS:
			stats.pickup_radius *= 1.0 + upgrade.amount
		Upgrade.Stat.DASH_COOLDOWN:
			stats.dash_cooldown *= 1.0 - upgrade.amount
		Upgrade.Stat.HEAL:
			health.heal(int(upgrade.amount))
