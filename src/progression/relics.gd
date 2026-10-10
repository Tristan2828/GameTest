class_name Relics
extends RefCounted
## Registry of shop relics. The index in ALL is the network id: only add new
## relics at the end.

const OFFERS_PER_SHOP: int = 4
## First reroll in a shop costs this; each further reroll costs REROLL_STEP more.
const REROLL_PRICE: int = 10
const REROLL_STEP: int = 10

const ALL: Array[Relic] = [
	preload("res://src/progression/relics/cursed_skull.tres"),
	preload("res://src/progression/relics/iron_boots.tres"),
	preload("res://src/progression/relics/hourglass.tres"),
	preload("res://src/progression/relics/grave_lantern.tres"),
	preload("res://src/progression/relics/bone_charm.tres"),
	preload("res://src/progression/relics/hunters_eye.tres"),
	preload("res://src/progression/relics/vampire_fang.tres"),
	preload("res://src/progression/relics/holy_water.tres"),
	preload("res://src/progression/relics/mourners_bell.tres"),
	preload("res://src/progression/relics/bloodstone.tres"),
]


static func get_relic(id: int) -> Relic:
	return ALL[clampi(id, 0, ALL.size() - 1)]


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < ALL.size()


## Up to OFFERS_PER_SHOP relics the player doesn't own yet (co-op-only relics
## only when `co_op`; weapon-only relics only to that weapon's hero, `stats`).
static func roll_offers(rng: RandomNumberGenerator, owned: Array[int], co_op: bool = true,
		stats: CharacterStats = null) -> Array[int]:
	var pool: Array[int] = []
	for id: int in ALL.size():
		if not owned.has(id) and (co_op or not ALL[id].co_op_only) and fits_weapon(ALL[id], stats):
			pool.append(id)
	var result: Array[int] = []
	while not pool.is_empty() and result.size() < OFFERS_PER_SHOP:
		result.append(pool.pop_at(rng.randi() % pool.size()))
	return result


static func fits_weapon(relic: Relic, stats: CharacterStats) -> bool:
	return relic.for_weapon < 0 or (stats != null and stats.main_weapon == relic.for_weapon)


## Every peer runs this when a purchase is announced, so stats stay identical.
static func apply(id: int, stats: CharacterStats, health: PlayerHealth) -> void:
	for effect: Upgrade in get_relic(id).effects:
		Upgrades.apply_effect(effect, stats, health)
