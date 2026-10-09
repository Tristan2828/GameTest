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
	preload("res://src/progression/relics/bomb_satchel.tres"),
	preload("res://src/progression/relics/hunters_eye.tres"),
	preload("res://src/progression/relics/vampire_fang.tres"),
	preload("res://src/progression/relics/holy_water.tres"),

]


static func get_relic(id: int) -> Relic:
	return ALL[clampi(id, 0, ALL.size() - 1)]


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < ALL.size()


## Up to OFFERS_PER_SHOP relics the player doesn't own yet.
static func roll_offers(rng: RandomNumberGenerator, owned: Array[int]) -> Array[int]:
	var pool: Array[int] = []
	for id: int in ALL.size():
		if not owned.has(id):
			pool.append(id)
	var result: Array[int] = []
	while not pool.is_empty() and result.size() < OFFERS_PER_SHOP:
		result.append(pool.pop_at(rng.randi() % pool.size()))
	return result


## Every peer runs this when a purchase is announced, so stats stay identical.
static func apply(id: int, stats: CharacterStats, health: PlayerHealth) -> void:
	for effect: Upgrade in get_relic(id).effects:
		Upgrades.apply_effect(effect, stats, health)
