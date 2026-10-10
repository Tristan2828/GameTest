class_name HitBonus
extends RefCounted
## Damage bonuses from a player's upgrades (crits, Giant Slayer, Executioner).
## Pure math; the host applies it in EnemyManager.damage() before hex damage.

const CRIT_MULTIPLIER: float = 2.0
## Executioner counts enemies below this share of their health as wounded.
const WOUNDED_RATIO: float = 0.5


## Only main-weapon hits can crit. `roll` is a random number in 0..1.
static func is_crit(stats: CharacterStats, source: int, roll: float) -> bool:
	return source == DamageSource.MAIN_GUN and roll < stats.crit_chance


## `amount` with the attacker's boss / wounded bonuses (and the crit) applied.
static func scaled(amount: int, stats: CharacterStats, is_boss: bool, hp_ratio: float, crit: bool) -> int:
	var multiplier := 1.0
	if is_boss:
		multiplier += stats.boss_damage_bonus
	if hp_ratio < WOUNDED_RATIO:
		multiplier += stats.wounded_damage_bonus
	if crit:
		multiplier *= CRIT_MULTIPLIER
	return roundi(amount * multiplier)
