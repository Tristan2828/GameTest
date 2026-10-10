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
## COUNTDOWN: everyone has picked (level-up or shop); the game resumes in a few seconds.
enum Phase { PLAYING, STAGE_CLEAR, RUN_OVER, LEVEL_UP, SHOP, VICTORY, COUNTDOWN }

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const BOUNDS: Rect2 = Rect2(0, 0, 1600, 1000)
## A run is this many stages; beating the last boss is Victory.
const STAGE_COUNT: int = 3
## Your own attack sound, by CharacterStats.MainWeapon.
const MAIN_WEAPON_SOUNDS: Array[StringName] = [&"shoot", &"scythe", &"zap", &"spear"]
## How much tougher each stage of a run is (index = run depth - 1; a single-stage
## custom game always uses the first column). v0.18.0: the old +50% HP / +35%
## spawns per stage made stages 2-3 easy, since a team's damage roughly triples
## by stage 3 (measured with `[balance]` lines: boss fights went 65 s -> 8 s -> 4 s).
const ENEMY_HP_BY_DEPTH: Array[float] = [1.0, 4.0, 9.0]
const BOSS_HP_BY_DEPTH: Array[float] = [1.0, 4.5, 12.0]
const SPAWN_RATE_BY_DEPTH: Array[float] = [1.0, 1.4, 1.8]
## How much harder enemies hit (touch and bullets) at each run depth.
const DAMAGE_BY_DEPTH: Array[float] = [1.0, 1.3, 1.6]
## Later stages start their spawn ramp this many seconds in, so the opening
## minute isn't a stroll for a team that's already strong.
const RAMP_HEAD_START_BY_DEPTH: Array[float] = [0.0, 45.0, 90.0]
## Seconds the "Stage cleared" banner shows before the shop opens.
const STAGE_CLEAR_DELAY: float = 4.0
## Coins every player gets for beating a stage's boss (more in later stages).
const BOSS_BOUNTY: int = 25
const BOSS_BOUNTY_PER_STAGE: int = 15
## Horde waves last this long, then the boss arrives.
const WAVE_DURATION: float = 240.0
## Horde spawn rate while the boss is alive (and no pack surges).
const BOSS_FIGHT_SPAWN_RATE: float = 0.4
const BOSS_SPAWN_DISTANCE: float = 220.0
const BOSS_BANNER_SECONDS: float = 3.0
## "3, 2, 1" before play resumes after a level-up or the shop.
const RESUME_COUNTDOWN_SECONDS: float = 3.0
## 60 physics ticks per second / 2 = 30 player snapshots per second.
const PLAYER_SNAPSHOT_INTERVAL_TICKS: int = 2
## Enemies are smoothed on clients anyway, so 15 per second is plenty.
const ENEMY_SNAPSHOT_INTERVAL_TICKS: int = 4
const SPAWN_OFFSETS: Array[Vector2] = [Vector2(-24, -24), Vector2(24, -24), Vector2(-24, 24), Vector2(24, 24)]
## Enemy bullets: HP per hit when the shooter isn't found (each EnemyType has its
## own bullet_damage), and how long they fly.
const ENEMY_BULLET_DAMAGE: int = 15
const ENEMY_BULLET_LIFETIME: float = 7.0
## Clients fast-forward enemy patterns by at most this much (very laggy = less fair, not broken).
const MAX_PATTERN_FAST_FORWARD: float = 0.4
## Enemies appear just off-screen: the screen is 640x360, so ~367 px to a corner.
const SPAWN_DISTANCE_MIN: float = 380.0
const SPAWN_DISTANCE_MAX: float = 440.0
const MIN_SPAWN_DISTANCE_FROM_ANY_PLAYER: float = 340.0
const PACK_RADIUS: float = 28.0
const CONTROLS_HINT: String = "WASD / L-stick move (your weapons fire by themselves)   Esc / Start menu"
const COPIED_FEEDBACK_SECONDS: float = 4.0
const SPARK_COLOR: Color = Color(1.0, 0.9, 0.6)
const HURT_COLOR: Color = Color(1.0, 0.25, 0.3)
const CRIT_COLOR: Color = Color(1.0, 0.85, 0.25)
## Corpse Blast (upgrade): how far a burst reaches, and its color.
const KILL_BURST_RADIUS: float = 32.0
const KILL_BURST_COLOR: Color = Color(0.5, 0.95, 0.55)
## Map events: coins from a champion and a caught thief, the chest's coins when
## every weapon is maxed, and what a finished ritual gives.
const CHAMPION_COINS: int = 10
const RUNNER_COINS: int = 14
const CHEST_COINS_WHEN_MAXED: int = 30
## A finished ritual heals everyone inside this share of their max HP.
const RITUAL_HEAL_SHARE: float = 0.25
## Every team level-up heals each living player this share of their max HP.
const LEVEL_UP_HEAL_SHARE: float = 0.05
## A finished ritual's XP: this share of the current level's cost.
const RITUAL_XP_SHARE: float = 0.6
## Enemies called per ritual wave (+1 per extra player), and from how far.
const RITUAL_WAVE_SIZE: int = 2
const RITUAL_WAVE_DISTANCE: float = 200.0
## A relic quest pays this instead when the player already owns every relic.
const QUEST_COINS_WHEN_NO_RELIC: int = 40
## In --autopilot test mode, the host restarts by itself this long after a stage ends.
const AUTOPILOT_RESTART_DELAY: float = 2.0

var _phase: Phase = Phase.PLAYING
## Current stage number = map (1 Crypt, 2 Marsh, 3 Cathedral; host-owned, synced
## in snapshots). See _run_depth() for how far into the run it is.
var _stage: int = 1
var _stage_clear_left: float = 0.0
var _elapsed: float = 0.0
var _wave_duration: float = WAVE_DURATION
## Difficulty and custom game options for this run (RunSetup.config).
var _config: RunConfig = RunConfig.new()
## Host: starting level-ups not yet handed out (waits until everyone has loaded).
var _bonus_levels_left: int = 0
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
## Seconds until play resumes (Phase.COUNTDOWN; clients get it from snapshots).
var _resume_left: float = 0.0
## Host: peers whose arena has loaded, so they can receive snapshots and shots.
var _ready_peers: Dictionary[int, bool] = {}
var _tick: int = 0
var _director: SpawnDirector = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Host: kills, coins, XP... per player for the end-of-run screen.
var _run_stats: RunStats = RunStats.new()
## Host: Bone Effigies standing in the arena.
var _effigies: Array[Effigy] = []
## Host: Corpse Blast bursts waiting to go off this tick (position, damage, owner).
var _burst_positions: PackedVector2Array = PackedVector2Array()
var _burst_damages: PackedInt32Array = PackedInt32Array()
var _burst_owners: PackedInt32Array = PackedInt32Array()
## Host: seconds until another random power-up may drop.
var _power_up_cooldown: float = 0.0
## Host: everyone's quest for this stage (picked in the shop) and its progress.
var _quests: QuestTracker = QuestTracker.new()
## Host: Arsenal counts auto weapon damage from the stage start (peer -> damage then).
var _quest_damage_base: Dictionary[int, int] = {}
## Host: Untouchable restarts when hp_lost changes (peer -> hp_lost last tick).
var _quest_hp_seen: Dictionary[int, int] = {}
## Host: when (in run seconds) each player first got each auto weapon: peer -> {weapon id: seconds}.
var _weapon_owned_since: Dictionary[int, Dictionary] = {}
## Local: seconds our player has been downed (the camera moves to a teammate after a moment).
var _downed_seconds: float = 0.0
## Local: which teammate we're watching while downed (switch_view cycles).
var _spectate_index: int = 0


## Host: one Bone Effigy (a decoy that bursts when its time runs out).
class Effigy:
	var position: Vector2
	var time_left: float
	var lure_radius: float
	var burst_radius: float
	var burst_damage: int
	var owner_peer_id: int
	var source: int = DamageSource.ABILITY
## Shared team XP and level (host-owned, copied to clients in snapshots).
var _team: TeamProgress = TeamProgress.new()
var _copied_feedback_left: float = 0.0
var _announced_invite: bool = false
var _time_since_stage_end: float = 0.0
var _restart_requested: bool = false
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
@onready var _power_ups: GemManager = $PowerUps
@onready var _events: MapEvents = $Events
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
	_projectiles.spawn_backtrack = Player.MUZZLE_DISTANCE
	_enemy_bullets.bounds = BOUNDS
	_enemies.bounds = BOUNDS
	_events.bounds = BOUNDS
	_rng.randomize()
	# The lobby's Difficulty / Custom Game choices (clients got a copy from the host).
	_config = RunSetup.config
	_stage = _config.first_stage()
	if multiplayer.is_server() and LaunchOptions.start_stage > 1:
		_stage = LaunchOptions.start_stage
	_wave_duration = _config.wave_seconds
	_team.xp_rate = _config.xp_rate
	_bonus_levels_left = _config.bonus_levels
	_setup_stage()
	if multiplayer.is_server():
		_events.host_start_stage()
	_level_up.bind_panel(_hud.level_up_panel, _local_player)
	_shop.bind(_hud.shop_panel, _player_by_id, _ready_peer_list)
	_shop.relic_bought.connect(_on_relic_bought)
	_weapons.bounds = BOUNDS
	_enemies.enemy_vanished.connect(_on_enemy_vanished)
	_enemies.enemy_crit.connect(_on_enemy_crit)
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
	_power_ups.picked_up_at.connect(func(at: Vector2) -> void:
		if _near_local_player(at, 80.0):
			Sfx.play(&"pickup", -4.0))
	_weapons.weapon_gained.connect(_on_weapon_gained)
	_weapons.shards_requested.connect(_on_shards_requested)
	_weapons.find_player = _player_by_id
	_events.announced.connect(_on_event_announced)
	_level_up.upgrade_announced.connect(_on_upgrade_announced)
	_hud.run_summary.return_requested.connect(_request_restart)
	if LaunchOptions.stage_seconds > 0.0:
		_wave_duration = LaunchOptions.stage_seconds
	if multiplayer.is_server():
		_elapsed = LaunchOptions.start_at_seconds
		Net.invite.changed.connect(_on_invite_changed)
		_on_invite_changed()
		_enemies.enemy_killed.connect(_on_enemy_killed)
		_enemies.stats_of_peer = _stats_of_peer
		_enemies.pattern_fired.connect(_fire_enemy_pattern)
		_gems.collected.connect(_on_gem_collected)
		_coins.collected.connect(_on_coin_collected)
		_power_ups.collected.connect(_on_power_up_collected)
		_events.spawn_enemy = _spawn_event_enemy
		_events.champion_slain.connect(_on_champion_slain)
		_events.chest_opened.connect(_on_chest_opened)
		_events.ritual_completed.connect(_on_ritual_completed)
		_events.runner_caught.connect(_on_runner_caught)
		_events.wave_requested.connect(_on_ritual_wave)
		_events.coin_dropped.connect(func(at: Vector2) -> void: _coins.spawn_host(at, 1))
		_weapons.seeker_fired.connect(_fire_seeker)
		_weapons.ability_cast.connect(_on_ability_cast)
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


func _exit_tree() -> void:
	GameCursor.set_in_game(false)
	LocalInput.blocked = false


func _physics_process(delta: float) -> void:
	var is_host := multiplayer.is_server()
	_team.player_count = maxi(_player_nodes().size(), 1)
	if _phase == Phase.PLAYING:
		_elapsed += delta
		_run_stats.run_seconds += delta
		var t := PerfLog.start()
		for player: Player in _player_nodes():
			player.tick(delta)
		PerfLog.stop(&"players", t)
		if is_host:
			t = PerfLog.start()
			_spawn_enemies(delta)
			_tick_effigies(delta)
			_power_up_cooldown = maxf(_power_up_cooldown - delta, 0.0)
			PerfLog.stop(&"spawn", t)
			t = PerfLog.start()
			_enemies.tick_host(delta, _alive_player_positions(), _effigy_positions(), _effigy_lure_radius())
			PerfLog.stop(&"enemies", t)
			t = PerfLog.start()
			_tick_boss(delta)
			PerfLog.stop(&"boss", t)
			t = PerfLog.start()
			_weapons.tick_host(delta, _elapsed, _player_nodes(), _enemies, _ready_peer_list())
			_events.host_tick(delta, _elapsed, _player_nodes(), _enemies, _boss_spawned, _ready_peer_list())
			PerfLog.stop(&"weapons", t)
			t = PerfLog.start()
			_apply_contact_damage()
			_test_knock_out()
			_tick_revives(delta)
			_tick_quests(delta)
			PerfLog.stop(&"contact", t)
		else:
			t = PerfLog.start()
			_enemies.rebuild_grid()
			PerfLog.stop(&"grid", t)
		t = PerfLog.start()
		_weapons.tick_effects(delta, _player_nodes(), _enemies, is_host)
		PerfLog.stop(&"weapon_fx", t)
		t = PerfLog.start()
		_projectiles.steer(_enemies, delta)
		_projectiles.step(delta)
		_projectiles.resolve_hits(_enemies, is_host)
		if is_host:
			_resolve_kill_bursts()
		PerfLog.stop(&"shots", t)
		t = PerfLog.start()
		_enemy_bullets.step(delta)
		_enemy_bullets.resolve_player_hits(_player_nodes(), is_host)
		PerfLog.stop(&"enemy_bullets", t)
		t = PerfLog.start()
		_tick_gems(delta, is_host)
		PerfLog.stop(&"gems", t)
		if is_host:
			_update_phase()
		if is_host and _bonus_levels_left > 0 and _all_peers_loaded():
			# Custom game "starting level-ups": handed out once every client can see them.
			_level_up.host_queue(_bonus_levels_left)
			_team.level += _bonus_levels_left
			_bonus_levels_left = 0
		if is_host and _phase == Phase.PLAYING and _level_up.host_should_start():
			_start_level_up()
	elif _phase == Phase.LEVEL_UP:
		if is_host and _level_up.host_tick(delta, _ready_peer_list()):
			if _level_up.host_should_start():
				_start_level_up()
			else:
				_start_resume_countdown()
	elif _phase == Phase.COUNTDOWN:
		if is_host:
			_resume_left = maxf(_resume_left - delta, 0.0)
			if _resume_left <= 0.0:
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
		# (Screenshot runs wait longer: the summary's three pages get a picture each.)
		var delay := AUTOPILOT_RESTART_DELAY + (2.5 if not LaunchOptions.screenshot_dir.is_empty() else 0.0)
		if _time_since_stage_end >= delay:
			_time_since_stage_end = -INF
			_request_restart()
	if is_host:
		_tick += 1
		var t := PerfLog.start()
		_send_snapshots()
		PerfLog.stop(&"snapshots", t)


var _jingle_phase: Phase = Phase.PLAYING
## The countdown number last beeped (0 = none yet).
var _beeped_number: int = 0
## Everyone: the final numbers once the run ends (null before that).
var _final_stats: RunStats = null


## Calm music between stages, the boss theme during boss fights, otherwise the stage's own.
func _update_music() -> void:
	if _is_between_stages():
		Music.play(&"menu")
	elif _enemies.find_boss() != null:
		Music.play(Tracks.for_soundtrack(&"boss", _config.soundtrack, _stage))
	else:
		Music.play(Tracks.for_soundtrack(Stages.get_stage(_stage).music, _config.soundtrack, _stage))


func _play_phase_jingle() -> void:
	_play_countdown_beeps()
	if _phase == _jingle_phase:
		return
	_jingle_phase = _phase
	match _phase:
		Phase.VICTORY, Phase.STAGE_CLEAR:
			Sfx.play(&"victory", -2.0)
		Phase.RUN_OVER:
			Sfx.play(&"defeat", -2.0)
	if _is_run_finished() and not LaunchOptions.screenshot_dir.is_empty():
		await get_tree().create_timer(1.7).timeout  # After the summary's count-up.
		await Main.save_screenshot(get_tree(), "run_end.png")
		_hud.run_summary._show_page(1)
		await get_tree().create_timer(0.3).timeout
		await Main.save_screenshot(get_tree(), "run_end_weapons.png")
		_hud.run_summary._show_page(2)
		await get_tree().create_timer(0.3).timeout
		await Main.save_screenshot(get_tree(), "run_end_highlights.png")
		_hud.run_summary._show_page(0)


## A beep on each "3, 2, 1" and a higher one when play resumes.
func _play_countdown_beeps() -> void:
	if _phase == Phase.COUNTDOWN:
		var number := maxi(ceili(_resume_left), 1)
		if number != _beeped_number:
			_beeped_number = number
			Sfx.play(&"countdown", -4.0)
			if number == 2 and not LaunchOptions.screenshot_dir.is_empty():
				Main.save_screenshot(get_tree(), "countdown.png")
	elif _beeped_number != 0:
		_beeped_number = 0
		if _phase == Phase.PLAYING:
			Sfx.play(&"countdown_go", -4.0)


func _process(delta: float) -> void:
	for player: Player in _player_nodes():
		player.weapon_clock = _elapsed
	_copied_feedback_left = maxf(_copied_feedback_left - delta, 0.0)
	_boss_banner_left = maxf(_boss_banner_left - delta, 0.0)
	_play_phase_jingle()
	_update_music()
	_update_spectate(delta)
	# Hidden while playing; back for level-up cards, the shop and the pause menu.
	GameCursor.set_in_game((_phase == Phase.PLAYING or _phase == Phase.COUNTDOWN) and not LocalInput.blocked)
	_revive_screenshots()
	_event_screenshots()
	var t := PerfLog.start()
	_update_hud()
	PerfLog.stop(&"hud", t)
	_perf_report(delta)


var _perf_seconds: float = 0.0


## --perf-log: one line per second with step timings and object counts.
func _perf_report(delta: float) -> void:
	if not PerfLog.enabled:
		return
	PerfLog.frame()
	_perf_seconds += delta
	if _perf_seconds < 1.0:
		return
	var boss := _enemies.find_boss()
	print(PerfLog.report(_perf_seconds, "t=%.0fs %s enemies %d shots %d enemy_bullets %d effects %d gems %d boss %s draws %d phys %.1fms proc %.1fms" % [
		_elapsed, Phase.keys()[_phase], _enemies.active_count(), _projectiles.count(), _enemy_bullets.count(),
		_effects.count(), _gems.count(), "yes" if boss != null else "no",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]))
	_perf_seconds = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("copy_invite") and Net.invite.copy_to_clipboard():
		_copied_feedback_left = COPIED_FEEDBACK_SECONDS
	if event.is_action_pressed("restart"):
		_request_restart()
	if event.is_action_pressed("switch_view") and _is_spectating():
		_spectate_index += 1


## Host, once the run is over: everyone goes back to character select (once).
func _request_restart() -> void:
	if multiplayer.is_server() and _is_run_finished() and not _restart_requested:
		_restart_requested = true
		restart_requested.emit()


## Game info sent with feedback: where the run is, this player's state, the session.
func feedback_context() -> String:
	var lines := PackedStringArray()
	var clock := "boss fight" if _boss_seen else "%s into the wave" % RunStats.format_time(_elapsed)
	lines.append("Stage %d/%d: %s, %s (%s), team level %d" % [_run_depth(), _stage_count(), Stages.get_stage(_stage).title,
		clock, Phase.keys()[_phase].to_lower().replace("_", " "), _team.level])
	var local := _local_player()
	if local != null:
		lines.append("%s (%s) at %s, HP %d/%d%s, %d upgrades, %d relics, %d weapons" % [local.stats.display_name,
			local.display_name(), local.world_position().round(), local.health.hp, local.health.max_hp,
			" (downed)" if local.is_downed() else "", local.upgrade_ids.size(), local.relic_ids.size(), local.weapon_levels.size()])
	var session := "Solo"
	if Net.is_online():
		session = "Co-op, %d players, %s" % [_player_nodes().size(), "host" if multiplayer.is_server() else "client, ping %d ms" % Net.ping_ms()]
	lines.append("%s. %s" % [session, _config.summary()])
	return "\n".join(lines)


## A text summary for headless smoke tests (see LaunchOptions --run-for).
func debug_report() -> String:
	var lines := PackedStringArray()
	var role := "host" if multiplayer.is_server() else "client"
	lines.append("[report] peer %d (%s)  stage %d  phase=%s  time=%.1fs" % [multiplayer.get_unique_id(), role, _stage, Phase.keys()[_phase], _elapsed])
	lines.append("[report]   config: %s   wave %.0fs" % [_config.summary(), _wave_duration])
	for player: Player in _player_nodes():
		var line := "[report]   player %d (%s) slot %d at %s  hp %d/%d  coins %d  upgrades %s  relics %s" % [
			player.peer_id, player.stats.display_name, player.slot, player.position.round(), player.health.hp, player.health.max_hp,
			player.coins, player.upgrade_ids, player.relic_ids]
		line += "  weapons %s" % [player.weapon_levels]
		if player.is_local() and not multiplayer.is_server():
			line += "  corrections=%d largest=%.2fpx" % [player.correction_count, player.largest_correction]
		lines.append(line)
	lines.append("[report]   active enemies: %d   gems on ground: %d   team level %d (%d xp)" % [
		_enemies.active_count(), _gems.count(), _team.level, _team.xp])
	if multiplayer.is_server():
		lines.append("[report]   damage by peer: %s" % [_enemies.damage_by_peer])
		lines.append("[report]   kills by peer: %s" % [_run_stats_kills()])
		lines.append("[report]   invite: '%s'  %s" % [Net.invite.address, Net.invite.status])
	lines.append("[report]   enemy bullets alive: %d   altars: %d   music: %s" % [_enemy_bullets.count(), _weapons.altar_count(), Music.now_playing()])
	var event_kinds := PackedStringArray()
	for event: MapEvents.MapEvent in _events.events():
		event_kinds.append("%s/%s" % [MapEvents.Kind.keys()[event.kind], MapEvents.State.keys()[event.state]])
	lines.append("[report]   events: %s   power-ups on ground: %d   weapon effects: %s" % [
		event_kinds, _power_ups.count(), _weapons.effect_counts()])
	if multiplayer.is_server():
		lines.append("[report]   quests: %s   progress: %s" % [_quests.quest_of, _quests.progress])
	var boss := _enemies.find_boss()
	if boss != null:
		lines.append("[report]   boss: %s hp %.0f%% phase %d" % [boss.type.display_name, boss.hp_ratio * 100.0, _boss_brain.phase])
	lines.append("[report]   bullets alive: %d   physics time: %.2f ms/tick" % [_projectiles.count(), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	return "\n".join(lines)


func _run_stats_kills() -> Dictionary[int, int]:
	var kills: Dictionary[int, int] = {}
	for peer_id: int in _run_stats.by_peer:
		kills[peer_id] = _run_stats.get_stat(peer_id, RunStats.Stat.KILLS)
	return kills


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
	var boosts := Net.boosts_of(peer_id) if _config.ember_boosts else PackedInt32Array()
	_player_spawner.spawn({"peer_id": peer_id, "slot": _free_slot(), "character": RunSetup.character_for(peer_id),
		"hp_bonus": _config.hp_bonus, "boosts": boosts})
	if _config.start_with_weapons:
		for weapon_id: int in AutoWeapons.PICKUPS:
			_weapons.grant(peer_id, weapon_id, _ready_peer_list())
	if LaunchOptions.give_weapons:
		# Test aid: same path as real pickups (new joiners also get it via history).
		for weapon_id: int in AutoWeapons.PICKUPS:
			for level: int in 2:
				_weapons.grant(peer_id, weapon_id, _ready_peer_list())
	for upgrade_id: int in LaunchOptions.give_upgrades:
		_level_up.host_grant(peer_id, upgrade_id, _ready_peer_list())


func _lobby_rank(peer_id: int) -> int:
	var index := RunSetup.order.find(peer_id)
	return index if index >= 0 else 1000 + peer_id


func _remove_player(peer_id: int) -> void:
	_ready_peers.erase(peer_id)
	_level_up.host_remove_player(peer_id)
	_shop.host_remove_player(peer_id)
	_quests.remove(peer_id)
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
	var boosts: Variant = info.get("boosts", PackedInt32Array())
	player.setup(peer_id, slot, BOUNDS.get_center() + SPAWN_OFFSETS[slot], BOUNDS, character, int(info.get("hp_bonus", 0)),
		boosts if boosts is PackedInt32Array else PackedInt32Array())
	player.shot_requested.connect(_on_player_shot_requested)
	player.hurt.connect(_on_player_hurt)
	player.revived.connect(_on_player_revived)
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
	_balance_peak_alive = maxi(_balance_peak_alive, _enemies.active_count())
	var rate := BOSS_FIGHT_SPAWN_RATE if _boss_spawned else 1.0
	rate *= by_depth(SPAWN_RATE_BY_DEPTH, _run_depth()) * _config.enemy_count
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


## Enemy max HP for the current stage (and the difficulty sliders).
func _scaled_hp(type_id: int) -> int:
	var type := EnemyTypes.get_type(type_id)
	var difficulty := _config.boss_health if type.is_boss else _config.enemy_health
	return maxi(roundi(type.max_hp * hp_factor(type.is_boss, _run_depth()) * difficulty), 1)


## A stage-scaling table's value at this run depth (1 = first stage).
static func by_depth(table: Array[float], depth: int) -> float:
	return table[clampi(depth - 1, 0, table.size() - 1)]


## How much more HP enemies (or bosses) have at this run depth.
static func hp_factor(is_boss: bool, depth: int) -> float:
	return by_depth(BOSS_HP_BY_DEPTH if is_boss else ENEMY_HP_BY_DEPTH, depth)


## How far into the run this stage is (1 = first). Later stages are tougher.
## A single-stage custom game is always the first stage, whichever map it uses.
func _run_depth() -> int:
	return _stage - _config.first_stage() + 1


## Stages in this run (1 for a single-stage custom game).
func _stage_count() -> int:
	return _config.stage_count()


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


## Enemies touching a player's hitbox drain HP together, every
## PlayerHealth.CONTACT_INTERVAL: the more of them, the faster you lose HP.
func _apply_contact_damage() -> void:
	for player: Player in _player_nodes():
		if player.is_downed() or player.health.contact_left > 0.0 or player.health.is_invulnerable():
			continue
		var total := 0
		for enemy: Enemy in _enemies.enemies_in_radius(player.state.position, player.stats.hitbox_radius):
			total += enemy.type.contact_damage
		if total > 0:
			player.take_contact(_scaled_damage(total))


## Damage an enemy deals at this run depth.
func _scaled_damage(amount: int) -> int:
	return maxi(roundi(amount * by_depth(DAMAGE_BY_DEPTH, _run_depth())), 1)


## Host, --test-down: knock out the first client's player once (revive testing).
func _test_knock_out() -> void:
	if LaunchOptions.test_down_at < 0.0 or _elapsed < LaunchOptions.test_down_at:
		return
	for player: Player in _player_nodes():
		if not player.is_local() and not player.is_downed():
			LaunchOptions.test_down_at = -1.0
			player.health.hp = 0
			player.times_downed += 1
			print("Player %d knocked out (--test-down)" % player.peer_id)
			return


## Host: teammates standing in a downed player's circle fill it; full = back up.
func _tick_revives(delta: float) -> void:
	var players := _player_nodes()
	for downed: Player in players:
		if not downed.is_downed():
			continue
		var helper_speed := 0.0
		var helpers: Array[int] = []
		for helper: Player in players:
			if not helper.is_downed() and Revive.in_range(downed.state.position, helper.state.position):
				helper_speed += helper.stats.revive_speed
				helpers.append(helper.peer_id)
		downed.revive_progress = Revive.step(downed.revive_progress, helper_speed, delta)
		if downed.revive_progress >= 1.0:
			downed.revive()
			for peer_id: int in helpers:
				_run_stats.add(peer_id, RunStats.Stat.REVIVES, 1)
				_quest_count(peer_id, Quests.Id.GUARDIAN)


## Everyone: alive players other than `local`, in a stable order.
func _alive_teammates(local: Player) -> Array[Player]:
	var result: Array[Player] = []
	for player: Player in _player_nodes():
		if player != local and not player.is_downed():
			result.append(player)
	return result


## Local: while we're downed, the camera follows a living teammate (after a
## short moment on our own body). The last choice in the cycle is ourselves.
func _update_spectate(delta: float) -> void:
	var local := _local_player()
	if local == null:
		return
	if not local.is_downed() or _is_between_stages():
		_downed_seconds = 0.0
		_spectate_index = 0
		local.spectate_target = null
		return
	_downed_seconds += delta
	var choices := _alive_teammates(local)
	if choices.is_empty() or _downed_seconds < Revive.SPECTATE_DELAY:
		local.spectate_target = null
		return
	choices.append(local)
	local.spectate_target = choices[posmod(_spectate_index, choices.size())]


var _downed_screenshot_taken: bool = false
var _reviving_screenshot_taken: bool = false


## --screenshot-dir: one picture while watching a teammate, one while reviving.
func _revive_screenshots() -> void:
	var local := _local_player()
	if LaunchOptions.screenshot_dir.is_empty() or local == null:
		return
	if not _downed_screenshot_taken and _is_spectating() and _downed_seconds > Revive.SPECTATE_DELAY + 1.0:
		_downed_screenshot_taken = true
		Main.save_screenshot(get_tree(), "downed_spectating.png")
	if not _reviving_screenshot_taken and not local.is_downed():
		for player: Player in _player_nodes():
			if player.is_downed() and player.revive_progress > 0.4:
				_reviving_screenshot_taken = true
				Main.save_screenshot(get_tree(), "reviving.png")


var _event_screenshots_taken: Dictionary[String, bool] = {}


## --screenshot-dir: one picture of each kind of map event once it's near us.
func _event_screenshots() -> void:
	var local := _local_player()
	if LaunchOptions.screenshot_dir.is_empty() or local == null or _phase != Phase.PLAYING:
		return
	for event: MapEvents.MapEvent in _events.events():
		var name := "event_%s_%s.png" % [MapEvents.Kind.keys()[event.kind].to_lower(), MapEvents.State.keys()[event.state].to_lower()]
		if not _event_screenshots_taken.has(name) and event.position.distance_to(local.world_position()) < 200.0:
			_event_screenshots_taken[name] = true
			Main.save_screenshot(get_tree(), name)
	if not _event_screenshots_taken.has("power_up") and _power_ups.count() > 0:
		_event_screenshots_taken["power_up"] = true
		Main.save_screenshot(get_tree(), "power_up.png")
	# The hero's main weapon in a crowd (a few moments into each stage).
	for seconds: int in [30, 90]:
		var name := "stage%d_%ds.png" % [_stage, seconds]
		if not _event_screenshots_taken.has(name) and _elapsed >= seconds:
			_event_screenshots_taken[name] = true
			Main.save_screenshot(get_tree(), name)


func _is_spectating() -> bool:
	var local := _local_player()
	return local != null and local.is_downed() and _downed_seconds >= Revive.SPECTATE_DELAY \
		and not _alive_teammates(local).is_empty()


func _update_phase() -> void:
	var players := _player_nodes()
	if not players.is_empty() and _alive_player_positions().is_empty():
		_end_stage(Phase.RUN_OVER)
	elif _boss_defeated:
		_end_stage(Phase.STAGE_CLEAR)
	elif _elapsed >= _wave_duration and not _boss_spawned:
		if _config.boss_enabled:
			_spawn_boss()
		else:
			_end_stage(Phase.STAGE_CLEAR)  # Custom game without a boss: survived the timer.


## Host: numbers at the start of the stage and the busiest moment, for the
## balance line printed when it ends (`_print_balance`).
var _balance_start: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _balance_boss_at: float = -1.0
var _balance_peak_alive: int = 0


## One line per stage for tuning difficulty: how long the waves and the boss
## took, how hurt the team got, and how hard it hit. Compare stages with it.
func _print_balance(phase: Phase) -> void:
	var damage := 0
	for peer_id: int in _enemies.damage_by_peer:
		damage += _enemies.damage_by_peer[peer_id]
	var hp_lost := 0
	var downs := 0
	for player: Player in _player_nodes():
		hp_lost += player.hp_lost
		downs += player.times_downed
	var now := PackedInt32Array([_run_stats.total(RunStats.Stat.KILLS), damage, hp_lost, downs])
	var boss_seconds := _elapsed - _balance_boss_at if _balance_boss_at >= 0.0 else 0.0
	var max_hp := 0
	for player: Player in _player_nodes():
		max_hp += player.health.max_hp
	print("[balance] stage %d %s: time %.0fs (boss fight %.0fs)  team level %d  kills %d  dps %.0f  hp lost %d (team max hp %d)  downs %d  peak enemies %d  players %d" % [
		_run_depth(), Phase.keys()[phase], _elapsed, boss_seconds, _team.level, now[0] - _balance_start[0],
		(now[1] - _balance_start[1]) / maxf(_elapsed, 1.0), now[2] - _balance_start[2], max_hp, now[3] - _balance_start[3],
		_balance_peak_alive, _player_nodes().size()])
	_balance_start = now
	_balance_boss_at = -1.0
	_balance_peak_alive = 0


func _end_stage(phase: Phase) -> void:
	_print_balance(phase)
	if phase == Phase.STAGE_CLEAR and _run_depth() >= _stage_count():
		phase = Phase.VICTORY
	_phase = phase
	_stage_clear_left = STAGE_CLEAR_DELAY
	if phase == Phase.STAGE_CLEAR:
		_settle_stage_rewards()
	else:
		_level_up.host_reset()
		_broadcast_run_stats(phase == Phase.VICTORY)
	_enemies.clear_all()
	_projectiles.clear()
	_enemy_bullets.clear()
	_gems.clear()
	_coins.clear()
	_power_ups.clear()
	_events.clear()
	_quests.clear()
	for player: Player in _player_nodes():
		player.quest_id = -1
	_weapons.clear_altars()
	_effigies.clear()
	_clear_ability_markers()
	print("Stage ended: %s at %.1fs" % [Phase.keys()[phase], _elapsed])


## Host: nothing is left behind when a stage is won. Gems still on the ground
## go to the team bar (level-ups wait for the next stage), loose coins are split
## evenly, and everyone gets the boss bounty.
func _broadcast_run_stats(victory: bool) -> void:
	_run_stats.victory = victory
	_run_stats.stage_reached = _stage
	_run_stats.team_level = _team.level
	_run_stats.bosses_defeated = 0 if not _config.boss_enabled else (_run_depth() if victory else _run_depth() - 1)
	var boss := _enemies.find_boss()
	_run_stats.fell_to = "" if victory or boss == null else boss.type.display_name
	for player: Player in _player_nodes():
		var peer_id := player.peer_id
		_run_stats.add(peer_id, RunStats.Stat.KILLS, 0)  # Everyone gets a column.
		_run_stats.set_stat(peer_id, RunStats.Stat.DAMAGE, _enemies.damage_by_peer.get(peer_id, 0))
		_run_stats.set_stat(peer_id, RunStats.Stat.BOSS_DAMAGE, _enemies.boss_damage_by_peer.get(peer_id, 0))
		_run_stats.set_stat(peer_id, RunStats.Stat.HP_LOST, player.hp_lost)
		_run_stats.set_stat(peer_id, RunStats.Stat.DOWNS, player.times_downed)
		_record_weapon_breakdown(player)
	var data := _run_stats.encode()
	_receive_run_stats(data)
	for peer_id: int in _ready_peers:
		_receive_run_stats.rpc_id(peer_id, data)


## Host: damage, kills and time owned for this player's main weapon and every
## auto weapon they picked up.
func _record_weapon_breakdown(player: Player) -> void:
	var peer_id := player.peer_id
	var run_seconds := roundi(_run_stats.run_seconds)
	var damage: Dictionary = _enemies.damage_by_source.get(peer_id, {})
	var kills: Dictionary = _enemies.kills_by_source.get(peer_id, {})
	var seconds_by_source: Dictionary[int, int] = {DamageSource.MAIN_GUN: run_seconds}
	var owned: Dictionary = _weapon_owned_since.get(peer_id, {})
	for weapon_id: int in player.weapon_levels:
		var since: float = owned.get(weapon_id, 0.0)
		seconds_by_source[DamageSource.of_weapon(weapon_id)] = maxi(roundi(_run_stats.run_seconds - since), 1)
	for source: int in damage:
		if not seconds_by_source.has(source):
			seconds_by_source[source] = run_seconds
	for source: int in seconds_by_source:
		_run_stats.set_source(peer_id, source, int(damage.get(source, 0)), int(kills.get(source, 0)), seconds_by_source[source])


## Everyone: the end-of-run numbers arrived; show the summary screen.
@rpc("authority", "call_remote", "reliable")
func _receive_run_stats(data: Dictionary) -> void:
	_final_stats = RunStats.decode(data)
	var stage_in_run := _final_stats.stage_reached - _config.first_stage() + 1
	_hud.run_summary.score_multiplier = _config.score_multiplier()
	_hud.run_summary.difficulty_name = _config.difficulty_name()
	_hud.run_summary.first_stage = _config.first_stage()
	_hud.run_summary.bosses_enabled = _config.boss_enabled
	_hud.run_summary.local_record_rank = _save_record(stage_in_run)
	_hud.run_summary.local_embers = _earn_embers()
	var is_host := multiplayer.is_server()
	var restart_hint := "or press R / Select" if is_host else "Waiting for the host to return to character select..."
	_hud.run_summary.open(_final_stats, _player_nodes(), Stages.get_stage(_final_stats.stage_reached).title, _stage_count(),
		restart_hint, is_host, stage_in_run)


## Saves this PC's player's run to Records. Returns its rank for that hero
## (0 = new best, -1 = not kept). Test runs (headless, autopilot) aren't saved.
func _save_record(stage_in_run: int) -> int:
	var local := _local_player()
	if local == null or DisplayServer.get_name() == "headless" or LaunchOptions.autopilot:
		return -1
	var map_title := Stages.get_stage(_final_stats.stage_reached).title
	var entry := RunRecords.entry_for(_final_stats, local.peer_id, local.character_id, _config, stage_in_run,
		map_title, _player_nodes().size())
	return RunRecords.add(entry)


## Adds this PC's player's Embers for the run (Ember Shrine). Returns how many
## (-1 = not counted: test runs, like Records).
func _earn_embers() -> int:
	var local := _local_player()
	if local == null or DisplayServer.get_name() == "headless" or LaunchOptions.autopilot:
		return -1
	var amount := Embers.earned_for(_final_stats.bosses_defeated, _final_stats.victory,
		_final_stats.get_stat(local.peer_id, RunStats.Stat.KILLS), _config.score_multiplier())
	Embers.add_earned(amount)
	return amount


func _settle_stage_rewards() -> void:
	var levels := _team.add_xp(_gems.total_value())
	if levels > 0:
		_level_up.host_queue(levels)
	var players := _player_nodes()
	if players.is_empty():
		return
	var share := _coins.total_value() / players.size()
	var bounty := BOSS_BOUNTY + BOSS_BOUNTY_PER_STAGE * (_run_depth() - 1)
	for player: Player in players:
		player.coins += share + bounty
		_run_stats.add(player.peer_id, RunStats.Stat.COINS_EARNED, share + bounty)


## Host: the next stage starts. The run (level, upgrades, relics, coins) carries
## over; everyone respawns with full HP, downed players included.
func _begin_next_stage() -> void:
	_stage += 1
	_elapsed = 0.0
	_boss_spawned = false
	_boss_defeated = false
	_setup_stage()
	_events.host_start_stage()
	_weapons.reset_stage()
	for player: Player in _player_nodes():
		player.respawn(BOUNDS.get_center() + SPAWN_OFFSETS[player.slot])
	_start_quests(_shop.host_take_quests())
	# Level-ups banked at the end of the last stage come first, then "3, 2, 1".
	if _level_up.host_should_start():
		_start_level_up()
	else:
		_start_resume_countdown()
	print("Stage %d begins" % _stage)


## Everyone: load the current stage's enemies, boss script and floor.
func _setup_stage() -> void:
	var stage := Stages.get_stage(_stage)
	_director = SpawnDirector.new(randi(), stage.spawns)
	_director.ramp_head_start = by_depth(RAMP_HEAD_START_BY_DEPTH, _run_depth())
	_boss_brain = BossBrain.new(stage.boss_phase_one, stage.boss_phase_two)
	_boss_spin = 0.0
	_events.champion_type = stage.champion_type
	_floor.apply_stage(stage)


func _spawn_boss() -> void:
	_boss_spawned = true
	_balance_boss_at = _elapsed
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


func _on_enemy_killed(enemy: Enemy, killer_peer_id: int, source: int) -> void:
	_run_stats.add(killer_peer_id, RunStats.Stat.KILLS, 1)
	_quest_count(killer_peer_id, Quests.Id.SLAYER)
	var killer_stats := _stats_of_peer(killer_peer_id)
	# Corpse Blast: bursts don't set off more bursts (no chain reactions).
	if killer_stats != null and killer_stats.kill_burst_damage > 0 and source != DamageSource.KILL_BURST:
		_burst_positions.append(enemy.position)
		_burst_damages.append(killer_stats.kill_burst_damage)
		_burst_owners.append(killer_peer_id)
	_events.host_enemy_killed(enemy)
	if enemy.type.is_boss:
		# Don't end the stage mid-hit-check; the phase check does it this tick.
		_boss_defeated = true
		print("Boss killed by peer %d at %.1fs" % [killer_peer_id, _elapsed])
		return
	if not _gems.spawn_host(enemy.position, enemy.type.xp_value):
		# Too many gems on the ground: grant the XP directly instead.
		_on_gem_collected(enemy.type.xp_value, killer_peer_id)
	if _rng.randf() < enemy.type.coin_chance * _config.coin_rate:
		var offset := Vector2.from_angle(_rng.randf() * TAU) * 5.0
		if not _coins.spawn_host(enemy.position + offset, enemy.type.coin_value):
			_on_coin_collected(enemy.type.coin_value, killer_peer_id)
	if _power_up_cooldown <= 0.0 and _rng.randf() < PowerUps.DROP_CHANCE:
		_power_up_cooldown = PowerUps.DROP_COOLDOWN
		_drop_power_up(enemy.position, PowerUps.pick_kind(_rng.randf()))
	var killer := _player_by_id(killer_peer_id)
	if killer != null:
		killer.register_kill()


# --- Quests (picked in the shop for this stage) ----------------------------------

## Host: a new stage's quests, picked in the shop.
func _start_quests(chosen: Dictionary[int, int]) -> void:
	_quests.clear()
	_quest_damage_base.clear()
	_quest_hp_seen.clear()
	for player: Player in _player_nodes():
		var quest_id: int = chosen.get(player.peer_id, -1)
		player.quest_id = quest_id
		player.quest_progress = 0
		if quest_id < 0:
			continue
		_quests.assign(player.peer_id, quest_id)
		_quest_damage_base[player.peer_id] = _auto_weapon_damage(player.peer_id)
		_quest_hp_seen[player.peer_id] = player.hp_lost
		print("Player %d quest: %s" % [player.peer_id, Quests.TITLES[quest_id]])


## Host: progress on a quest; pays out the moment it's done.
func _quest_count(peer_id: int, quest_id: int, amount: float = 1.0) -> void:
	if _quests.count(peer_id, quest_id, amount):
		_pay_quest(peer_id)


## Host, every tick: quests that are about time or totals (Untouchable, Arsenal),
## and the progress every player sees.
func _tick_quests(delta: float) -> void:
	for player: Player in _player_nodes():
		var peer_id := player.peer_id
		if _quests.is_on(peer_id, Quests.Id.UNTOUCHABLE):
			var hit: bool = player.hp_lost != _quest_hp_seen.get(peer_id, player.hp_lost)
			_quest_hp_seen[peer_id] = player.hp_lost
			if hit or player.is_downed():
				_quests.set_progress(peer_id, Quests.Id.UNTOUCHABLE, 0.0)
			else:
				_quest_count(peer_id, Quests.Id.UNTOUCHABLE, delta)
		if _quests.is_on(peer_id, Quests.Id.ARSENAL):
			var dealt: int = _auto_weapon_damage(peer_id) - _quest_damage_base.get(peer_id, 0)
			if _quests.set_progress(peer_id, Quests.Id.ARSENAL, dealt):
				_pay_quest(peer_id)
		player.quest_progress = _quests.shown_progress(peer_id)


## Host: all damage this player has dealt with auto weapons this run.
func _auto_weapon_damage(peer_id: int) -> int:
	var total := 0
	var by_source: Dictionary = _enemies.damage_by_source.get(peer_id, {})
	for source: int in by_source:
		if DamageSource.weapon_id(source) >= 0:
			total += int(by_source[source])
	return total


## Host: a quest is done. Coins, or a relic the player doesn't own yet (coins
## if they own them all).
func _pay_quest(peer_id: int) -> void:
	var player := _player_by_id(peer_id)
	var quest_id: int = _quests.quest_of.get(peer_id, -1)
	if player == null or quest_id < 0:
		return
	player.quest_progress = Quests.TARGETS[quest_id]
	var reward := "%d coins" % Quests.REWARDS[quest_id]
	var coins := Quests.REWARDS[quest_id]
	if coins == Quests.RELIC_REWARD:
		var relics := Relics.roll_offers(_rng, player.relic_ids, _player_nodes().size() > 1, player.stats)
		if relics.is_empty():
			coins = QUEST_COINS_WHEN_NO_RELIC
			reward = "%d coins" % coins
		else:
			_shop.host_grant_relic(peer_id, relics[0], _ready_peer_list())
			reward = Relics.get_relic(relics[0]).title
	if coins > 0:
		player.coins += coins
		_run_stats.add(peer_id, RunStats.Stat.COINS_EARNED, coins)
	var text := "%s completed a quest: %s! (%s)" % [player.display_name(), Quests.TITLES[quest_id], reward]
	print(text)
	_show_quest_done(peer_id, text)
	for target: int in _ready_peers:
		_receive_quest_done.rpc_id(target, peer_id, text)


## Everyone: a quest was finished (a fanfare for the player who did it).
func _show_quest_done(peer_id: int, text: String) -> void:
	_hud.toast(text, Hud.QUEST_DONE_COLOR)
	var player := _player_by_id(peer_id)
	if player != null and player.is_local():
		Sfx.play(&"quest", -3.0)
		_effects.burst(player.world_position(), Hud.QUEST_DONE_COLOR, 20, 90.0, 0.6, 1.5)


@rpc("authority", "call_remote", "reliable")
func _receive_quest_done(peer_id: int, text: String) -> void:
	_show_quest_done(peer_id, text)


## "Quest: Slayer 120/250" for the HUD ("" without a quest).
func _quest_text(player: Player) -> String:
	if player.quest_id < 0 or _is_between_stages():
		return ""
	var target := Quests.TARGETS[player.quest_id]
	if player.quest_progress >= target:
		return "Quest done: %s" % Quests.TITLES[player.quest_id]
	if target <= 1:
		return "Quest: %s (%s)" % [Quests.TITLES[player.quest_id], Quests.description(player.quest_id)]
	return "Quest: %s %d/%d" % [Quests.TITLES[player.quest_id], player.quest_progress, target]


## Host: put a power-up on the ground (Kind as its value).
func _drop_power_up(at: Vector2, kind: int) -> void:
	_power_ups.spawn_host(at.clamp(BOUNDS.grow(-12.0).position, BOUNDS.grow(-12.0).end), kind)


## Host: someone grabbed a power-up. Apply it, then show it on every screen.
func _on_power_up_collected(kind: int, collector_peer_id: int) -> void:
	var player := _player_by_id(collector_peer_id)
	if player == null or not PowerUps.is_valid_kind(kind):
		return
	_quest_count(collector_peer_id, Quests.Id.SCAVENGER)
	var at := player.state.position
	match kind:
		PowerUps.Kind.HEART:
			player.health.heal_share(PowerUps.HEART_HEAL_SHARE)
		PowerUps.Kind.HOLY_BOMB:
			var damage := roundi(PowerUps.BOMB_DAMAGE * hp_factor(false, _run_depth()) * _config.enemy_health)
			_enemies.smite(at, PowerUps.BOMB_RADIUS, damage, collector_peer_id, DamageSource.HOLY_BOMB)
		PowerUps.Kind.FROST_HOURGLASS:
			_enemies.freeze_all(PowerUps.FROST_SECONDS)
	_show_power_up(kind, collector_peer_id, at)
	for peer_id: int in _ready_peers:
		_receive_power_up.rpc_id(peer_id, kind, collector_peer_id, at)


## Everyone: a power-up went off (effects; Soul Magnet and frozen bullets run on every peer).
func _show_power_up(kind: int, collector_peer_id: int, at: Vector2) -> void:
	var player := _player_by_id(collector_peer_id)
	var who := player.display_name() if player != null else "Someone"
	if player != null and player.is_local():
		who = "You"
	match kind:
		PowerUps.Kind.HEART:
			_effects.burst(at, HURT_COLOR, 12, 60.0, 0.5, 1.5)
		PowerUps.Kind.SOUL_MAGNET:
			_gems.attract_all(collector_peer_id)
			_effects.burst(at, Color(0.5, 0.75, 1.0), 16, 90.0, 0.5, 1.5)
		PowerUps.Kind.HOLY_BOMB:
			_detonate_blast(at, PowerUps.BOMB_RADIUS)
			_effects.burst(at, Color(1.0, 0.9, 0.5), 30, 200.0, 0.6, 2.0)
		PowerUps.Kind.FROST_HOURGLASS:
			_enemy_bullets.freeze_all(PowerUps.FROST_SECONDS)
			_effects.burst(at, PowerUps.FROST_COLOR, 24, 140.0, 0.6, 1.5)
			Sfx.play(&"hex", -4.0, 1.5)
	_hud.toast("%s grabbed %s!" % [who, PowerUps.TITLES[kind]], Color(1.0, 0.9, 0.6))


# --- Map events (MapEvents decides; the arena hands out the rewards) ------------

## Host: a champion or thief for an event. Champions get tougher with more players, like bosses.
func _spawn_event_enemy(type_id: int, at: Vector2) -> Enemy:
	var type := EnemyTypes.get_type(type_id)
	var players := maxi(_player_nodes().size(), 1)
	var hit_points := roundi(_scaled_hp(type_id) * (1.0 + type.hp_per_extra_player * (players - 1)))
	return _enemies.spawn(type_id, at, hit_points)


## Host: a champion died: a pile of coins and a power-up next to its chest.
func _on_champion_slain(at: Vector2, _champion_type: int) -> void:
	for player: Player in _player_nodes():
		_quest_count(player.peer_id, Quests.Id.CHAMPION_HUNTER)
	_scatter_coins(at, CHAMPION_COINS, 3, 26.0)
	_drop_power_up(at + Vector2(0, 18), PowerUps.pick_kind(_rng.randf()))


## Host: the first player to touch a champion's chest gets an auto weapon (or a
## level of one); with every weapon maxed, coins instead.
func _on_chest_opened(peer_id: int, at: Vector2) -> void:
	var player := _player_by_id(peer_id)
	if player == null:
		return
	_show_chest_opened(at)
	for target: int in _ready_peers:
		_receive_chest_opened.rpc_id(target, at)
	var weapon_id := _weapons.random_upgradable_weapon(player)
	if weapon_id < 0:
		player.coins += CHEST_COINS_WHEN_MAXED
		_run_stats.add(peer_id, RunStats.Stat.COINS_EARNED, CHEST_COINS_WHEN_MAXED)
		_events.announce("%s opened the chest: %d coins!" % [player.display_name(), CHEST_COINS_WHEN_MAXED])
		return
	var level: int = player.weapon_levels.get(weapon_id, 0) + 1
	_weapons.grant(peer_id, weapon_id, _ready_peer_list())
	_events.announce("%s opened the chest: %s%s!" % [player.display_name(), AutoWeapons.get_weapon(weapon_id).title,
		"" if level <= 1 else " Lv %d" % level])


## Host: everyone in the circle heals, and a ring of XP gems worth most of a level appears.
func _on_ritual_completed(at: Vector2, inside: Array[int]) -> void:
	for peer_id: int in inside:
		_quest_count(peer_id, Quests.Id.RITUALIST)
	for peer_id: int in inside:
		var player := _player_by_id(peer_id)
		if player != null:
			player.health.heal_share(RITUAL_HEAL_SHARE)
	var total := roundi(TeamProgress.xp_to_next(_team.level, _team.player_count, _team.xp_rate) * RITUAL_XP_SHARE)
	var gems := clampi(total / 5, 6, 24)
	for i: int in gems:
		var value := maxi(total / gems + (1 if i < total % gems else 0), 1)
		var spot := at + Vector2.from_angle(TAU * i / gems) * _rng.randf_range(14.0, 34.0)
		if not _gems.spawn_host(spot, value):
			_on_gem_collected(value, inside[0] if not inside.is_empty() else 1)
	_show_ritual_done(at)
	for target: int in _ready_peers:
		_receive_ritual_done.rpc_id(target, at)


## Host: the thief bursts into a shower of coins.
func _on_runner_caught(at: Vector2) -> void:
	for player: Player in _player_nodes():
		_quest_count(player.peer_id, Quests.Id.THIEF_CATCHER)
	_scatter_coins(at, RUNNER_COINS, 2, 30.0)


## Host: a ritual calls a few of this stage's enemies from around the circle.
func _on_ritual_wave(at: Vector2) -> void:
	var count := RITUAL_WAVE_SIZE + _player_nodes().size() - 1
	var inner := BOUNDS.grow(-16.0)
	for i: int in count:
		var type_id := _random_stage_enemy()
		var spot := (at + Vector2.from_angle(_rng.randf() * TAU) * RITUAL_WAVE_DISTANCE).clamp(inner.position, inner.end)
		_enemies.spawn(type_id, spot, _scaled_hp(type_id))


## A regular enemy type this stage is already sending (by its spawn weights).
func _random_stage_enemy() -> int:
	var entries: Array[SpawnEntry] = []
	var total := 0.0
	for entry: SpawnEntry in Stages.get_stage(_stage).spawns:
		if entry.unlock_time <= _elapsed:
			entries.append(entry)
			total += entry.weight
	if entries.is_empty():
		return Stages.get_stage(_stage).pack_type
	var roll := _rng.randf() * total
	for entry: SpawnEntry in entries:
		roll -= entry.weight
		if roll <= 0.0:
			return entry.enemy_type
	return entries[-1].enemy_type


func _scatter_coins(at: Vector2, count: int, value: int, spread: float) -> void:
	var inner := BOUNDS.grow(-8.0)
	for i: int in count:
		var spot := (at + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(4.0, spread)).clamp(inner.position, inner.end)
		_coins.spawn_host(spot, value)


## Everyone: a line about an event (toast + chime).
func _on_event_announced(text: String) -> void:
	_hud.toast(text, Color(1.0, 0.85, 0.5))
	Sfx.play(&"event", -8.0)


## Everyone: a chest bursts open.
func _show_chest_opened(at: Vector2) -> void:
	_effects.burst(at, Color(1.0, 0.85, 0.4), 24, 110.0, 0.6, 1.5)
	if _near_local_player(at):
		Sfx.play(&"chest", -2.0)


## Everyone: a ritual finished.
func _show_ritual_done(at: Vector2) -> void:
	_effects.burst(at, MapEvents.RITUAL_COLOR, 30, 120.0, 0.7, 2.0)
	var ring := BombBlast.new()
	ring.radius = MapEvents.RITUAL_RADIUS * 1.5
	ring.color = MapEvents.RITUAL_FILL_COLOR
	ring.position = at
	add_child(ring)
	if _near_local_player(at):
		Sfx.play(&"revive", -3.0)


@rpc("authority", "call_remote", "reliable")
func _receive_chest_opened(at: Vector2) -> void:
	_show_chest_opened(at)


@rpc("authority", "call_remote", "reliable")
func _receive_ritual_done(at: Vector2) -> void:
	_show_ritual_done(at)


## Coins are first come, first served: they go to whoever picked them up.
func _on_coin_collected(value: int, collector_peer_id: int) -> void:
	var player := _player_by_id(collector_peer_id)
	if player != null:
		if player.stats.coin_luck > 0.0 and _rng.randf() < player.stats.coin_luck:
			value += 1  # Greed (Ember Shrine).
		player.coins += value
		_run_stats.add(collector_peer_id, RunStats.Stat.COINS_EARNED, value)
		_quest_count(collector_peer_id, Quests.Id.GOLD_DIGGER, value)


func _on_weapon_gained(peer_id: int, weapon_id: int) -> void:
	if multiplayer.is_server():
		if not _weapon_owned_since.has(peer_id):
			_weapon_owned_since[peer_id] = {}
		if not _weapon_owned_since[peer_id].has(weapon_id):
			_weapon_owned_since[peer_id][weapon_id] = _run_stats.run_seconds
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
	var shooter := _player_by_id(shooter_id)
	var damage := WeaponSystem.power(shooter, weapon.damage_at(level)) if shooter != null else weapon.damage_at(level)
	for angle: float in AutoWeapons.seeker_angles(level, aim):
		_projectiles.spawn(origin, Vector2.from_angle(angle) * weapon.speed, damage,
			weapon.reach / weapon.speed, shooter_id, 0, 0.0, DamageSource.of_weapon(AutoWeapons.Id.SEEKING_BOLTS))


func _on_relic_bought(peer_id: int, relic_id: int) -> void:
	var player := _player_by_id(peer_id)
	if player != null:
		player.apply_relic(relic_id)


func _on_gem_collected(value: int, collector_peer_id: int) -> void:
	_run_stats.add(collector_peer_id, RunStats.Stat.XP_GATHERED, value)
	var levels_gained := _team.add_xp(value)
	if levels_gained > 0:
		_level_up.host_queue(levels_gained)
		for player: Player in _player_nodes():
			player.health.heal_share(LEVEL_UP_HEAL_SHARE * levels_gained)
		print("Team level %d at %.1fs (stage %d)" % [_team.level, _elapsed, _stage])


func _start_level_up() -> void:
	_phase = Phase.LEVEL_UP
	# With several level-ups queued, show the level this particular choice is for.
	var level := _team.level - _level_up.pending_levels + 1
	_level_up.host_start(_player_nodes(), level, _ready_peer_list())


## Host: everyone has chosen; play resumes after a short "3, 2, 1" (online only:
## solo has nobody to wait for, so it goes straight back to playing).
func _start_resume_countdown() -> void:
	if not Net.is_online():
		_phase = Phase.PLAYING
		return
	_phase = Phase.COUNTDOWN
	_resume_left = RESUME_COUNTDOWN_SECONDS


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


## Host: every connected client's arena has loaded.
func _all_peers_loaded() -> bool:
	for peer_id: int in multiplayer.get_peers():
		if not _ready_peers.has(peer_id):
			return false
	return true


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
	_power_ups.tick(delta, positions, radii, is_host)


# --- Shots -------------------------------------------------------------------

## Runs on the host for every player's shot, and on a client for its own
## predicted shots. Only the host tells other peers about it.
func _on_player_shot_requested(shooter: Player, input_seq: int) -> void:
	var pattern := shooter.stats.shot_pattern
	var origin := shooter.muzzle_position()
	var aim := shooter.state.aim
	var seed_value := ShotPatterns.make_seed(shooter.peer_id, input_seq)
	if shooter.stats.main_weapon != CharacterStats.MainWeapon.BOLTS:
		# Scythe, lightning and spears: the weapon system shows them (and tells clients).
		_weapons.fire_main(shooter, origin, seed_value, _enemies, multiplayer.is_server())
		if shooter.is_local():
			Sfx.play(MAIN_WEAPON_SOUNDS[shooter.stats.main_weapon], -10.0)
		return
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
			stats.bullet_lifetime, shooter_id, stats.pierce, -bullets[i + 2], DamageSource.MAIN_GUN,
			stats.ricochet, stats.homing)


## Everyone: a Bone Spear's Splinters shards (simulated on every peer like bolts;
## the host decides the hits).
func _on_shards_requested(owner_id: int, at: Vector2, angles: PackedFloat32Array, damage: int) -> void:
	for angle: float in angles:
		_projectiles.spawn(at, Vector2.from_angle(angle) * MainWeapons.SHARD_SPEED, damage, MainWeapons.SHARD_LIFETIME,
			owner_id, 0, 0.0, DamageSource.MAIN_GUN)


func _stats_of_peer(peer_id: int) -> CharacterStats:
	var player := _player_by_id(peer_id)
	return player.stats if player != null else null


## Host: set off this tick's Corpse Blast bursts, and show them everywhere (one
## message for all of them).
func _resolve_kill_bursts() -> void:
	if _burst_positions.is_empty():
		return
	for i: int in _burst_positions.size():
		_enemies.damage_in_radius(_burst_positions[i], KILL_BURST_RADIUS, _burst_damages[i], _burst_owners[i],
			DamageSource.KILL_BURST)
	_show_kill_bursts(_burst_positions)
	for peer_id: int in _ready_peers:
		_receive_kill_bursts.rpc_id(peer_id, _burst_positions.size(), _burst_positions)
	_burst_positions.clear()
	_burst_damages.clear()
	_burst_owners.clear()


## Everyone: Corpse Blast bursts. Rings only near this player (they're many).
func _show_kill_bursts(positions: PackedVector2Array) -> void:
	for at: Vector2 in positions:
		_effects.burst(at, KILL_BURST_COLOR, 6, 70.0, 0.3, 1.0)
		if _near_local_player(at, 260.0):
			var ring := BombBlast.new()
			ring.radius = KILL_BURST_RADIUS
			ring.color = KILL_BURST_COLOR
			ring.position = at
			add_child(ring)


## Everyone: a critical hit (gold sparks).
func _on_enemy_crit(at: Vector2) -> void:
	_effects.burst(at, CRIT_COLOR, 5, 90.0, 0.25, 1.0)


## Host: one of a player's auto weapons that used to be a hero ability goes off
## at `at` (WeaponSystem picked the spot). Resolve it and show it everywhere.
func _on_ability_cast(caster: Player, weapon_id: int, level: int, at: Vector2) -> void:
	var weapon := AutoWeapons.get_weapon(weapon_id)
	var power := caster.stats.auto_power
	var source := DamageSource.of_weapon(weapon_id)
	match weapon.kind:
		AutoWeapon.Kind.BLAST:
			caster.health.invulnerable_left = maxf(caster.health.invulnerable_left, weapon.duration)
			caster.health.heal_share(AutoWeapons.BLAST_HEAL_SHARE)
			_enemies.damage_in_radius(at, weapon.radius_at(level), WeaponSystem.power(caster, weapon.damage_at(level)),
				caster.peer_id, source)
			_detonate_blast(at, weapon.reach)
			for peer_id: int in _ready_peers:
				_receive_blast.rpc_id(peer_id, at, weapon.reach)
		AutoWeapon.Kind.HEX:
			var radius := weapon.radius_at(level)
			var seconds := weapon.duration * power
			_enemies.hex_in_radius(at, radius, seconds, AutoWeapons.HEX_DAMAGE_MULTIPLIER)
			_show_hex(at, radius, seconds)
			for peer_id: int in _ready_peers:
				_receive_hex.rpc_id(peer_id, at, radius, seconds)
		AutoWeapon.Kind.EFFIGY:
			var effigy := Effigy.new()
			effigy.position = at
			effigy.time_left = weapon.duration * power
			effigy.lure_radius = weapon.reach
			effigy.burst_radius = weapon.radius_at(level)
			effigy.burst_damage = WeaponSystem.power(caster, weapon.damage_at(level))
			effigy.owner_peer_id = caster.peer_id
			effigy.source = source
			_effigies.append(effigy)
			_show_effigy(effigy.position, effigy.time_left, effigy.lure_radius, caster.slot)
			for peer_id: int in _ready_peers:
				_receive_effigy.rpc_id(peer_id, effigy.position, effigy.time_left, effigy.lure_radius, caster.slot)


## Host: count down effigies; an expired one bursts, damaging enemies around it.
func _tick_effigies(delta: float) -> void:
	for i: int in range(_effigies.size() - 1, -1, -1):
		var effigy := _effigies[i]
		effigy.time_left -= delta
		if effigy.time_left > 0.0:
			continue
		_effigies.remove_at(i)
		_enemies.damage_in_radius(effigy.position, effigy.burst_radius, effigy.burst_damage, effigy.owner_peer_id,
			effigy.source)
		_effigy_burst(effigy.position, effigy.burst_radius)
		for peer_id: int in _ready_peers:
			_receive_effigy_burst.rpc_id(peer_id, effigy.position, effigy.burst_radius)


func _effigy_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for effigy: Effigy in _effigies:
		positions.append(effigy.position)
	return positions


func _effigy_lure_radius() -> float:
	var radius := 0.0
	for effigy: Effigy in _effigies:
		radius = maxf(radius, effigy.lure_radius)
	return radius


## Everyone: the hex sigil on the ground.
func _show_hex(at: Vector2, radius: float, seconds: float) -> void:
	var marker := AbilityMarker.new()
	marker.kind = AbilityMarker.Kind.HEX
	marker.radius = radius
	marker.duration = seconds
	marker.position = at
	marker.add_to_group(&"ability_markers")
	add_child(marker)
	_effects.burst(at, AbilityMarker.HEX_COLOR, 16, 90.0, 0.4, 1.5)
	if _near_local_player(at):
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
	add_child(marker)
	_effects.burst(at, Color(0.84, 0.8, 0.68), 10, 50.0, 0.35, 1.0)
	if _near_local_player(at):
		Sfx.play(&"effigy", -3.0)


## Everyone: the effigy bursts.
func _effigy_burst(at: Vector2, radius: float) -> void:
	var blast := BombBlast.new()
	blast.radius = radius
	blast.color = Color(0.84, 0.8, 0.68)
	blast.position = at
	add_child(blast)
	_effects.burst(at, Color(0.84, 0.8, 0.68), 18, 120.0, 0.45, 1.5)
	if _near_local_player(at):
		_shake_local(3.0)
		Sfx.play(&"bomb", -8.0, 1.4)


func _clear_ability_markers() -> void:
	for marker: Node in get_tree().get_nodes_in_group(&"ability_markers"):
		marker.queue_free()


## True if `at` is close enough to what this machine's screen shows to be worth hearing.
func _near_local_player(at: Vector2, distance: float = 340.0) -> bool:
	var local := _local_player()
	if local == null:
		return false
	var listener := local.view_center() if local.spectate_target != null else local.world_position()
	return listener.distance_to(at) <= distance


func _on_enemy_vanished(at: Vector2, type_id: int, facing_left: bool) -> void:
	var type := EnemyTypes.get_type(type_id)
	var color := type.color
	var is_boss := type.is_boss
	if not type.sprite.is_empty():
		_effects.corpse(type.sprite, at, facing_left, type.sprite_scale, 1.2 if is_boss else 0.4)
	if is_boss:
		Sfx.play(&"bomb", 2.0, 0.6)
	elif _phase == Phase.PLAYING and _near_local_player(at):
		Sfx.play(&"death", -9.0)
	_effects.burst(at, color, 24 if is_boss else 6, 120.0 if is_boss else 50.0, 0.9 if is_boss else 0.35,
		3.0 if is_boss else 1.5)
	if is_boss:
		_shake_local(10.0)


func _on_player_hurt(victim: Player, amount: int) -> void:
	# Small touches get small effects; a bullet hit gets the full flash.
	var big := amount >= 10
	_effects.burst(victim.position, HURT_COLOR, 10 if big else 4, 70.0, 0.4)
	if victim.is_local():
		_hud.flash_hurt(0.28 if big else 0.14)
		Sfx.play(&"hurt", -3.0 if big else -9.0)
	if victim.is_downed() and _player_nodes().size() > 1:
		_effects.burst(victim.position, Player.SLOT_COLORS[victim.slot % Player.SLOT_COLORS.size()], 18, 90.0, 0.6, 1.5)
		Sfx.play(&"downed", -4.0)


## Everyone: a downed player got back up (also fires when a new stage respawns them).
func _on_player_revived(player: Player) -> void:
	if _phase != Phase.PLAYING:
		return
	_effects.burst(player.position, Player.REVIVE_COLOR, 20, 80.0, 0.6, 1.5)
	if player.is_local() or _near_local_player(player.position):
		Sfx.play(&"revive", -3.0)


func _shake_local(strength: float) -> void:
	var local := _local_player()
	if local != null:
		local.add_shake(strength)


## Everyone: clear enemy bullets and show the blast.
func _detonate_blast(at: Vector2, radius: float) -> void:
	_shake_local(6.0)
	Sfx.play(&"bomb")
	_enemy_bullets.clear_near(at, radius)
	var blast := BombBlast.new()
	blast.radius = radius
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
	# Whoever fired strikes their attack pose (on every peer).
	var shooter := _enemies.find_hit(origin, 6.0)
	if shooter != null:
		shooter.play_attack()
	if _near_local_player(origin, 360.0):
		Sfx.play(&"enemy_shot", -12.0)
	# Only the host's copy deals damage, so only its shooter lookup matters.
	var damage := _scaled_damage(shooter.type.bullet_damage if shooter != null else ENEMY_BULLET_DAMAGE)
	var bullets := ShotPatterns.build(pattern as ShotPatterns.Id, aim, seed_value)
	for i: int in range(0, bullets.size(), ShotPatterns.STRIDE):
		var offset := Vector2(bullets[i + 3], bullets[i + 4])
		_enemy_bullets.spawn(origin + offset, Vector2.from_angle(bullets[i]) * bullets[i + 1], damage,
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
		_hud.set_health(local.health.hp, local.health.max_hp)
		_hud.set_coins(local.coins)
		_hud.set_weapons(local.weapon_levels)
		_hud.set_quest(_quest_text(local), local.quest_id >= 0 and local.quest_progress >= Quests.TARGETS[local.quest_id])
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
	_update_minimap(local, boss)

	var status := "Solo"
	if Net.is_online():
		status = "Host" if multiplayer.is_server() else "Client  ping %d ms" % Net.ping_ms()
	_hud.set_status("Stage %d/%d   %s   players %d" % [_run_depth(), _stage_count(), status, _player_nodes().size()])

	var info := CONTROLS_HINT
	if Net.is_online() and multiplayer.is_server():
		info = _invite_hud_text() + "\n" + info
	_hud.set_info(info)

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
		Phase.COUNTDOWN:
			_hud.show_banner(str(maxi(ceili(_resume_left), 1)), "Get ready!")
		Phase.STAGE_CLEAR:
			_hud.show_banner("Stage %d cleared!" % _run_depth(), "Stage %d of %d is next. Everyone respawns." % [_run_depth() + 1, _stage_count()])
		Phase.VICTORY, Phase.RUN_OVER:
			_hud.hide_banner()  # The run summary panel shows instead.
		_:
			if _boss_banner_left > 0.0 and boss != null:
				_hud.show_banner("%s rises!" % boss.type.display_name, "Destroy it to clear the stage.")
			else:
				_hud.hide_banner()
	_hud.set_notice(_revive_notice(local))


## The line near the bottom of the screen about downed teammates ("" = none).
func _revive_notice(local: Player) -> String:
	if local == null or _phase != Phase.PLAYING or _player_nodes().size() < 2:
		return ""
	if local.is_downed():
		var text := "You're down! A teammate can revive you by standing in your circle."
		if _is_spectating():
			var watching := local.spectate_target
			var who := "yourself" if watching == null or watching == local else watching.display_name()
			text += "
Watching %s.   Space / A: switch view" % who
		return text
	var names := PackedStringArray()
	for player: Player in _player_nodes():
		if not player.is_downed():
			continue
		if Revive.in_range(player.world_position(), local.world_position()):
			return "Reviving %s... %d%%" % [player.display_name(), roundi(player.revive_progress * 100.0)]
		names.append(player.display_name())
	if names.is_empty():
		return ""
	return "%s %s down! Stand in the circle to revive." % [" and ".join(names), "is" if names.size() == 1 else "are"]


func _update_minimap(local: Player, boss: Enemy) -> void:
	_hud.minimap.visible = not _is_between_stages()
	_hud.teammate_arrows.visible = _hud.minimap.visible
	if not _hud.minimap.visible:
		return
	var markers: Array[Array] = []
	var teammates: Array[Array] = []
	for player: Player in _player_nodes():
		var color := Player.SLOT_COLORS[player.slot % Player.SLOT_COLORS.size()]
		markers.append([player.world_position(), color, player.is_local(), player.is_downed()])
		# Edge arrows only for downed teammates (go revive them; v0.18.0, owner
		# request: arrows to healthy teammates were clutter). While we watch a
		# teammate, an arrow also points back to our own body.
		if player.is_downed() and (not player.is_local() or player.spectate_target != null):
			teammates.append([player.world_position(), color, player.is_downed(),
				"You" if player.is_local() else player.display_name()])
	var view := Rect2()
	if local != null:
		var screen := get_viewport_rect().size
		view = Rect2(local.view_center() - screen / 2.0, screen)
	var events := _events.markers()
	_hud.teammate_arrows.show_state(view, teammates, events)
	_hud.minimap.events = events
	_hud.minimap.show_state(view, markers, _enemies.active_positions(), _weapons.altar_positions(),
		boss.position if boss != null else Vector2.INF, local.world_position() if local != null else Vector2.INF)


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
	_power_ups.flush_events(peers)
	_flush_enemy_patterns(peers)
	if _tick % PLAYER_SNAPSHOT_INTERVAL_TICKS == 0:
		var ids := PackedInt32Array()
		var positions := PackedVector2Array()
		var aims := PackedFloat32Array()
		var acks := PackedInt32Array()
		var hp := PackedInt32Array()
		var max_hp := PackedInt32Array()
		var flags := PackedByteArray()
		var coins := PackedInt32Array()
		var revive := PackedByteArray()
		var quest_ids := PackedInt32Array()
		var quest_progress := PackedInt32Array()
		for player: Player in _player_nodes():
			quest_ids.append(player.quest_id)
			quest_progress.append(player.quest_progress)
			ids.append(player.peer_id)
			positions.append(player.state.position)
			aims.append(player.state.aim)
			acks.append(player.last_processed_seq)
			hp.append(player.health.hp)
			max_hp.append(player.health.max_hp)
			flags.append(2 if player.health.is_bullet_safe() else 0)
			coins.append(player.coins)
			revive.append(roundi(clampf(player.revive_progress, 0.0, 1.0) * 255.0))
		# Whichever pause is running (level-up or shop) reports who we're waiting for.
		var in_shop := _phase == Phase.SHOP
		var waiting := PackedInt32Array(_shop.waiting_ids if in_shop else _level_up.waiting_ids)
		var countdown := _shop.countdown_left if in_shop else _level_up.countdown_left
		if _phase == Phase.COUNTDOWN:
			countdown = _resume_left
		for peer_id: int in peers:
			_receive_player_snapshot.rpc_id(peer_id, ids, positions, aims, acks, hp, max_hp, flags, coins, revive,
				_elapsed, _phase, _stage, _team.level, _team.xp, waiting, countdown, quest_ids, quest_progress)
	if _tick % ENEMY_SNAPSHOT_INTERVAL_TICKS == 0:
		_enemies.send_snapshot(peers)


## Client -> host, once, when this client's arena has loaded.
@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if multiplayer.is_server():
		var peer_id := multiplayer.get_remote_sender_id()
		_ready_peers[peer_id] = true
		_receive_config.rpc_id(peer_id, _config.to_dict())
		_gems.send_full_state(peer_id)
		_coins.send_full_state(peer_id)
		_power_ups.send_full_state(peer_id)
		_weapons.send_full_state(peer_id)
		_weapons.send_history(peer_id, _player_nodes())
		_level_up.host_send_history(peer_id, _player_nodes())
		_shop.host_send_history(peer_id, _player_nodes())


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_player_snapshot(ids: PackedInt32Array, positions: PackedVector2Array, aims: PackedFloat32Array,
		acks: PackedInt32Array, hp: PackedInt32Array, max_hp: PackedInt32Array, flags: PackedByteArray,
		coins: PackedInt32Array, revive: PackedByteArray, elapsed: float, phase: int, stage: int, team_level: int, team_xp: int,
		pause_waiting: PackedInt32Array, pause_countdown: float, quest_ids: PackedInt32Array,
		quest_progress: PackedInt32Array) -> void:
	for i: int in ids.size():
		var player := _player_by_id(ids[i])
		if player != null:
			player.apply_server_state(positions[i], aims[i], acks[i], hp[i], max_hp[i], (flags[i] & 2) != 0)
			player.coins = coins[i]
			if i < revive.size():
				player.revive_progress = revive[i] / 255.0
			if i < quest_ids.size() and i < quest_progress.size():
				player.quest_id = quest_ids[i] if Quests.is_valid_id(quest_ids[i]) else -1
				player.quest_progress = quest_progress[i]
	_sync_clock(elapsed)
	if stage != _stage:
		_stage = stage
		_setup_stage()
	_team.level = team_level
	_team.xp = team_xp
	if phase == Phase.SHOP:
		_shop.apply_status(pause_waiting, pause_countdown)
	elif phase == Phase.COUNTDOWN:
		_resume_left = pause_countdown
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
			_power_ups.clear()
			_events.clear()
			_weapons.clear_altars()
			_clear_ability_markers()


## Client: the host's run settings (friends who drop in mid-run never saw the lobby).
@rpc("authority", "call_remote", "reliable")
func _receive_config(data: Dictionary) -> void:
	_config = RunConfig.from_dict(data)
	RunSetup.config = _config
	if LaunchOptions.stage_seconds <= 0.0:
		_wave_duration = _config.wave_seconds
	_team.xp_rate = _config.xp_rate


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
	var t := PerfLog.start()
	_apply_enemy_patterns(patterns, origins, aims, seeds, fire_times)
	PerfLog.stop(&"rx_patterns", t)


func _apply_enemy_patterns(patterns: PackedInt32Array, origins: PackedVector2Array, aims: PackedFloat32Array,
		seeds: PackedInt32Array, fire_times: PackedFloat32Array) -> void:
	var dodge_time := _elapsed + Net.ping_ms() / 2000.0
	for i: int in patterns.size():
		var age := clampf(dodge_time - fire_times[i], 0.0, MAX_PATTERN_FAST_FORWARD)
		_spawn_enemy_pattern(patterns[i], origins[i], aims[i], seeds[i], age)


@rpc("authority", "call_remote", "reliable")
func _receive_seeker(shooter_id: int, origin: Vector2, aim: float, level: int) -> void:
	_spawn_seeker(shooter_id, origin, aim, level)


@rpc("authority", "call_remote", "reliable")
func _receive_power_up(kind: int, collector_peer_id: int, at: Vector2) -> void:
	if PowerUps.is_valid_kind(kind):
		_show_power_up(kind, collector_peer_id, at)


@rpc("authority", "call_remote", "reliable")
func _receive_blast(at: Vector2, radius: float) -> void:
	_detonate_blast(at, radius)


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


@rpc("authority", "call_remote", "reliable")
func _receive_shot(shooter_id: int, pattern: int, origin: Vector2, aim: float, seed_value: int) -> void:
	_spawn_shot(shooter_id, pattern as ShotPatterns.Id, origin, aim, seed_value)
