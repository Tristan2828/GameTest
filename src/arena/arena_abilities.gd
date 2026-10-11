class_name ArenaAbilities
extends Node
## The arena's part that resolves Grave Blast, Hex Snare and Bone Effigy (auto
## weapons that go off at a spot WeaponSystem picks) and Corpse Blast bursts.
## The host does the damage; every peer draws them from a small event.
##
## A child node of the Arena (in arena.tscn), so its RPCs reach the same node on
## every peer. It uses the arena's managers and players directly.

## Corpse Blast (upgrade): how far a burst reaches, and its color.
const KILL_BURST_RADIUS: float = 32.0
const KILL_BURST_COLOR: Color = Color(0.5, 0.95, 0.55)
const EFFIGY_COLOR: Color = Color(0.84, 0.8, 0.68)

## Host: Bone Effigies standing in the arena.
var effigies: Array[Effigy] = []
## Host: Corpse Blast bursts waiting to go off this tick (position, damage, owner).
var _burst_positions: PackedVector2Array = PackedVector2Array()
var _burst_damages: PackedInt32Array = PackedInt32Array()
var _burst_owners: PackedInt32Array = PackedInt32Array()

@onready var arena: Arena = get_parent() as Arena


## Host: one Bone Effigy (a decoy that bursts when its time runs out).
class Effigy:
	var position: Vector2
	var time_left: float
	var lure_radius: float
	var burst_radius: float
	var burst_damage: int
	var owner_peer_id: int
	var source: int = DamageSource.ABILITY


## Host: one of a player's auto weapons that used to be a hero ability goes off
## at `at` (WeaponSystem picked the spot). Resolve it and show it everywhere.
func on_ability_cast(caster: Player, weapon_id: int, level: int, at: Vector2) -> void:
	var weapon := AutoWeapons.get_weapon(weapon_id)
	var power := caster.stats.auto_power
	var source := DamageSource.of_weapon(weapon_id)
	match weapon.kind:
		AutoWeapon.Kind.BLAST:
			caster.health.invulnerable_left = maxf(caster.health.invulnerable_left, weapon.duration)
			caster.health.heal_share(AutoWeapons.BLAST_HEAL_SHARE)
			arena._enemies.damage_in_radius(at, weapon.radius_at(level), arena._weapons.power(caster, weapon.damage_at(level)),
				caster.peer_id, source)
			detonate_blast(at, weapon.reach)
			for peer_id: int in arena._ready_peers:
				_receive_blast.rpc_id(peer_id, at, weapon.reach)
		AutoWeapon.Kind.HEX:
			var radius := weapon.radius_at(level)
			var seconds := weapon.duration * power
			arena._enemies.hex_in_radius(at, radius, seconds, AutoWeapons.HEX_DAMAGE_MULTIPLIER)
			_show_hex(at, radius, seconds)
			for peer_id: int in arena._ready_peers:
				_receive_hex.rpc_id(peer_id, at, radius, seconds)
		AutoWeapon.Kind.EFFIGY:
			var effigy := Effigy.new()
			effigy.position = at
			effigy.time_left = weapon.duration * power
			effigy.lure_radius = weapon.reach
			effigy.burst_radius = weapon.radius_at(level)
			effigy.burst_damage = arena._weapons.power(caster, weapon.damage_at(level))
			effigy.owner_peer_id = caster.peer_id
			effigy.source = source
			effigies.append(effigy)
			_show_effigy(effigy.position, effigy.time_left, effigy.lure_radius, caster.slot)
			for peer_id: int in arena._ready_peers:
				_receive_effigy.rpc_id(peer_id, effigy.position, effigy.time_left, effigy.lure_radius, caster.slot)


## Host: count down effigies; an expired one bursts, damaging enemies around it.
func tick_effigies(delta: float) -> void:
	for i: int in range(effigies.size() - 1, -1, -1):
		var effigy := effigies[i]
		effigy.time_left -= delta
		if effigy.time_left > 0.0:
			continue
		effigies.remove_at(i)
		arena._enemies.damage_in_radius(effigy.position, effigy.burst_radius, effigy.burst_damage, effigy.owner_peer_id,
			effigy.source)
		_effigy_burst(effigy.position, effigy.burst_radius)
		for peer_id: int in arena._ready_peers:
			_receive_effigy_burst.rpc_id(peer_id, effigy.position, effigy.burst_radius)


func effigy_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for effigy: Effigy in effigies:
		positions.append(effigy.position)
	return positions


func effigy_lure_radius() -> float:
	var radius := 0.0
	for effigy: Effigy in effigies:
		radius = maxf(radius, effigy.lure_radius)
	return radius


## Host: a Corpse Blast burst goes off at the end of this tick's hit check.
func queue_kill_burst(at: Vector2, damage: int, owner_peer_id: int) -> void:
	_burst_positions.append(at)
	_burst_damages.append(damage)
	_burst_owners.append(owner_peer_id)


## Host: set off this tick's Corpse Blast bursts, and show them everywhere (one
## message for all of them).
func resolve_kill_bursts() -> void:
	if _burst_positions.is_empty():
		return
	for i: int in _burst_positions.size():
		arena._enemies.damage_in_radius(_burst_positions[i], KILL_BURST_RADIUS, _burst_damages[i], _burst_owners[i],
			DamageSource.KILL_BURST)
	_show_kill_bursts(_burst_positions)
	for peer_id: int in arena._ready_peers:
		_receive_kill_bursts.rpc_id(peer_id, _burst_positions.size(), _burst_positions)
	_burst_positions.clear()
	_burst_damages.clear()
	_burst_owners.clear()


## Everyone: the stage ended; effigies and lingering markers go.
func clear() -> void:
	effigies.clear()
	for marker: Node in get_tree().get_nodes_in_group(&"ability_markers"):
		marker.queue_free()


## Everyone: clear enemy bullets and show the blast (Grave Blast, Holy Bomb).
func detonate_blast(at: Vector2, radius: float) -> void:
	arena._shake_local(6.0)
	Sfx.play(&"bomb")
	arena._enemy_bullets.clear_near(at, radius)
	var blast := BombBlast.new()
	blast.radius = radius
	blast.position = at
	arena.add_child(blast)


## Everyone: Corpse Blast bursts. Rings only near this player (they're many).
func _show_kill_bursts(positions: PackedVector2Array) -> void:
	for at: Vector2 in positions:
		arena._effects.burst(at, KILL_BURST_COLOR, 6, 70.0, 0.3, 1.0)
		if arena._near_local_player(at, 260.0):
			var ring := BombBlast.new()
			ring.radius = KILL_BURST_RADIUS
			ring.color = KILL_BURST_COLOR
			ring.position = at
			arena.add_child(ring)


## Everyone: the hex sigil on the ground.
func _show_hex(at: Vector2, radius: float, seconds: float) -> void:
	var marker := AbilityMarker.new()
	marker.kind = AbilityMarker.Kind.HEX
	marker.radius = radius
	marker.duration = seconds
	marker.position = at
	marker.add_to_group(&"ability_markers")
	arena.add_child(marker)
	arena._effects.burst(at, AbilityMarker.HEX_COLOR, 16, 90.0, 0.4, 1.5)
	if arena._near_local_player(at):
		Sfx.play(&"hex", -4.0)


## Everyone: the effigy rises (it lives as long as the host's copy).
func _show_effigy(at: Vector2, seconds: float, lure_radius: float, slot: int) -> void:
	var marker := AbilityMarker.new()
	marker.kind = AbilityMarker.Kind.EFFIGY
	marker.radius = lure_radius
	marker.duration = seconds
	marker.color = Player.SLOT_COLORS[slot % Player.SLOT_COLORS.size()]
	marker.position = at
	marker.add_to_group(&"ability_markers")
	arena.add_child(marker)
	arena._effects.burst(at, EFFIGY_COLOR, 10, 50.0, 0.35, 1.0)
	if arena._near_local_player(at):
		Sfx.play(&"effigy", -3.0)


## Everyone: the effigy bursts.
func _effigy_burst(at: Vector2, radius: float) -> void:
	var blast := BombBlast.new()
	blast.radius = radius
	blast.color = EFFIGY_COLOR
	blast.position = at
	arena.add_child(blast)
	arena._effects.burst(at, EFFIGY_COLOR, 18, 120.0, 0.45, 1.5)
	if arena._near_local_player(at):
		arena._shake_local(3.0)
		Sfx.play(&"bomb", -8.0, 1.4)


@rpc("authority", "call_remote", "reliable")
func _receive_blast(at: Vector2, radius: float) -> void:
	detonate_blast(at, radius)


@rpc("authority", "call_remote", "reliable")
func _receive_hex(at: Vector2, radius: float, seconds: float) -> void:
	_show_hex(at, radius, seconds)


@rpc("authority", "call_remote", "reliable")
func _receive_effigy(at: Vector2, seconds: float, lure_radius: float, slot: int) -> void:
	_show_effigy(at, seconds, lure_radius, slot)


@rpc("authority", "call_remote", "reliable")
func _receive_kill_bursts(count: int, positions: PackedVector2Array) -> void:
	if count > 0:
		_show_kill_bursts(positions)


@rpc("authority", "call_remote", "reliable")
func _receive_effigy_burst(at: Vector2, radius: float) -> void:
	_effigy_burst(at, radius)
