class_name PlayerHealth
extends RefCounted
## HP and the short safety windows after hits. The host owns this; clients
## receive copies through snapshots.
##
## Two kinds of damage (owner decision, v0.22.0):
## - Enemy bullets hit hard and then give a moment of safety from bullets.
## - Touching enemies drains a little every CONTACT_INTERVAL while they touch
##   you, with no safety: being surrounded is deadly.
## `invulnerable_left` (reviving, Grave Blast) protects from both.

## Seconds between drains while enemies touch you.
const CONTACT_INTERVAL: float = 0.5

var max_hp: int = 100
var hp: int = 100
## Safe from everything (revives, Grave Blast).
var invulnerable_left: float = 0.0
## Safe from enemy bullets only (after a bullet hit).
var bullet_safe_left: float = 0.0
## Counts down while enemies touch you; at 0 the next touch drains again.
var contact_left: float = 0.0
## Recovery: fractions of an HP not yet healed.
var _regen_carry: float = 0.0


func reset(max_value: int) -> void:
	max_hp = max_value
	hp = max_value
	invulnerable_left = 0.0
	bullet_safe_left = 0.0
	contact_left = 0.0
	_regen_carry = 0.0


func is_downed() -> bool:
	return hp <= 0


func is_invulnerable() -> bool:
	return invulnerable_left > 0.0


## True if an enemy bullet would pass through right now.
func is_bullet_safe() -> bool:
	return invulnerable_left > 0.0 or bullet_safe_left > 0.0


func ratio() -> float:
	return clampf(float(hp) / maxf(max_hp, 1.0), 0.0, 1.0)


## `recovery` = HP regenerated per second.
func tick(delta: float, recovery: float = 0.0) -> void:
	invulnerable_left = maxf(invulnerable_left - delta, 0.0)
	bullet_safe_left = maxf(bullet_safe_left - delta, 0.0)
	contact_left = maxf(contact_left - delta, 0.0)
	if recovery > 0.0 and not is_downed() and hp < max_hp:
		_regen_carry += recovery * delta
		var whole := floori(_regen_carry)
		if whole > 0:
			_regen_carry -= whole
			heal(whole)


## An enemy bullet. Returns true if it landed (not downed, not safe).
func take_bullet(amount: int, safe_seconds: float) -> bool:
	if is_downed() or is_bullet_safe():
		return false
	hp = maxi(hp - amount, 0)
	bullet_safe_left = safe_seconds
	return true


## Enemies touching you (`amount` = all of them together). Drains at most once
## per CONTACT_INTERVAL. Returns true if it landed.
func take_contact(amount: int) -> bool:
	if is_downed() or is_invulnerable() or contact_left > 0.0 or amount <= 0:
		return false
	hp = maxi(hp - amount, 0)
	contact_left = CONTACT_INTERVAL
	return true


func heal(amount: int) -> void:
	if is_downed():
		return
	hp = mini(hp + amount, max_hp)


## Heals this share of max HP (at least 1).
func heal_share(share: float) -> void:
	heal(maxi(roundi(max_hp * share), 1))
