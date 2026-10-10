class_name PowerUps
extends RefCounted
## Rare pickups that do something the moment you grab them (Heart, Soul Magnet,
## Holy Bomb, Frost Hourglass). They lie in their own GemManager pool, where a
## pickup's "value" is its Kind. The Kind is sent over the network: append only.
##
## Host: rolls drops when enemies die (rarely, and never two too close together)
## and applies the effect for whoever grabbed it.

enum Kind { HEART, SOUL_MAGNET, HOLY_BOMB, FROST_HOURGLASS }

## Chance that a regular enemy's death drops a pickup (when not on cooldown).
const DROP_CHANCE: float = 0.012
## At most one random drop per this many seconds of play.
const DROP_COOLDOWN: float = 10.0
## Relative odds of each Kind for a random drop (same order as Kind).
const WEIGHTS: Array[int] = [35, 25, 20, 20]
## Hearts healed by a Heart.
const HEART_HEAL: int = 1
## Holy Bomb: reach (about a screen) and damage to every regular enemy in it
## (times the stage's health growth, so it stays a near-certain kill).
const BOMB_RADIUS: float = 260.0
const BOMB_DAMAGE: int = 400
## Frost Hourglass: regular enemies and the enemy bullets already flying stop.
const FROST_SECONDS: float = 4.0
const FROST_COLOR: Color = Color(0.55, 0.85, 1.0)

const TITLES: Array[String] = ["Heart", "Soul Magnet", "Holy Bomb", "Frost Hourglass"]
const SPRITES: Array[String] = ["pickup_heart", "pickup_magnet", "pickup_bomb", "pickup_frost"]
const DESCRIPTIONS: Array[String] = [
	"Heals 1 heart for whoever grabs it.",
	"Pulls every XP gem on the map to you.",
	"Smites every regular enemy around you and wipes out nearby enemy bullets. Bosses are spared.",
	"Freezes regular enemies and every enemy bullet in the air for 4 seconds.",
]


static func is_valid_kind(kind: int) -> bool:
	return kind >= 0 and kind < TITLES.size()


## A random Kind by WEIGHTS. `roll` is a number in [0, 1).
static func pick_kind(roll: float) -> int:
	var total := 0
	for weight: int in WEIGHTS:
		total += weight
	var target := roll * total
	for kind: int in WEIGHTS.size():
		target -= WEIGHTS[kind]
		if target < 0.0:
			return kind
	return WEIGHTS.size() - 1
