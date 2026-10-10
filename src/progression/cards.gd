class_name Cards
extends RefCounted
## Everything that changes a player's build, as one number (a "card"), so the
## host can announce it the same way whether it came from a level-up pick, an
## altar, a chest or a boss (v0.23.0, auto-fire redesign step 2):
## - 0..999: an Upgrades id (a passive's next level, or a filler: heal, coins).
## - WEAPON_BASE + AutoWeapons id: that auto weapon, or its next level.
## - MAIN_LEVEL: the hero's main weapon's next level (CharacterStats.main_levels).
## - MAIN_EVOLUTION: the maxed main weapon evolves (CharacterStats.evolution).
## - EVOLVE_BASE + evolved AutoWeapons id: a maxed auto weapon evolves.
## Cards are sent over the network, so these numbers never change.
##
## Rules: 6 weapon slots (the main weapon is one), 6 passive slots. Level-up
## cards offer new weapons and passives while slots are free, and levels of what
## you carry; when there's nothing left, fillers. Pure logic (reads a Player's
## build, never changes it), so it's unit-testable.

const WEAPON_BASE: int = 1000
const MAIN_LEVEL: int = 2000
const MAIN_EVOLUTION: int = 2001
const EVOLVE_BASE: int = 3000

const CHOICES_PER_LEVEL: int = 3
## Card rerolls every player starts a run with (the shop sells more).
const START_REROLLS: int = 1
## How likely each kind of card is to be offered, relative to a brand-new
## weapon or passive: levels of what you carry come up more, so builds grow.
const NEW_WEIGHT: float = 1.0
const LEVEL_WEIGHT: float = 2.0
const MAIN_LEVEL_WEIGHT: float = 3.0

## Filler cards when there's nothing else to offer.
const HEAL_FILLER: int = 8
const COIN_FILLER: int = 38


static func weapon(weapon_id: int) -> int:
	return WEAPON_BASE + weapon_id


static func evolve(evolved_id: int) -> int:
	return EVOLVE_BASE + evolved_id


static func is_upgrade(card: int) -> bool:
	return card >= 0 and card < WEAPON_BASE


static func is_weapon(card: int) -> bool:
	return card >= WEAPON_BASE and card < MAIN_LEVEL


static func is_evolution(card: int) -> bool:
	return card == MAIN_EVOLUTION or card >= EVOLVE_BASE


static func weapon_id(card: int) -> int:
	if is_weapon(card):
		return card - WEAPON_BASE
	if card >= EVOLVE_BASE:
		return card - EVOLVE_BASE
	return -1


static func is_valid(card: int) -> bool:
	if is_upgrade(card):
		return Upgrades.is_valid_id(card)
	if is_weapon(card):
		return AutoWeapons.is_valid_id(card - WEAPON_BASE)
	if card >= EVOLVE_BASE:
		return AutoWeapons.EVOLUTIONS.has(card - EVOLVE_BASE)
	return card == MAIN_LEVEL or card == MAIN_EVOLUTION


# --- A player's build ----------------------------------------------------------

## Passive id -> level (how many times it was taken).
static func passive_levels(player: Player) -> Dictionary[int, int]:
	var levels: Dictionary[int, int] = {}
	for id: int in player.upgrade_ids:
		if Upgrades.get_upgrade(id).passive:
			levels[id] = levels.get(id, 0) + 1
	return levels


static func free_weapon_slots(player: Player) -> int:
	return AutoWeapons.WEAPON_SLOTS - 1 - player.weapon_levels.size()


static func free_passive_slots(player: Player) -> int:
	return Upgrades.PASSIVE_SLOTS - passive_levels(player).size()


## Whether `weapon_id` (or the weapon it evolved into) is already carried.
static func carries(player: Player, weapon_id: int) -> bool:
	return player.weapon_levels.has(weapon_id) or player.weapon_levels.has(AutoWeapons.evolution_of(weapon_id))


static func main_is_maxed(player: Player) -> bool:
	return player.main_level >= player.stats.main_max_level()


## Every evolution this player could get right now (a maxed weapon plus its passive).
static func ready_evolutions(player: Player) -> Array[int]:
	var ready: Array[int] = []
	var passives := passive_levels(player)
	if not player.main_evolved and main_is_maxed(player) and player.stats.evolution != null \
			and passives.has(player.stats.evolution_catalyst):
		ready.append(MAIN_EVOLUTION)
	for evolved: int in AutoWeapons.EVOLUTIONS:
		var weapon := AutoWeapons.get_weapon(evolved)
		if player.weapon_levels.get(weapon.evolves_from, 0) >= AutoWeapons.MAX_LEVEL and passives.has(weapon.catalyst):
			ready.append(evolve(evolved))
	return ready


## Whether this card would still change something for this player.
static func can_take(player: Player, card: int) -> bool:
	if is_upgrade(card):
		var upgrade := Upgrades.get_upgrade(card)
		if upgrade.retired:
			return false
		if not upgrade.passive:
			return true
		var levels := passive_levels(player)
		if levels.has(card):
			return levels[card] < upgrade.max_stacks
		return free_passive_slots(player) > 0
	if is_weapon(card):
		var id := card - WEAPON_BASE
		if player.weapon_levels.has(id):
			return player.weapon_levels[id] < AutoWeapons.get_weapon(id).max_level()
		return AutoWeapons.PICKUPS.has(id) and not carries(player, id) and free_weapon_slots(player) > 0
	if card == MAIN_LEVEL:
		return not main_is_maxed(player) and not player.main_evolved
	return ready_evolutions(player).has(card)


## Every card a level-up could offer this player, with its weight.
static func options(player: Player) -> Dictionary[int, float]:
	var result: Dictionary[int, float] = {}
	if can_take(player, MAIN_LEVEL):
		result[MAIN_LEVEL] = MAIN_LEVEL_WEIGHT
	for id: int in AutoWeapons.PICKUPS:
		var card := weapon(id)
		if can_take(player, card):
			result[card] = LEVEL_WEIGHT if player.weapon_levels.has(id) else NEW_WEIGHT
	var levels := passive_levels(player)
	for id: int in Upgrades.ALL.size():
		var upgrade := Upgrades.ALL[id]
		if upgrade.passive and can_take(player, id):
			result[id] = LEVEL_WEIGHT if levels.has(id) else NEW_WEIGHT
	return result


## Up to CHOICES_PER_LEVEL different cards, picked by weight; fillers (heal when
## hurt, coins) when the build is full.
static func roll(rng: RandomNumberGenerator, player: Player, is_hurt: bool) -> Array[int]:
	var pool := options(player)
	var result: Array[int] = []
	while not pool.is_empty() and result.size() < CHOICES_PER_LEVEL:
		var card := _weighted_pick(rng, pool)
		result.append(card)
		pool.erase(card)
	if result.size() < CHOICES_PER_LEVEL and is_hurt:
		result.append(HEAL_FILLER)
	if result.size() < CHOICES_PER_LEVEL:
		result.append(COIN_FILLER)
	return result


static func _weighted_pick(rng: RandomNumberGenerator, pool: Dictionary[int, float]) -> int:
	var total := 0.0
	for card: int in pool:
		total += pool[card]
	var roll_at := rng.randf() * total
	for card: int in pool:
		roll_at -= pool[card]
		if roll_at < 0.0:
			return card
	return pool.keys()[pool.size() - 1]


## What an altar showing `weapon_id` gives this player: that weapon (new or a
## level), else a level of a random weapon they carry, or -1 (coins instead).
static func altar_card(rng: RandomNumberGenerator, player: Player, weapon_id: int) -> int:
	var card := weapon(weapon_id)
	if can_take(player, card):
		return card
	var carried: Array[int] = []
	if can_take(player, MAIN_LEVEL):
		carried.append(MAIN_LEVEL)
	for id: int in player.weapon_levels:
		if can_take(player, weapon(id)):
			carried.append(weapon(id))
	return -1 if carried.is_empty() else carried[rng.randi() % carried.size()]


## What a champion's chest gives: an evolution if one is ready, else a random
## weapon (new, if a slot is free, or a level of one carried), or -1 (coins).
static func chest_card(rng: RandomNumberGenerator, player: Player) -> int:
	var ready := ready_evolutions(player)
	if not ready.is_empty():
		return ready[0]
	var choices: Array[int] = []
	if can_take(player, MAIN_LEVEL):
		choices.append(MAIN_LEVEL)
	for id: int in AutoWeapons.PICKUPS:
		if can_take(player, weapon(id)):
			choices.append(weapon(id))
	return -1 if choices.is_empty() else choices[rng.randi() % choices.size()]


# --- What a card shows ---------------------------------------------------------

static func title(card: int, stats: CharacterStats) -> String:
	if is_upgrade(card):
		return Upgrades.get_upgrade(card).title
	if card == MAIN_LEVEL:
		return stats.main_weapon_name if stats != null else "Main weapon"
	if card == MAIN_EVOLUTION:
		return stats.evolved_weapon_name if stats != null else "Evolution"
	return AutoWeapons.get_weapon(weapon_id(card)).title


static func icon(card: int, stats: CharacterStats) -> String:
	if is_upgrade(card):
		return Upgrades.get_upgrade(card).icon
	if card == MAIN_LEVEL:
		return stats.main_weapon_icon if stats != null else "icon_main_gun"
	if card == MAIN_EVOLUTION:
		return stats.evolved_weapon_icon if stats != null else "icon_main_gun"
	return AutoWeapons.get_weapon(weapon_id(card)).icon


## What taking it does (for a main weapon level: that level's step).
static func description(card: int, player: Player) -> String:
	if is_upgrade(card):
		return Upgrades.get_upgrade(card).description
	if card == MAIN_LEVEL:
		var step := next_main_step(player)
		return step.description if step != null else ""
	if card == MAIN_EVOLUTION:
		return (player.stats.evolution as Upgrade).description if player != null and player.stats.evolution != null else ""
	return AutoWeapons.get_weapon(weapon_id(card)).description


## The Upgrade the main weapon's next level applies (null when maxed).
static func next_main_step(player: Player) -> Upgrade:
	if player == null:
		return null
	var index := player.main_level - 1
	if index < 0 or index >= player.stats.main_levels.size():
		return null
	return player.stats.main_levels[index] as Upgrade


## [current level, max level] for the card's pips ([0, 0] = no pips).
static func levels(card: int, player: Player) -> Vector2i:
	if player == null:
		return Vector2i.ZERO
	if is_upgrade(card):
		var upgrade := Upgrades.get_upgrade(card)
		return Vector2i(passive_levels(player).get(card, 0), upgrade.max_stacks) if upgrade.passive else Vector2i.ZERO
	if card == MAIN_LEVEL:
		return Vector2i(player.main_level, player.stats.main_max_level())
	if is_weapon(card):
		var id := card - WEAPON_BASE
		return Vector2i(player.weapon_levels.get(id, 0), AutoWeapons.get_weapon(id).max_level())
	return Vector2i.ZERO


## "New weapon!", "New passive!", "Evolution!" or "" (the pips say the level).
static func badge(card: int, player: Player) -> String:
	if is_evolution(card):
		return "Evolution!"
	if is_weapon(card) and player != null and not player.weapon_levels.has(card - WEAPON_BASE):
		return "New weapon!"
	if is_upgrade(card) and Upgrades.get_upgrade(card).passive and player != null \
			and not passive_levels(player).has(card):
		return "New passive!"
	return ""


## Before -> after lines for the card (stats, or the weapon's next level).
static func preview_text(card: int, player: Player) -> String:
	if player == null:
		return ""
	if is_upgrade(card):
		var upgrade := Upgrades.get_upgrade(card)
		if upgrade.stat == Upgrade.Stat.COINS:
			return "Coins %d -> %d" % [player.coins, player.coins + roundi(upgrade.amount)]
		return Upgrades.preview_text(card, player.stats, player.health)
	if card == MAIN_LEVEL:
		var step := next_main_step(player)
		return Upgrades.effect_preview(step, player.stats, player.health) if step != null else ""
	if card == MAIN_EVOLUTION:
		return Upgrades.effect_preview(player.stats.evolution as Upgrade, player.stats, player.health)
	var id := weapon_id(card)
	var weapon := AutoWeapons.get_weapon(id)
	var level: int = player.weapon_levels.get(id, 0)
	if is_evolution(card) or level == 0:
		return weapon_summary(weapon, 1)
	return "Damage %d -> %d" % [weapon.damage_at(level), weapon.damage_at(level + 1)] + _weapon_change(weapon, level)


## One line about the weapon at this level (damage and its main number).
static func weapon_summary(weapon: AutoWeapon, level: int) -> String:
	var text := "Damage %d" % weapon.damage_at(level)
	if weapon.count_at(level) > 1:
		text += ", %d at once" % weapon.count_at(level)
	return text + ", every %.1fs" % weapon.interval_at(level)


static func _weapon_change(weapon: AutoWeapon, level: int) -> String:
	if weapon.count_at(level + 1) != weapon.count_at(level):
		return "\nCount %d -> %d" % [weapon.count_at(level), weapon.count_at(level + 1)]
	if not is_equal_approx(weapon.interval_at(level + 1), weapon.interval_at(level)):
		return "\nEvery %.2fs -> %.2fs" % [weapon.interval_at(level), weapon.interval_at(level + 1)]
	if not is_equal_approx(weapon.radius_at(level + 1), weapon.radius_at(level)):
		return "\nSize %d -> %d" % [roundi(weapon.radius_at(level)), roundi(weapon.radius_at(level + 1))]
	return ""
