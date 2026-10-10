class_name LocalInput
extends Node
## Reads this computer's keyboard or gamepad (movement only) and turns it into
## PlayerInput. The main weapon aims and fires by itself (AutoAim), from the
## enemies this screen shows.

const AUTOPILOT_REVIVE_REACH: float = 0.4

## True while a menu (pause) is open: the player stands still (the weapons keep going).
static var blocked: bool = false

## The way the hero faces: the last direction they moved (the Reaper's Scythe flies this way).
var facing: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _autopilot_time: float = 0.0


func _ready() -> void:
	_rng.randomize()


## Call once per physics tick.
func sample(player: Player, delta: float) -> PlayerInput:
	var input := PlayerInput.new()
	if LaunchOptions.autopilot:
		input.move = _autopilot_move(player, delta)
	elif not blocked:
		input.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.move.length_squared() > 0.01:
		facing = input.move.angle()
	var enemies := player.get_tree().get_first_node_in_group("enemy_manager") as EnemyManager
	var targets := enemies.active_positions() if enemies != null else PackedVector2Array()
	var boss := enemies.find_boss() if enemies != null else null
	var aim := AutoAim.pick(player.stats, player.state.position, facing, targets, _rng.randf(),
		boss.position if boss != null else Vector2.INF)
	input.fire = not is_nan(aim)
	input.aim = aim if input.fire else facing
	return input


## Test mode (`--autopilot`): kite away from the nearest enemy, drift in a
## circle, grab altars and map events, and go revive downed teammates.
func _autopilot_move(player: Player, delta: float) -> Vector2:
	_autopilot_time += delta
	var move := Vector2.from_angle(_autopilot_time * 0.7) * 0.5

	var nearest: Enemy = null
	var nearest_distance := INF
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.active:
			continue
		var distance := enemy.global_position.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest != null:
		var to_enemy := nearest.global_position - player.global_position
		var downed := _downed_teammate(player)
		if downed != null and not player.is_downed():
			var to_downed := downed.global_position - player.global_position
			return to_downed.normalized() if to_downed.length() > Revive.RADIUS * AUTOPILOT_REVIVE_REACH else Vector2.ZERO
		# Weapon altars are worth pushing through a crowd for.
		var weapons := player.get_tree().get_first_node_in_group("altars") as WeaponSystem
		if weapons != null and to_enemy.length() > 50.0:
			var altar := weapons.nearest_altar(player.global_position)
			if altar.is_finite() and altar.distance_to(player.global_position) < 400.0:
				return (altar - player.global_position).normalized()
		# So are map events (stand in rituals, wake champions, open chests).
		var events := player.get_tree().get_first_node_in_group("map_events") as MapEvents
		if events != null and to_enemy.length() > 40.0:
			var spot := events.nearest(player.global_position)
			var distance := spot.distance_to(player.global_position) if spot.is_finite() else INF
			if distance < 500.0:
				return (spot - player.global_position).normalized() if distance > 16.0 else Vector2.ZERO
		if to_enemy.length() < 120.0:
			return (move - to_enemy.normalized()).limit_length(1.0)
	# Nothing close: vacuum up XP.
	var gems := player.get_tree().get_first_node_in_group("gems") as GemManager
	if gems != null:
		var gem := gems.nearest_gem(player.global_position)
		if gem.is_finite() and gem.distance_to(player.global_position) < 300.0:
			return (gem - player.global_position).normalized()
	return move


## Autopilot: the nearest downed teammate, or null.
func _downed_teammate(player: Player) -> Player:
	var best: Player = null
	for node: Node in player.get_parent().get_children():
		var other := node as Player
		if other == null or other == player or not other.is_downed():
			continue
		if best == null or other.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = other
	return best
