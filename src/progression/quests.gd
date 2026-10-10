class_name Quests
extends RefCounted
## Quests picked in the shop for the next stage. Each player picks 1 of 3 for
## themselves (free); finishing it during that stage pays coins or a free relic
## right away. Unfinished quests simply expire when the stage ends.
## The index (Id) is sent over the network: only add new quests at the end.

enum Id { CHAMPION_HUNTER, RITUALIST, THIEF_CATCHER, SLAYER, UNTOUCHABLE, GOLD_DIGGER, ARSENAL, SCAVENGER, GUARDIAN }

const OFFERS_PER_SHOP: int = 3
## Reward 0 coins = a free relic you don't own yet.
const RELIC_REWARD: int = 0

const TITLES: Array[String] = ["Champion Hunter", "Ritualist", "Thief Catcher", "Slayer", "Untouchable",
	"Gold Digger", "Arsenal", "Scavenger", "Guardian"]
## "%d" is replaced with the target.
const DESCRIPTIONS: Array[String] = [
	"Help defeat the stage's champion.",
	"Be in the circle when a ritual is completed.",
	"Help catch a Grave Robber.",
	"Kill %d enemies yourself.",
	"Go %d seconds without losing a heart.",
	"Pick up %d coins.",
	"Deal %d damage with auto weapons.",
	"Grab %d power-ups.",
	"Revive a teammate.",
]
const TARGETS: Array[int] = [1, 1, 1, 250, 60, 40, 4000, 2, 1]
const REWARDS: Array[int] = [45, RELIC_REWARD, 35, 40, RELIC_REWARD, RELIC_REWARD, 45, 35, RELIC_REWARD]
const ICONS: Array[String] = ["crown", "icon_ritual", "coin_big", "up_sharpened_bolts", "up_steady_nerves", "coin_big",
	"icon_chain_lightning", "pickup_bomb", "rel_mourners_bell"]
## Only offered with teammates.
const CO_OP_ONLY: Array[bool] = [false, false, false, false, false, false, false, false, true]


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < TITLES.size()


static func description(id: int) -> String:
	var text := DESCRIPTIONS[id]
	return text % TARGETS[id] if text.contains("%d") else text


static func reward_text(id: int) -> String:
	return "Reward: a free relic" if REWARDS[id] == RELIC_REWARD else "Reward: %d coins" % REWARDS[id]


## OFFERS_PER_SHOP different quests (co-op-only ones only when `co_op`).
static func roll_offers(rng: RandomNumberGenerator, co_op: bool) -> Array[int]:
	var pool: Array[int] = []
	for id: int in TITLES.size():
		if co_op or not CO_OP_ONLY[id]:
			pool.append(id)
	var result: Array[int] = []
	while not pool.is_empty() and result.size() < OFFERS_PER_SHOP:
		result.append(pool.pop_at(rng.randi() % pool.size()))
	return result
