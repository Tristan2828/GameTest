class_name Arena
extends Node2D
## One stage of a run: players, the enemy horde, bullets, and the boss.
## A stage is WAVE_DURATION of horde, then the boss arrives; killing it clears the stage.
##
## Every physics tick (while the run is being played) runs in a fixed order:
## players -> spawning -> enemies -> contact damage -> bullets -> hits -> gems -> phase check.
## Level-ups pause all of that (phase LEVEL_UP) until LevelUpController is done.
## The host then sends snapshots to every client that has finished loading.

signal restart_requested

## Values are sent over the network: only add new phases at the end.
enum Phase { PLAYING, STAGE_CLEAR, RUN_OVER, LEVEL_UP, SHOP, VICTORY }

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const BOUNDS: Rect2 = Rect2(0, 0, 1600, 1000)
## A run is this many stages; beating the last boss is Victory.
const STAGE_COUNT: int = 3
## Each stage after the first: +35% spawn rate and +50% enemy HP (cumulative, linear).
const STAGE_SPAWN_RATE_GROWTH: float = 0.35
const STAGE_HP_GROWTH: float = 0.5
## Seconds the "Stage cleared" banner shows before the shop opens.
const STAGE_CLEAR_DELAY: float = 4.0
## Coins every player gets for beating a stage's boss (more in later stages).
const BOSS_BOUNTY: int = 20
const BOSS_BOUNTY_PER_STAGE: int = 10
## Horde waves last this long, then the boss arrives.
const WAVE_DURATION: float = 240.0
## Horde spawn rate while the boss is alive (and no pack surges).
const BOSS_FIGHT_SPAWN_RATE: float = 0.4
const BOSS_SPAWN_DISTANCE: float = 220.0
const BOSS_BANNER_SECONDS: float = 3.0
## 60 physics ticks per second / 2 = 30 player snapshots per second.
const PLAYER_SNAPSHOT_INTERVAL_TICKS: int = 2
## Enemies are smoothed on clients anyway, so 15 per second is plenty.
const ENEMY_SNAPSHOT_INTERVAL_TICKS: int = 4
const SPAWN_OFFSETS: Array[Vector2] = [Vector2(-24, -24), Vector2(24, -24), Vector2(-24, 24), Vector2(24, 24)]
## Enemy bullets: hearts per hit and how long they fly.
const ENEMY_BULLET_DAMAGE: int = 1
const ENEMY_BULLET_LIFETIME: float = 7.0
## Bombs: clear enemy bullets in a big radius, hurt enemies in a smaller one.
const BOMB_CLEAR_RADIUS: float = 220.0
const BOMB_DAMAGE_RADIUS: float = 90.0
const BOMB_DAMAGE: int = 60
const BOMB_INVULNERABILITY: float = 1.5
## Clients fast-forward enemy patterns by at most this much (very laggy = less fair, not broken).
const MAX_PATTERN_FAST_FORWARD: float = 0.4
## Enemies appear just off-screen: the screen is 640x360, so ~367 px to a corner.
const SPAWN_DISTANCE_MIN: float = 380.0
const SPAWN_DISTANCE_MAX: float = 440.0
const MIN_SPAWN_DISTANCE_FROM_ANY_PLAYER: float = 340.0
const PACK_RADIUS: float = 28.0
const CONTROLS_HINT: String = "WASD / L-stick move   Mouse / R-stick aim   LMB / RT fire   Space / LT dash   Q / RB bomb   Esc / Start menu"
const COPIED_FEEDBACK_SECONDS: float = 4.0
const SPARK_COLOR: Color = Color(1.0, 0.9, 0.6)
const HURT_COLOR: Color = Color(1.0, 0.25, 0.3)
## In --autopilot test mode, the host restarts by itself this long after a stage ends.
const AUTOPILOT_RESTART_DELAY: float = 2.0

var _phase: Phase = Phase.PLAYING
## Current stage, 1..STAGE_COUNT (host-owned, synced in snapshots).
var _stage: int = 1
var _stage_clear_left: float = 0.0
var _elapsed: float = 0.0
var _wave_duration: float = WAVE_DURATION
var _boss_brain: BossBrain = null
## Turning angle for SPIN boss steps.
var _boss_spin: float = 0.0
## Host: the boss has been spawned this stage.
var _boss_spawned: bool = false
## Host: the boss died this tick (the stage ends at the phase check).
var _boss_defeated: bool = false
## Everyone: we've seen the boss (for the intro banner and "BOSS" timer).
var _boss_seen: bool = false
var _boss_banner_left: float = 0.0
## Host: peers whose arena has loaded, so they can receive snapshots and shots.
var _ready_peers: Dictionary[int, bool] = {}
var _tick: int = 0
var _director: SpawnDirector = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Host: kills per peer id (for reports; scoreboards later).
var _kills_by_peer: Dictionary[int, int] = {}
## Shared team XP and level (host-owned, copied to clients in snapshots).
var _team: TeamProgress = TeamProgress.new()
var _copied_feedback_left: float = 0.0
var _announced_invite: bool = false
var _time_since_stage_end: float = 0.0
# Host: enemy pattern events fired this tick, sent once per tick.
var _pattern_ids: PackedInt32Array = PackedInt32Array()
var _pattern_origins: PackedVector2Array = PackedVector2Array()
var _pattern_aims: PackedFloat32Array = PackedFloat32Array()
var _pattern_seeds: PackedInt32Array = PackedInt32Array()
var _pattern_times: PackedFloat32Array = PackedFloat32Array()

@onready var _players: Node2D = $Players
@onready var _player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var _enemies: EnemyManager = $Enemies
@onready var _gems: GemManager = $Gems
@onready var _coins: GemManager = $Coins
@onready var _shop: ShopController = $Shop
@onready var _weapons: WeaponSystem = $Weapons
@onready var _projectiles: ProjectileManager = $Projectiles
@onready var _enemy_bullets: ProjectileManager = $EnemyProjectiles
@onready var _level_up: LevelUpController = $LevelUp
@onready var _hud: Hud = $Hud
@onready var _floor: ArenaFloor = $Floor
@onready var _effects: EffectsLayer = $Effects


func _ready() -> void:
	# Every peer needs the spawn function: the host calls it via spawn(), and
	# clients call it automatically with the same data when the spawn replicates.
	_player_spawner.spawn_function = _spawn_player
	_projectiles.bounds = BOUNDS
	_enemy_bullets.bounds = BOUNDS
	_enemies.bounds = BOUNDS
	_rng.randomize()
	if multiplayer.is_server():
		_stage = LaunchOptions.start_stage
	_setup_stage()
	_level_up.bind_panel(_hud.level_up_panel)
	_shop.bind(_hud.shop_panel, _player_by_id, _ready_peer_list)
	_shop.relic_bought.connect(_on_relic_bought)
	_weapons.bounds = BOUNDS
	_enemies.enemy_vanished.connect(_on_enemy_vanished)
	_projectiles.hit_at.connect(func(at: Vector2) -> void:
		_effects.burst(at, SPARK_COLOR, 3, 60.0, 0.15, 1.0)
		if _near_local_player(at):
			Sfx.play(&"hit", -10.0))
	_gems.picked_up_at.connect(func(at: Vector2) -> void:
		if _near_local_player(at, 60.0):
			Sfx.play(&"gem", -8.0, 1.0 + randf() * 0.3))
	_coins.picked_up_at.connect(func(at: Vector2) -> void:
		if _near_local_player(at, 60.0):
			Sfx.play(&"coin", -6.0))
	_weapons.weapon_gained.connect(_on_weapon_gained)
	_level_up.upgrade_announced.connect(_on_upgrade_announced)
	if LaunchOptions.stage_seconds > 0.0:
		_wave_duration = LaunchOptions.stage_seconds
	if multiplayer.is_server():
		_elapsed = LaunchOptions.start_at_seconds
		Net.invite.changed.connect(_on_invite_changed)
		_on_invite_changed()
		_enemies.enemy_killed.connect(_on_enemy_killed)
		_enemies.pattern_fired.connect(_fire_enemy_pattern)
		_gems.collected.connect(_on_gem_collected)
		_coins.collected.connect(_on_coin_collected)
		_weapons.seeker_fired.connect(_fire_seeker)
		multiplayer.peer_connected.connect(_add_player)
		multiplayer.peer_disconnected.connect(_remove_player)
		_add_player(1)
		var peers: Array[int] = []
		peers.assign(multiplayer.get_peers())
		# Same order as the lobby, so everyone keeps their color.
		peers.sort_custom(func(a: int, b: int) -> bool:
			return _lobby_rank(a) < _lobby_rank(b))
		for peer_id: int in peers:
			_add_player(peer_id)
	else:
		_notify_ready.rpc_id(1)


func _physics_process(delta: float) -> void:
	var is_host := multiplayer.is_server()
	if _phase == Phase.PLAYING:
		_elapsed += delta
		for player: Player in _player_nodes():
			player.tick(delta)
		if is_host:
			_spawn_enemies(delta)
			_enemies.tick_host(delta, _alive_player_positions())
			_tick_boss(delta)
			_weapons.tick_host(delta, _elapsed, _player_nodes(), _enemies, _ready_peer_list())
			_apply_contact_damage()
		else:
			_enemies.rebuild_grid()
		_projectiles.step(delta)
		_projectiles.resolve_hits(_enemies, is_host)
		_enemy_bullets.step(delta)
		_enemy_bullets.resolve_player_hits(_player_nodes(), is_host)
		_tick_gems(delta, is_host)
		if is_host:
			_update_phase()
		if is_host and _phase == Phase.PLAYING and _level_up.host_should_start():
			_start_level_up()
	elif _phase == Phase.LEVEL_UP:
		if is_host and _level_up.host_tick(delta, _ready_peer_list()):
			if _level_up.host_should_start():
				_start_level_up()
			else:
				_phase = Phase.PLAYING
	elif _phase == Phase.STAGE_CLEAR:
		if is_host:
			_stage_clear_left -= delta
			if _stage_clear_left <= 0.0:
				_phase = Phase.SHOP
				_shop.host_start(_player_nodes(), _ready_peer_list())
	elif _phase == Phase.SHOP:
		if is_host and _shop.host_tick(delta):
			_begin_next_stage()
	elif is_host and LaunchOptions.autopilot:
		# Only RUN_OVER / VICTORY reach here: the run is finished.
		_time_since_stage_end += delta
		if _time_since_stage_end >= AUTOPILOT_RESTART_DELAY:
			_time_since_stage_end = -INF
			restart_requested.emit()
	if is_host:
		_tick += 1
		_send_snapshots()


var _jingle_phase: Phase = Phase.PLAYING


func _play_phase_jingle() -> void:
	if _phase == _jingle_phase:
		return
	_jingle_phase = _phase
	match _phase:
		Phase.VICTORY, Phase.STAGE_CLEAR:
			Sfx.play(&"victory", -2.0)
		Phase.RUN_OVER:
			Sfx.play(&"defeat", -2.0)


func _process(delta: float) -> void:
	for player: Player in _player_nodes():
		player.weapon_clock = _elapsed
	_copied_feedback_left = maxf(_copied_feedback_left - delta, 0.0)
	_boss_banner_left = maxf(_boss_banner_left - delta, 0.0)
	_play_phase_jingle()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("copy_invite") and Net.invite.copy_to_clipboard():
		_copied_feedback_left = COPIED_FEEDBACK_SECONDS
	if event.is_action_pressed("restart") and multiplayer.is_server() and _is_run_finished():
		restart_requested.emit()


## A text summary for headless smoke tests (see LaunchOptions --run-for).
func debug_report() -> String:
	var lines := PackedStringArray()
	var role := "host" if multiplayer.is_server() else "client"
	lines.append("[report] peer %d (%s)  stage %d  phase=%s  time=%.1fs" % [multiplayer.get_unique_id(), role, _stage, Phase.keys()[_phase], _elapsed])
	for player: Player in _player_nodes():
		var line := "[report]   player %d (%s) slot %d at %s  hearts %d/%d  bombs %d  coins %d  upgrades %s  relics %s" % [
			player.peer_id, player.stats.display_name, player.slot, player.position.round(), player.health.hearts, player.health.max_hearts,
			player.bombs_left, player.coins, player.upgrade_ids, player.relic_ids]
		line += "  weapons %s" % [player.weapon_levels]
		if player.is_local() and not multiplayer.is_server():
			line += "  corrections=%d largest=%.2fpx" % [player.correction_count, player.largest_correction]
		lines.append(line)
	lines.append("[report]   active enemies: %d   gems on ground: %d   team level %d (%d xp)" % [
		_enemies.active_count(), _gems.count(), _team.level, _team.xp])
	if multiplayer.is_server():
		lines.append("[report]   damage by peer: %s" % [_enemies.damage_by_peer])
		lines.append("[report]   kills by peer: %s" % [_kills_by_peer])
		lines.append("[report]   invite: '%s'  %s" % [Net.invite.address, Net.invite.status])
	lines.append("[report]   enemy bullets alive: %d   altars: %d" % [_enemy_bullets.count(), _weapons.altar_count()])
	var boss := _enemies.find_boss()
	if boss != null:
		lines.append("[report]   boss: %s hp %.0f%% phase %d" % [boss.type.display_name, boss.hp_ratio * 100.0, _boss_brain.phase])
	lines.append("[report]   bullets alive: %d   physics time: %.2f ms/tick" % [_projectiles.count(), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	return "\n".join(lines)


# --- Players -----------------------------------------------------------------

func _player_nodes() -> Array[Player]:
	var result: Array[Player] = []
	for child: Node in _players.get_children():
		var player := child as Player
		if player != null and not player.is_queued_for_deletion():
			result.append(player)
	return result


func _player_by_id(peer_id: int) -> Player:
	return _players.get_node_or_null(str(peer_id)) as Player


func _local_player() -> Player:
	return _player_by_id(multiplayer.get_unique_id())


func _alive_player_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for player: Player in _player_nodes():
		if not player.is_downed():
			positions.append(player.state.position)
	return positions


func _add_player(peer_id: int) -> void:
	_player_spawner.spawn({"peer_id": peer_id, "slot": _free_slot(), "character": RunSetup.character_for(peer_id)})
	if LaunchOptions.give_weapons:
		# Test aid: same path as real pickups (new joiners also get it via history).
		for weapon_id: int in AutoWeapons.ALL.size():
			for level: int in 2:
				_weapons.grant(peer_id, weapon_id, _ready_peer_list())


func _lobby_rank(peer_id: int) -> int:
	var index := RunSetup.order.find(peer_id)
	return index if index >= 0 else 1000 + peer_id


func _remove_player(peer_id: int) -> void:
	_ready_peers.erase(peer_id)
	_level_up.host_remove_player(peer_id)
	_shop.host_remove_player(peer_id)
	var player := _player_by_id(peer_id)
	if player != null:
		player.queue_free()


func _spawn_player(data: Variant) -> Node:
	var info: Dictionary = data
	var peer_id: int = info["peer_id"]
	var slot: int = info["slot"]
	var character: int = info.get("character", Characters.Id.WANDERER)
	if not Characters.is_valid_id(character):
		character = Characters.Id.WANDERER
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(peer_id, slot, BOUNDS.get_center() + SPAWN_OFFSETS[slot], BOUNDS, character)
	player.shot_requested.connect(_on_player_shot_requested)
	player.bomb_requested.connect(_on_player_bomb_requested)
	player.hurt.connect(_on_player_hurt)
	return player


func _free_slot() -> int:
	var used: Array[int] = []
	for player: Player in _player_nodes():
		used.append(player.slot)
	for slot: int in Net.MAX_PLAYERS:
		if not used.has(slot):
			return slot
	return 0


# --- Host simulation ---------------------------------------------------------

func _spawn_enemies(delta: float) -> void:
	var alive_players := _alive_player_positions()
	if alive_players.is_empty():
		return
	var rate := BOSS_FIGHT_SPAWN_RATE if _boss_spawned else 1.0
	rate *= 1.0 + STAGE_SPAWN_RATE_GROWTH * (_stage - 1)
	for type_id: int in _director.tick(delta, _elapsed, alive_players.size(), _enemies.active_count(), rate):
		var point := _offscreen_spawn_point(alive_players)
		if point.is_finite():
			_enemies.spawn(type_id, point, _scaled_hp(type_id))
	if not _boss_spawned and _director.pack_due(_elapsed, _enemies.active_count()):
		var center := _offscreen_spawn_point(alive_players)
		if center.is_finite():
			var pack_type := Stages.get_stage(_stage).pack_type
			for i: int in SpawnDirector.PACK_SIZE:
				var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, PACK_RADIUS)
				_enemies.spawn(pack_type, (center + offset).clamp(BOUNDS.position, BOUNDS.end), _scaled_hp(pack_type))


## Enemy max HP for the current stage.
func _scaled_hp(type_id: int) -> int:
	return roundi(EnemyTypes.get_type(type_id).max_hp * (1.0 + STAGE_HP_GROWTH * (_stage - 1)))


## A point just off-screen from a random player, inside the arena and not too
## close to anyone. Returns Vector2.INF if none was found (spawn is skipped).
func _offscreen_spawn_point(alive_players: Array[Vector2]) -> Vector2:
	var inner := BOUNDS.grow(-16.0)
	for attempt: int in 12:
		var around := alive_players[_rng.randi() % alive_players.size()]
		var distance := _rng.randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
		var point := around + Vector2.from_angle(_rng.randf() * TAU) * distance
		if inner.has_point(point) and _far_from_players(point, alive_players):
			return point
	return Vector2.INF


func _far_from_players(point: Vector2, alive_players: Array[Vector2]) -> bool:
	for player_position: Vector2 in alive_players:
		if point.distance_to(player_position) < MIN_SPAWN_DISTANCE_FROM_ANY_PLAYER:
			return false
	return true


func _apply_contact_damage() -> void:
	for player: Player in _player_nodes():
		if not player.can_be_hit():
			continue
		var enemy := _enemies.find_hit(player.state.position, player.stats.hitbox_radius)
		if enemy != null:
			player.take_hit(enemy.type.contact_damage)


func _update_phase() -> void:
	var players := _player_nodes()
	if not players.is_empty() and _alive_player_positions().is_empty():
		_end_stage(Phase.RUN_OVER)
	elif _boss_defeated:
		_end_stage(Phase.STAGE_CLEAR)
	elif _elapsed >= _wave_duration and not _boss_spawned:
		_spawn_boss()


func _end_stage(phase: Phase) -> void:
	if phase == Phase.STAGE_CLEAR and _stage >= STAGE_COUNT:
		phase = Phase.VICTORY
	_phase = phase
	_stage_clear_left = STAGE_CLEAR_DELAY
	if phase == Phase.STAGE_CLEAR:
		_settle_stage_rewards()
	else:
		_level_up.host_reset()
	_enemies.clear_all()
	_projectiles.clear()
	_enemy_bullets.clear()
	_gems.clear()
	_coins.clear()
	_weapons.clear_altars()
	print("Stage ended: %s at %.1fs" % [Phase.keys()[phase], _elapsed])


## Host: the next stage starts. The run (level, upgrades, relics, coins) carries
## over; everyone respawns with full hearts and bombs, ghosts included.
## Host: nothing is left behind when a stage is won. Gems still on the ground
## go to the team bar (level-ups wait for the next stage), loose coins are split
## evenly, and everyone gets the boss bounty.
func _settle_stage_rewards() -> void:
	var levels := _team.add_xp(_gems.total_value())
	if levels > 0:
		_level_up.host_queue(levels)
	var players := _player_nodes()
	if players.is_empty():
		return
	var share := _coins.total_value() / players.size()
	var bounty := BOSS_BOUNTY + BOSS_BOUNTY_PER_STAGE * (_stage - 1)
	for player: Player in players:
		player.coins += share + bounty


func _begin_next_stage() -> void:
	_stage += 1
	_elapsed = 0.0
	_boss_spawned = false
	_boss_defeated = false
	_setup_stage()
	_weapons.reset_stage()
	for player: Player in _player_nodes():
		player.respawn(BOUNDS.get_center() + SPAWN_OFFSETS[player.slot])
	_phase = Phase.PLAYING
	print("Stage %d begins" % _stage)


## Everyone: load the current stage's enemies, boss script and floor.
func _setup_stage() -> void:
	var stage := Stages.get_stage(_stage)
	_director = SpawnDirector.new(randi(), stage.spawns)
	_boss_brain = BossBrain.new(stage.boss_phase_one, stage.boss_phase_two)
	_boss_spin = 0.0
	_floor.apply_stage(stage)


func _spawn_boss() -> void:
	_boss_spawned = true
	var alive := _alive_player_positions()
	var center := Vector2.ZERO
	for point: Vector2 in alive:
		center += point / alive.size()
	var inner := BOUNDS.grow(-40.0)
	var at := (center + Vector2.from_angle(_rng.randf() * TAU) * BOSS_SPAWN_DISTANCE).clamp(inner.position, inner.end)
	var boss_type_id := Stages.get_stage(_stage).boss_type
	var boss_type := EnemyTypes.get_type(boss_type_id)
	var players := maxi(_player_nodes().size(), 1)
	var hit_points := roundi(_scaled_hp(boss_type_id) * (1.0 + boss_type.hp_per_extra_player * (players - 1)))
	if LaunchOptions.weak_bosses:
		hit_points = maxi(roundi(hit_points * 0.02), 1)
	_enemies.spawn(boss_type_id, at, hit_points)
	print("Boss spawned with %d HP at %.1fs" % [hit_points, _elapsed])


## Host: run the boss's attack schedule.
func _tick_boss(delta: float) -> void:
	var boss := _enemies.find_boss()
	if boss == null:
		return
	var step := _boss_brain.tick(delta, boss.hp_ratio)
	if step == null:
		return
	var targets := _alive_player_positions()
	match step.aim:
		BossStep.Aim.FIXED:
			_fire_enemy_pattern(step.pattern, boss.position, step.angle)
		BossStep.Aim.SPIN:
			_boss_spin += step.angle
			_fire_enemy_pattern(step.pattern, boss.position, _boss_spin)
		BossStep.Aim.AT_EACH_PLAYER:
			for target: Vector2 in targets:
				_fire_enemy_pattern(step.pattern, boss.position, (target - boss.position).angle())
		BossStep.Aim.AT_NEAREST:
			if not targets.is_empty():
				var nearest := targets[0]
				for target: Vector2 in targets:
					if boss.position.distance_squared_to(target) < boss.position.distance_squared_to(nearest):
						nearest = target
				_fire_enemy_pattern(step.pattern, boss.position, (nearest - boss.position).angle())


func _on_enemy_killed(enemy: Enemy, killer_peer_id: int) -> void:
	_kills_by_peer[killer_peer_id] = _kills_by_peer.get(killer_peer_id, 0) + 1
	if enemy.type.is_boss:
		# Don't end the stage mid-hit-check; the phase check does it this tick.
		_boss_defeated = true
		return
	if not _gems.spawn_host(enemy.position, enemy.type.xp_value):
		# Too many gems on the ground: grant the XP directly instead.
		_on_gem_collected(enemy.type.xp_value, killer_peer_id)
	if _rng.randf() < enemy.type.coin_chance:
		var offset := Vector2.from_angle(_rng.randf() * TAU) * 5.0
		if not _coins.spawn_host(enemy.position + offset, enemy.type.coin_value):
			_on_coin_collected(enemy.type.coin_value, killer_peer_id)
	var killer := _player_by_id(killer_peer_id)
	if killer != null:
		killer.register_kill()


## Coins are first come, first served: they go to whoever picked them up.
func _on_coin_collected(value: int, collector_peer_id: int) -> void:
	var player := _player_by_id(collector_peer_id)
	if player != null:
		player.coins += value


func _on_weapon_gained(peer_id: int, weapon_id: int) -> void:
	var player := _player_by_id(peer_id)
	if player != null:
		player.gain_weapon(weapon_id)
		if player.is_local():
			Sfx.play(&"pickup")


## Host: a Seeking Bolts volley. Clients get a small event and spawn the same bolts.
func _fire_seeker(shooter: Player, aim: float, level: int) -> void:
	var origin := shooter.state.position
	_spawn_seeker(shooter.peer_id, origin, aim, level)
	for peer_id: int in _ready_peers:
		_receive_seeker.rpc_id(peer_id, shooter.peer_id, origin, aim, level)


func _spawn_seeker(shooter_id: int, origin: Vector2, aim: float, level: int) -> void:
	var weapon := AutoWeapons.get_weapon(AutoWeapons.Id.SEEKING_BOLTS)
	for angle: float in AutoWeapons.seeker_angles(level, aim):
		_projectiles.spawn(origin, Vector2.from_angle(angle) * weapon.speed, weapon.damage_at(level),
			weapon.reach / weapon.speed, shooter_id)


func _on_relic_bought(peer_id: int, relic_id: int) -> void:
	var player := _player_by_id(peer_id)
	if player != null:
		player.apply_relic(relic_id)


func _on_gem_collected(value: int, _collector_peer_id: int) -> void:
	var levels_gained := _team.add_xp(value)
	if levels_gained > 0:
		_level_up.host_queue(levels_gained)


func _start_level_up() -> void:
	_phase = Phase.LEVEL_UP
	# With several level-ups queued, show the level this particular choice is for.
	var level := _team.level - _level_up.pending_levels + 1
	_level_up.host_start(_player_nodes(), level, _ready_peer_list())


func _on_upgrade_announced(peer_id: int, upgrade_id: int) -> void:
	var player := _player_by_id(peer_id)
	if player != null:
		player.apply_upgrade(upgrade_id)


## The whole run has ended (the host can restart).
func _is_run_finished() -> bool:
	return _phase == Phase.RUN_OVER or _phase == Phase.VICTORY


## No combat is happening: between stages or after the run.
func _is_between_stages() -> bool:
	return _phase == Phase.STAGE_CLEAR or _phase == Phase.SHOP or _is_run_finished()


func _ready_peer_list() -> Array[int]:
	var peers: Array[int] = []
	peers.assign(_ready_peers.keys())
	return peers


func _tick_gems(delta: float, is_host: bool) -> void:
	var positions: Dictionary[int, Vector2] = {}
	var radii: Dictionary[int, float] = {}
	# Ghosts collect too.
	for player: Player in _player_nodes():
		positions[player.peer_id] = player.world_position()
		radii[player.peer_id] = player.stats.pickup_radius
	_gems.tick(delta, positions, radii, is_host)
	_coins.tick(delta, positions, radii, is_host)


# --- Shots -------------------------------------------------------------------

## Runs on the host for every player's shot, and on a client for its own
## predicted shots. Only the host tells other peers about it.
func _on_player_shot_requested(shooter: Player, input_seq: int) -> void:
	var pattern := shooter.stats.shot_pattern
	var origin := shooter.muzzle_position()
	var aim := shooter.state.aim
	var seed_value := ShotPatterns.make_seed(shooter.peer_id, input_seq)
	_spawn_shot(shooter.peer_id, pattern, origin, aim, seed_value)
	if shooter.is_local():
		Sfx.play(&"shoot", -14.0)
	if multiplayer.is_server():
		for peer_id: int in _ready_peers:
			# The shooter already predicted this shot itself.
			if peer_id != shooter.peer_id:
				_receive_shot.rpc_id(peer_id, shooter.peer_id, pattern, origin, aim, seed_value)


func _spawn_shot(shooter_id: int, pattern: ShotPatterns.Id, origin: Vector2, aim: float, seed_value: int) -> void:
	var shooter := _player_by_id(shooter_id)
	if shooter == null:
		return
	var stats := shooter.stats
	var bullets := ShotPatterns.build(pattern, aim, seed_value, stats.projectile_count, stats.bullet_speed)
	for i: int in range(0, bullets.size(), ShotPatterns.STRIDE):
		var offset := Vector2(bullets[i + 3], bullets[i + 4])
		_projectiles.spawn(origin + offset, Vector2.from_angle(bullets[i]) * bullets[i + 1], stats.bullet_damage,
			stats.bullet_lifetime, shooter_id, stats.pierce, -bullets[i + 2])


## Host: a player bombed. Resolve it here and show it on every screen.
func _on_player_bomb_requested(bomber: Player) -> void:
	var at := bomber.state.position
	bomber.health.invulnerable_left = maxf(bomber.health.invulnerable_left, BOMB_INVULNERABILITY)
	if bomber.stats.bomb_heal > 0:
		bomber.health.heal(bomber.stats.bomb_heal)
	var damage := roundi(BOMB_DAMAGE * bomber.stats.bomb_damage_multiplier)
	_enemies.damage_in_radius(at, BOMB_DAMAGE_RADIUS, damage, bomber.peer_id)
	_detonate_bomb(at)
	for peer_id: int in _ready_peers:
		_receive_bomb.rpc_id(peer_id, at)


## True if `at` is close enough to this machine's player to be worth hearing.
func _near_local_player(at: Vector2, distance: float = 340.0) -> bool:
	var local := _local_player()
	return local != null and local.world_position().distance_to(at) <= distance


func _on_enemy_vanished(at: Vector2, color: Color, radius: float) -> void:
	var is_boss := radius >= 18.0
	if is_boss:
		Sfx.play(&"bomb", 2.0, 0.6)
	elif _phase == Phase.PLAYING and _near_local_player(at):
		Sfx.play(&"death", -9.0)
	_effects.burst(at, color, 24 if is_boss else 6, 120.0 if is_boss else 50.0, 0.9 if is_boss else 0.35,
		3.0 if is_boss else 1.5)
	if is_boss:
		_shake_local(10.0)


func _on_player_hurt(victim: Player) -> void:
	_effects.burst(victim.position, HURT_COLOR, 10, 70.0, 0.4)
	if victim.is_local():
		_hud.flash_hurt()
		Sfx.play(&"hurt", -3.0)


func _shake_local(strength: float) -> void:
	var local := _local_player()
	if local != null:
		local.add_shake(strength)


## Everyone: clear enemy bullets and show the blast.
func _detonate_bomb(at: Vector2) -> void:
	_shake_local(6.0)
	Sfx.play(&"bomb")
	_enemy_bullets.clear_near(at, BOMB_CLEAR_RADIUS)
	var blast := BombBlast.new()
	blast.radius = BOMB_CLEAR_RADIUS
	blast.position = at
	add_child(blast)


## Host: an enemy (or boss) fires a pattern. Spawn it here and tell clients.
func _fire_enemy_pattern(pattern: int, origin: Vector2, aim: float) -> void:
	var seed_value := _rng.randi() & 0x7fffffff
	_spawn_enemy_pattern(pattern, origin, aim, seed_value, 0.0)
	_pattern_ids.append(pattern)
	_pattern_origins.append(origin)
	_pattern_aims.append(aim)
	_pattern_seeds.append(seed_value)
	_pattern_times.append(_elapsed)


## `age` > 0 starts the pattern partway through (clients catching up on lag).
func _spawn_enemy_pattern(pattern: int, origin: Vector2, aim: float, seed_value: int, age: float) -> void:
	if _near_local_player(origin, 360.0):
		Sfx.play(&"enemy_shot", -12.0)
	var bullets := ShotPatterns.build(pattern as ShotPatterns.Id, aim, seed_value)
	for i: int in range(0, bullets.size(), ShotPatterns.STRIDE):
		var offset := Vector2(bullets[i + 3], bullets[i + 4])
		_enemy_bullets.spawn(origin + offset, Vector2.from_angle(bullets[i]) * bullets[i + 1], ENEMY_BULLET_DAMAGE,
			ENEMY_BULLET_LIFETIME, 0, 0, age - bullets[i + 2])


func _flush_enemy_patterns(peers: Array[int]) -> void:
	if _pattern_ids.is_empty():
		return
	for peer_id: int in peers:
		_receive_enemy_patterns.rpc_id(peer_id, _pattern_ids, _pattern_origins, _pattern_aims, _pattern_seeds, _pattern_times)
	_pattern_ids.clear()
	_pattern_origins.clear()
	_pattern_aims.clear()
	_pattern_seeds.clear()
	_pattern_times.clear()


# --- HUD ---------------------------------------------------------------------

func _update_hud() -> void:
	var local := _local_player()
	if local != null:
		_hud.set_hearts(local.health.hearts, local.health.max_hearts)
		_hud.set_bombs(local.bombs_left)
		_hud.set_coins(local.coins)
		_hud.set_weapons(local.weapons_summary())
	var boss := _enemies.find_boss()
	if boss == null and _elapsed < _wave_duration:
		# New stage: the next boss gets its own intro banner.
		_boss_seen = false
	if boss != null and not _boss_seen:
		_boss_seen = true
		Sfx.play(&"boss")
		_boss_banner_left = BOSS_BANNER_SECONDS
	if _is_between_stages():
		_hud.set_timer_text("")
	elif _boss_seen:
		_hud.set_timer_text("BOSS")
	else:
		_hud.set_time_left(_wave_duration - _elapsed)
	_hud.set_boss(boss.type.display_name if boss != null else "", boss.hp_ratio if boss != null else 0.0)
	_hud.set_progress(_team.level, _team.progress_ratio())

	var status := "Solo"
	if Net.is_online():
		status = "Host" if multiplayer.is_server() else "Client  ping %d ms" % Net.ping_ms()
	_hud.set_status("Stage %d/%d   %s   players %d" % [_stage, STAGE_COUNT, status, _player_nodes().size()])

	var info := CONTROLS_HINT
	if Net.is_online() and multiplayer.is_server():
		info = _invite_hud_text() + "\n" + info
	_hud.set_info(info)

	var restart_hint := "Press R / Select to return to the lobby" if multiplayer.is_server() else "Waiting for the host..."
	var name_of := func(peer_id: int) -> String:
		var player := _player_by_id(peer_id)
		return player.display_name() if player != null else "someone"
	_level_up.refresh_panel_status(name_of)
	_shop.refresh_panel(local, name_of)
	match _phase:
		Phase.SHOP:
			if _shop.is_open_locally():
				_hud.hide_banner()
			else:
				_hud.show_banner("Shop", "Other players are shopping...")
		Phase.LEVEL_UP:
			if _level_up.has_local_choices():
				_hud.hide_banner()
			else:
				_hud.show_banner("Level up!", "Others are choosing.   " + _level_up.status_text(name_of))
		Phase.STAGE_CLEAR:
			_hud.show_banner("Stage %d cleared!" % _stage, "Stage %d of %d is next. Everyone respawns." % [_stage + 1, STAGE_COUNT])
		Phase.VICTORY:
			_hud.show_banner("Victory!", "The crypt is cleansed.   " + restart_hint)
		Phase.RUN_OVER:
			_hud.show_banner("Run over", restart_hint)
		_:
			if _boss_banner_left > 0.0 and boss != null:
				_hud.show_banner("%s rises!" % boss.type.display_name, "Destroy it to clear the stage.")
			elif local != null and local.is_downed():
				_hud.show_banner("You're a ghost", "Collect XP and coins for your team. You respawn next stage.")
			else:
				_hud.hide_banner()


func _invite_hud_text() -> String:
	var invite := Net.invite
	var line := "Invite: finding your public address..."
	if not invite.address.is_empty():
		var hint := "copied to clipboard!" if _copied_feedback_left > 0.0 else "F1 to copy"
		line = "Invite: %s   (%s)" % [invite.address, hint]
	return line + "\n" + invite.status


func _on_invite_changed() -> void:
	# The invite is copied automatically the moment the address is known.
	if not Net.invite.address.is_empty() and not _announced_invite:
		_announced_invite = true
		_copied_feedback_left = COPIED_FEEDBACK_SECONDS


# --- Networking --------------------------------------------------------------

func _send_snapshots() -> void:
	if _ready_peers.is_empty():
		return
	var peers := _ready_peer_list()
	_gems.flush_events(peers)
	_coins.flush_events(peers)
	_flush_enemy_patterns(peers)
	if _tick % PLAYER_SNAPSHOT_INTERVAL_TICKS == 0:
		var ids := PackedInt32Array()
		var positions := PackedVector2Array()
		var aims := PackedFloat32Array()
		var acks := PackedInt32Array()
		var hearts := PackedByteArray()
		var max_hearts := PackedByteArray()
		var flags := PackedByteArray()
		var bombs := PackedByteArray()
		var coins := PackedInt32Array()
		for player: Player in _player_nodes():
			ids.append(player.peer_id)
			positions.append(player.state.position)
			aims.append(player.state.aim)
			acks.append(player.last_processed_seq)
			hearts.append(player.health.hearts)
			max_hearts.append(player.health.max_hearts)
			flags.append((1 if player.state.is_dashing() else 0) | (2 if player.health.is_invulnerable() else 0))
			bombs.append(player.bombs_left)
			coins.append(player.coins)
		# Whichever pause is running (level-up or shop) reports who we're waiting for.
		var in_shop := _phase == Phase.SHOP
		var waiting := PackedInt32Array(_shop.waiting_ids if in_shop else _level_up.waiting_ids)
		var countdown := _shop.countdown_left if in_shop else _level_up.countdown_left
		for peer_id: int in peers:
			_receive_player_snapshot.rpc_id(peer_id, ids, positions, aims, acks, hearts, max_hearts, flags, bombs, coins,
				_elapsed, _phase, _stage, _team.level, _team.xp, waiting, countdown)
	if _tick % ENEMY_SNAPSHOT_INTERVAL_TICKS == 0:
		_enemies.send_snapshot(peers)


## Client -> host, once, when this client's arena has loaded.
@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if multiplayer.is_server():
		var peer_id := multiplayer.get_remote_sender_id()
		_ready_peers[peer_id] = true
		_gems.send_full_state(peer_id)
		_coins.send_full_state(peer_id)
		_weapons.send_full_state(peer_id)
		_weapons.send_history(peer_id, _player_nodes())
		_level_up.host_send_history(peer_id, _player_nodes())
		_shop.host_send_history(peer_id, _player_nodes())


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_player_snapshot(ids: PackedInt32Array, positions: PackedVector2Array, aims: PackedFloat32Array,
		acks: PackedInt32Array, hearts: PackedByteArray, max_hearts: PackedByteArray, flags: PackedByteArray, bombs: PackedByteArray,
		coins: PackedInt32Array, elapsed: float, phase: int, stage: int, team_level: int, team_xp: int,
		pause_waiting: PackedInt32Array, pause_countdown: float) -> void:
	for i: int in ids.size():
		var player := _player_by_id(ids[i])
		if player != null:
			player.apply_server_state(positions[i], aims[i], (flags[i] & 1) != 0, acks[i], hearts[i], max_hearts[i], (flags[i] & 2) != 0)
			player.bombs_left = bombs[i]
			player.coins = coins[i]
	_sync_clock(elapsed)
	if stage != _stage:
		_stage = stage
		_setup_stage()
	_team.level = team_level
	_team.xp = team_xp
	if phase == Phase.SHOP:
		_shop.apply_status(pause_waiting, pause_countdown)
	else:
		_level_up.apply_status(pause_waiting, pause_countdown)
	if phase != _phase:
		if _phase == Phase.LEVEL_UP:
			_level_up.close_local()
		if _phase == Phase.SHOP:
			_shop.close_local()
		_phase = phase as Phase
		if _is_between_stages():
			_projectiles.clear()
			_enemy_bullets.clear()
			_gems.clear()
			_coins.clear()
			_weapons.clear_altars()


## Client: keep our copy of the stage clock close to the host's *current* time.
## Snapshots are about half a round trip old when they arrive, so add that.
func _sync_clock(host_elapsed: float) -> void:
	var estimate := host_elapsed + Net.ping_ms() / 2000.0
	if absf(estimate - _elapsed) > 0.25:
		_elapsed = estimate
	else:
		_elapsed = lerpf(_elapsed, estimate, 0.1)


## Client: enemy patterns fired on the host. They're fast-forwarded to where they
## will be when our own inputs reach the host (about one round trip after the
## host fired them), so what we dodge on screen matches what the host checks.
@rpc("authority", "call_remote", "reliable")
func _receive_enemy_patterns(patterns: PackedInt32Array, origins: PackedVector2Array, aims: PackedFloat32Array,
		seeds: PackedInt32Array, fire_times: PackedFloat32Array) -> void:
	var dodge_time := _elapsed + Net.ping_ms() / 2000.0
	for i: int in patterns.size():
		var age := clampf(dodge_time - fire_times[i], 0.0, MAX_PATTERN_FAST_FORWARD)
		_spawn_enemy_pattern(patterns[i], origins[i], aims[i], seeds[i], age)


@rpc("authority", "call_remote", "reliable")
func _receive_seeker(shooter_id: int, origin: Vector2, aim: float, level: int) -> void:
	_spawn_seeker(shooter_id, origin, aim, level)


@rpc("authority", "call_remote", "reliable")
func _receive_bomb(at: Vector2) -> void:
	_detonate_bomb(at)


@rpc("authority", "call_remote", "reliable")
func _receive_shot(shooter_id: int, pattern: int, origin: Vector2, aim: float, seed_value: int) -> void:
	_spawn_shot(shooter_id, pattern as ShotPatterns.Id, origin, aim, seed_value)
