class_name Embers
extends RefCounted
## Light permanent progression: Embers earned at the end of every run, spent at
## the title menu's Ember Shrine on small permanent boosts (each player's own,
## kept on this PC in user://embers.cfg). A fully bought hero is only a few
## percent stronger; buying everything takes about 100 runs.
##
## In co-op each player brings their own boosts: Net sends a client's ranks to the
## host on connecting, and the arena's spawn data hands them to every peer, which
## applies them to that player's stats (see `apply`). The host can turn boosts
## off for everyone (RunConfig.ember_boosts).

const PATH: String = "user://embers.cfg"

## Boost ids are sent over the network: append only.
enum Boost { KEEN_EYE, SWIFTNESS, FOCUS, GREED, REACH, RESOLVE }

const MAX_RANK: int = 3
## Price of rank 1, 2 and 3 of any boost.
const PRICES: Array[int] = [50, 100, 175]

## Per Boost: [name, sprite icon, what one rank does, amount per rank].
const BOOSTS: Array[Array] = [
	["Keen Eye", "up_keen_edge", "+2% main weapon crit chance", 0.02],
	["Swiftness", "up_fleet_foot", "+2% move speed", 0.02],
	["Focus", "up_shadow_step", "-3% ability cooldown", 0.03],
	["Greed", "coin_big", "+5% chance a coin you pick up is worth 1 more", 0.05],
	["Reach", "up_grave_magnet", "+6% pickup radius", 0.06],
	["Resolve", "up_steady_nerves", "+0.05s safe time after a hit", 0.05],
]

## Earning: per boss killed, for a victory, per 100 of your kills (capped).
const PER_BOSS: int = 8
const PER_VICTORY: int = 6
const KILLS_PER_EMBER: int = 100
const MAX_KILL_EMBERS: int = 10

## Where the file is saved (tests point it elsewhere).
static var path: String = PATH

## Embers ready to spend.
var balance: int = 0
## Every Ember ever earned (shown on the shrine page).
var total_earned: int = 0
## Rank bought per Boost (0..MAX_RANK).
var ranks: PackedInt32Array = PackedInt32Array()
## Off: your boosts stay bought but aren't used (a "pure" run).
var enabled: bool = true


func _init() -> void:
	ranks.resize(BOOSTS.size())


static func boost_name(boost: int) -> String:
	return BOOSTS[boost][0]


static func boost_icon(boost: int) -> String:
	return BOOSTS[boost][1]


static func boost_text(boost: int) -> String:
	return BOOSTS[boost][2]


## Embers for one player's finished run.
static func earned_for(bosses: int, victory: bool, kills: int, score_multiplier: float) -> int:
	var base := bosses * PER_BOSS + (PER_VICTORY if victory else 0) + mini(kills / KILLS_PER_EMBER, MAX_KILL_EMBERS)
	return roundi(base * clampf(score_multiplier, 0.25, 2.0))


## What the next rank of a boost costs (-1 = already maxed).
func next_price(boost: int) -> int:
	return PRICES[ranks[boost]] if ranks[boost] < MAX_RANK else -1


func can_buy(boost: int) -> bool:
	var price := next_price(boost)
	return price >= 0 and balance >= price


func buy(boost: int) -> bool:
	if not can_buy(boost):
		return false
	balance -= next_price(boost)
	ranks[boost] += 1
	return true


## Everything spent comes back (free, any time).
func refund_all() -> void:
	balance += spent()
	ranks.fill(0)


func spent() -> int:
	var total := 0
	for boost: int in ranks.size():
		for rank: int in ranks[boost]:
			total += PRICES[rank]
	return total


## Every boost bought to the top.
static func full_price() -> int:
	var per_boost := 0
	for price: int in PRICES:
		per_boost += price
	return per_boost * BOOSTS.size()


## The ranks this player brings to a run (all zero while switched off).
func active_ranks() -> PackedInt32Array:
	if enabled:
		return ranks.duplicate()
	var none := PackedInt32Array()
	none.resize(BOOSTS.size())
	return none


## Untrusted ranks (from the network) cleaned up: right length, each 0..MAX_RANK.
static func clean_ranks(data: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(BOOSTS.size())
	for boost: int in mini(data.size(), BOOSTS.size()):
		result[boost] = clampi(data[boost], 0, MAX_RANK)
	return result


## Applies boost ranks to one player's stats. Every peer runs this when the
## player spawns, so all copies of the stats match.
static func apply(boost_ranks: PackedInt32Array, stats: CharacterStats) -> void:
	var clean := clean_ranks(boost_ranks)
	for boost: int in clean.size():
		var amount: float = BOOSTS[boost][3] * clean[boost]
		if amount <= 0.0:
			continue
		match boost:
			Boost.KEEN_EYE:
				stats.crit_chance = clampf(stats.crit_chance + amount, 0.0, 1.0)
			Boost.SWIFTNESS:
				stats.move_speed *= 1.0 + amount
			Boost.FOCUS:
				stats.ability_cooldown *= 1.0 - amount
			Boost.GREED:
				stats.coin_luck += amount
			Boost.REACH:
				stats.pickup_radius *= 1.0 + amount
			Boost.RESOLVE:
				stats.hit_invulnerability += amount


static func load_saved() -> Embers:
	var embers := Embers.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return embers
	embers.balance = maxi(int(file.get_value("embers", "balance", 0)), 0)
	embers.total_earned = maxi(int(file.get_value("embers", "total_earned", 0)), 0)
	embers.enabled = bool(file.get_value("embers", "enabled", true))
	var saved: Variant = file.get_value("embers", "ranks", PackedInt32Array())
	if saved is PackedInt32Array or saved is Array:
		embers.ranks = clean_ranks(PackedInt32Array(saved))
	return embers


func save() -> void:
	var file := ConfigFile.new()
	file.set_value("embers", "balance", balance)
	file.set_value("embers", "total_earned", total_earned)
	file.set_value("embers", "enabled", enabled)
	file.set_value("embers", "ranks", ranks)
	file.save(path)


## Adds a run's Embers to the saved total and returns the new state.
static func add_earned(amount: int) -> Embers:
	var embers := load_saved()
	embers.balance += maxi(amount, 0)
	embers.total_earned += maxi(amount, 0)
	embers.save()
	return embers
