class_name MapEvents
extends Node2D
## Events around the map, so there's a reason to explore the whole arena:
## - Champion lair: a sleeping champion (a crowned mini-boss) wakes when someone
##   comes close. Killing it leaves a chest with an auto weapon.
## - Ritual circle: stand inside while the dead pour in; when it fills up, the
##   team gets a burst of XP and everyone inside heals.
## - Grave Robber: a thief that runs away dropping coins. Catch it before it
##   escapes for a coin shower.
## A lair and a ritual are placed when a stage starts; more pop up during it.
##
## Host: places events, runs them, and decides what happens (the arena hands out
## the rewards through the signals). Sends a small snapshot of every event a few
## times per second. Everyone: draws them, and the arena points arrows at them.

## Host: the arena hands out what an event gives.
signal champion_slain(at: Vector2, champion_type: int)
signal chest_opened(peer_id: int, at: Vector2)
signal ritual_completed(at: Vector2, inside: Array[int])
signal runner_caught(at: Vector2)
signal runner_escaped(at: Vector2)
## Host: a ritual calls more enemies (spawn some around `at`).
signal wave_requested(at: Vector2)
## Host: the Grave Robber drops a stolen coin here.
signal coin_dropped(at: Vector2)
## Everyone: show this line to the team (toasts).
signal announced(text: String)

## Sent as numbers: only add new kinds/states at the end.
enum Kind { CHAMPION, RITUAL, RUNNER, CHEST }
## WAITING: lair asleep / ritual not started. ACTIVE: champion awake, ritual
## being held, thief running.
enum State { WAITING, ACTIVE }

## A sleeping champion wakes when a player comes this close.
const WAKE_RADIUS: float = 150.0
const RITUAL_RADIUS: float = 42.0
## Seconds of standing in the circle to finish a ritual.
const RITUAL_SECONDS: float = 15.0
## With nobody inside, a started ritual drains completely in this long.
const RITUAL_DRAIN_SECONDS: float = 30.0
## While a ritual is held, a wave is called this often.
const RITUAL_WAVE_INTERVAL: float = 1.2
## Rituals that pop up during a stage fade if nobody starts them in time.
const POPUP_RITUAL_SECONDS: float = 50.0
## Seconds before the Grave Robber escapes, and how often it drops a coin.
const RUNNER_SECONDS: float = 20.0
const RUNNER_COIN_INTERVAL: float = 1.5
const RUNNER_SPAWN_DISTANCE: float = 230.0
const CHEST_RADIUS: float = 12.0
## Stage seconds when a pop-up event appears, and which kind.
const POPUP_TIMES: Array[float] = [70.0, 140.0, 200.0]
const POPUP_KINDS: Array[int] = [Kind.RUNNER, Kind.RITUAL, Kind.RUNNER]
## Fixed events are placed at least this far from where players start (the middle)...
const LAIR_MIN_FROM_CENTER: float = 330.0
## ...this far from each other, and this far inside the walls.
const EVENT_SPACING: float = 260.0
const EDGE_INSET: float = 70.0
const SNAPSHOT_INTERVAL_TICKS: int = 6

const CHAMPION_COLOR: Color = Color(1.0, 0.35, 0.3)
const RITUAL_COLOR: Color = Color(0.75, 0.5, 1.0)
const RITUAL_FILL_COLOR: Color = Color(1.0, 0.82, 0.35)
const RUNNER_COLOR: Color = Color(1.0, 0.82, 0.35)
const CHEST_COLOR: Color = Color(1.0, 0.9, 0.5)

var bounds: Rect2 = Rect2(0, 0, 1600, 1000)
## This stage's champion (EnemyTypes id; the arena sets it on every peer).
var champion_type: int = -1
## Host: spawns an enemy for an event: func(type_id: int, at: Vector2) -> Enemy.
var spawn_enemy: Callable = Callable()

var _events: Array[MapEvent] = []
var _next_id: int = 0
var _next_popup: int = 0
var _tick: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Host: set every tick (the enemy pool, and the peers to tell).
var _enemies: EnemyManager = null
var _peers: Array[int] = []


## One event (the same fields on every peer; clients copy them from snapshots).
class MapEvent:
	var id: int
	var kind: int
	var state: int = State.WAITING
	var position: Vector2
	## Ritual: how full the circle is (0..1). Others: unused.
	var progress: float = 0.0
	## Seconds until it goes away by itself (-1 = never).
	var time_left: float = -1.0
	## Host: the enemy that is this event (champion, thief), and its type.
	var enemy: Enemy = null
	var enemy_type: int = -1
	## Host: seconds until the next ritual wave / stolen coin.
	var timer: float = 0.0


func _ready() -> void:
	_rng.randomize()
	add_to_group("map_events")


func events() -> Array[MapEvent]:
	return _events


func count() -> int:
	return _events.size()


func clear() -> void:
	_events.clear()
	queue_redraw()


## [world position, color, sprite] for every event, for edge arrows and the minimap.
func markers() -> Array[Array]:
	var result: Array[Array] = []
	for event: MapEvent in _events:
		result.append([event.position, color_of(event.kind), icon_of(event.kind)])
	return result


static func color_of(kind: int) -> Color:
	match kind:
		Kind.CHAMPION:
			return CHAMPION_COLOR
		Kind.RITUAL:
			return RITUAL_COLOR
		Kind.RUNNER:
			return RUNNER_COLOR
	return CHEST_COLOR


static func icon_of(kind: int) -> String:
	match kind:
		Kind.CHAMPION:
			return "crown"
		Kind.RITUAL:
			return "icon_ritual"
		Kind.RUNNER:
			return "coin_big"
	return "chest"


## Position of the closest event worth walking to (not an awake champion), or
## Vector2.INF (used by the autopilot).
func nearest(from: Vector2) -> Vector2:
	var best := Vector2.INF
	for event: MapEvent in _events:
		if event.kind == Kind.CHAMPION and event.state == State.ACTIVE:
			continue
		if best == Vector2.INF or from.distance_squared_to(event.position) < from.distance_squared_to(best):
			best = event.position
	return best


# --- Host --------------------------------------------------------------------

## Host: a new stage. A champion lair and a ritual circle go to random spots
## away from the middle (where everyone starts).
func host_start_stage() -> void:
	clear()
	_next_popup = 0
	var taken: Array[Vector2] = [bounds.get_center()]
	if champion_type >= 0:
		var lair := _add(Kind.CHAMPION, _free_spot(taken))
		lair.enemy_type = champion_type
		taken.append(lair.position)
	_add(Kind.RITUAL, _free_spot(taken))


## Host, every tick of play.
func host_tick(delta: float, elapsed: float, players: Array[Player], enemies: EnemyManager, boss_spawned: bool,
		peers: Array[int]) -> void:
	_enemies = enemies
	_peers = peers
	var alive: Array[Player] = []
	for player: Player in players:
		if not player.is_downed():
			alive.append(player)
	if not boss_spawned and _next_popup < POPUP_TIMES.size() and elapsed >= POPUP_TIMES[_next_popup]:
		_start_popup(POPUP_KINDS[_next_popup], alive)
		_next_popup += 1
	for i: int in range(_events.size() - 1, -1, -1):
		var event := _events[i]
		if event.time_left > 0.0:
			event.time_left = maxf(event.time_left - delta, 0.0)
		match event.kind:
			Kind.CHAMPION:
				_tick_champion(event, alive)
			Kind.RITUAL:
				_tick_ritual(event, delta, alive)
			Kind.RUNNER:
				_tick_runner(event, delta)
			Kind.CHEST:
				_tick_chest(event, alive)
		if event.time_left == 0.0:
			_events.remove_at(i)
	_tick += 1
	if _tick % SNAPSHOT_INTERVAL_TICKS == 0:
		_send_snapshot(peers)


## Host: an enemy died. If it was an event's (champion, thief), that event is
## done; returns its Kind, or -1.
func host_enemy_killed(enemy: Enemy) -> int:
	for event: MapEvent in _events:
		if event.enemy != enemy:
			continue
		event.enemy = null
		if event.kind == Kind.CHAMPION:
			# The champion leaves its chest behind.
			event.kind = Kind.CHEST
			event.state = State.WAITING
			event.position = enemy.position.clamp(bounds.grow(-16.0).position, bounds.grow(-16.0).end)
			champion_slain.emit(event.position, event.enemy_type)
			announce("%s falls! Open its chest." % EnemyTypes.get_type(event.enemy_type).display_name)
			return Kind.CHAMPION
		_events.erase(event)
		runner_caught.emit(enemy.position)
		announce("The Grave Robber is caught! Grab the coins!")
		return Kind.RUNNER
	return -1


## Host: a ritual or thief appears near a random living player.
func _start_popup(kind: int, alive: Array[Player]) -> void:
	if alive.is_empty():
		return
	var around := alive[_rng.randi() % alive.size()].state.position
	var inner := bounds.grow(-EDGE_INSET)
	var at := around
	for attempt: int in 12:
		var distance := RUNNER_SPAWN_DISTANCE if kind == Kind.RUNNER else _rng.randf_range(200.0, 320.0)
		at = around + Vector2.from_angle(_rng.randf() * TAU) * distance
		if inner.has_point(at):
			break
	at = at.clamp(inner.position, inner.end).round()
	if kind == Kind.RITUAL:
		var ritual := _add(Kind.RITUAL, at)
		ritual.time_left = POPUP_RITUAL_SECONDS
		announce("A ritual circle glows nearby. Hold it for XP!")
		return
	if not spawn_enemy.is_valid():
		return
	var thief: Enemy = spawn_enemy.call(EnemyTypes.Id.GRAVE_ROBBER, at)
	if thief == null:
		return
	var runner := _add(Kind.RUNNER, at)
	runner.state = State.ACTIVE
	runner.enemy = thief
	runner.enemy_type = EnemyTypes.Id.GRAVE_ROBBER
	runner.time_left = RUNNER_SECONDS
	runner.timer = RUNNER_COIN_INTERVAL
	announce("A Grave Robber! Catch it before it escapes!")


func _tick_champion(event: MapEvent, alive: Array[Player]) -> void:
	if event.state == State.ACTIVE:
		if is_instance_valid(event.enemy) and event.enemy.active:
			event.position = event.enemy.position
		return
	for player: Player in alive:
		if player.state.position.distance_to(event.position) <= WAKE_RADIUS and spawn_enemy.is_valid():
			event.enemy = spawn_enemy.call(event.enemy_type, event.position)
			if event.enemy != null:
				event.state = State.ACTIVE
				announce("The %s awakens!" % EnemyTypes.get_type(event.enemy_type).display_name)
			return


func _tick_ritual(event: MapEvent, delta: float, alive: Array[Player]) -> void:
	var inside: Array[int] = []
	for player: Player in alive:
		if player.state.position.distance_to(event.position) <= RITUAL_RADIUS:
			inside.append(player.peer_id)
	if event.state == State.WAITING:
		if inside.is_empty():
			return
		event.state = State.ACTIVE
		event.time_left = -1.0  # Started: it no longer fades away.
		event.timer = 0.0
		announce("The ritual begins! Stay in the circle!")
	if inside.is_empty():
		event.progress = maxf(event.progress - delta / RITUAL_DRAIN_SECONDS, 0.0)
	else:
		event.progress = minf(event.progress + delta / RITUAL_SECONDS, 1.0)
	event.timer -= delta
	if event.timer <= 0.0:
		event.timer = RITUAL_WAVE_INTERVAL
		wave_requested.emit(event.position)
	if event.progress >= 1.0:
		event.time_left = 0.0  # Removed at the end of this tick.
		ritual_completed.emit(event.position, inside)
		announce("Ritual complete! The team gains XP and heals.")


func _tick_runner(event: MapEvent, delta: float) -> void:
	if not is_instance_valid(event.enemy) or not event.enemy.active:
		event.time_left = 0.0
		return
	event.position = event.enemy.position
	event.timer -= delta
	if event.timer <= 0.0:
		event.timer = RUNNER_COIN_INTERVAL
		coin_dropped.emit(event.position)
	if event.time_left == 0.0:
		var thief := event.enemy
		event.enemy = null
		runner_escaped.emit(thief.position)
		if _enemies != null:
			_enemies.remove(thief)
		announce("The Grave Robber got away...")


func _tick_chest(event: MapEvent, alive: Array[Player]) -> void:
	for player: Player in alive:
		if player.state.position.distance_to(event.position) <= CHEST_RADIUS:
			event.time_left = 0.0
			chest_opened.emit(player.peer_id, event.position)
			return


func _add(kind: int, at: Vector2) -> MapEvent:
	var event := MapEvent.new()
	event.id = _next_id
	_next_id += 1
	event.kind = kind
	event.position = at
	_events.append(event)
	queue_redraw()
	return event


## A random spot inside the walls, far from the middle and from `taken` spots
## (the best of a few tries if none is far enough).
func _free_spot(taken: Array[Vector2]) -> Vector2:
	var inner := bounds.grow(-EDGE_INSET)
	var best := inner.get_center()
	var best_gap := -1.0
	for attempt: int in 30:
		var at := Vector2(_rng.randf_range(inner.position.x, inner.end.x), _rng.randf_range(inner.position.y, inner.end.y)).round()
		var gap := INF
		for other: Vector2 in taken:
			gap = minf(gap, at.distance_to(other))
		if at.distance_to(bounds.get_center()) < LAIR_MIN_FROM_CENTER:
			gap = minf(gap, at.distance_to(bounds.get_center()) - LAIR_MIN_FROM_CENTER)
		if gap >= EVENT_SPACING:
			return at
		if gap > best_gap:
			best_gap = gap
			best = at
	return best


## Host: a line for every player's screen.
func announce(text: String) -> void:
	print("Event: %s" % text)
	announced.emit(text)
	for peer_id: int in _peers:
		_receive_announcement.rpc_id(peer_id, text)


func _send_snapshot(peers: Array[int]) -> void:
	if peers.is_empty():
		return
	var ids := PackedInt32Array()
	var kinds := PackedByteArray()
	var states := PackedByteArray()
	var positions := PackedVector2Array()
	var values := PackedFloat32Array()
	for event: MapEvent in _events:
		ids.append(event.id)
		kinds.append(event.kind)
		states.append(event.state)
		positions.append(event.position)
		# A started ritual sends how full it is; everything else how long it has left.
		values.append(event.progress if event.kind == Kind.RITUAL and event.state == State.ACTIVE else event.time_left)
	for peer_id: int in peers:
		# The count keeps the call valid when there are no events (empty arrays only).
		_receive_snapshot.rpc_id(peer_id, ids.size(), ids, kinds, states, positions, values)


# --- Drawing -------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _events.is_empty():
		queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for event: MapEvent in _events:
		match event.kind:
			Kind.CHAMPION:
				if event.state == State.WAITING:
					_draw_lair(event, now)
			Kind.RITUAL:
				_draw_ritual(event, now)
			Kind.CHEST:
				var glow := 0.5 + 0.5 * sin(now * 4.0)
				draw_circle(event.position, 14.0, Color(CHEST_COLOR, 0.12 + 0.1 * glow))
				PixelArt.draw(self, "chest", event.position + Vector2(0, roundf(sin(now * 3.0))))


## A sleeping champion: a dark statue of it on a pulsing red ring.
func _draw_lair(event: MapEvent, now: float) -> void:
	var pulse := 0.5 + 0.5 * sin(now * 2.5)
	draw_circle(event.position, 26.0, Color(CHAMPION_COLOR, 0.07 + 0.05 * pulse))
	draw_arc(event.position, 26.0, 0.0, TAU, 32, Color(CHAMPION_COLOR, 0.35 + 0.3 * pulse), 1.0)
	if champion_type < 0:
		return
	var type := EnemyTypes.get_type(champion_type)
	PixelArt.draw(self, type.sprite, event.position, Color.WHITE, false, false, type.sprite_scale, Color(0.45, 0.4, 0.5))
	var top := PixelArt.size_of(type.sprite).y * type.sprite_scale / 2.0
	PixelArt.draw(self, "crown", event.position + Vector2(0, -top - 4.0 - roundf(pulse * 2.0)), Color.WHITE, false, false,
		1.0, Color(1, 1, 1, 0.5 + 0.5 * pulse))


## The ritual circle: a turning dashed ring with a sigil; once started, it
## fills up with a gold arc. A pop-up circle blinks when it's about to fade.
func _draw_ritual(event: MapEvent, now: float) -> void:
	var active := event.state == State.ACTIVE
	var alpha := 1.0
	if event.time_left >= 0.0 and event.time_left < 8.0:
		alpha = 0.4 + 0.6 * absf(sin(now * 6.0))
	draw_circle(event.position, RITUAL_RADIUS, Color(RITUAL_COLOR, (0.14 if active else 0.07) * alpha))
	var dashes := 24
	var turn := now * (1.2 if active else 0.4)
	for i: int in range(0, dashes, 2):
		draw_arc(event.position, RITUAL_RADIUS, turn + TAU * i / dashes, turn + TAU * (i + 1) / dashes, 4,
			Color(RITUAL_COLOR, 0.7 * alpha), 1.0)
	draw_arc(event.position, RITUAL_RADIUS * 0.55, -turn, -turn + TAU, 24, Color(RITUAL_COLOR, 0.3 * alpha), 1.0)
	PixelArt.draw(self, "icon_ritual", event.position, Color.WHITE, false, false, 1.0, Color(1, 1, 1, alpha))
	if event.progress > 0.0:
		draw_arc(event.position, RITUAL_RADIUS + 3.0, -PI / 2.0, -PI / 2.0 + TAU * event.progress, 48, RITUAL_FILL_COLOR, 2.0)


# --- Network messages ------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_snapshot(count_hint: int, ids: PackedInt32Array, kinds: PackedByteArray, states: PackedByteArray,
		positions: PackedVector2Array, values: PackedFloat32Array) -> void:
	_events.clear()
	for i: int in mini(count_hint, ids.size()):
		var event := MapEvent.new()
		event.id = ids[i]
		event.kind = kinds[i]
		event.state = states[i]
		event.position = positions[i]
		if event.kind == Kind.RITUAL and event.state == State.ACTIVE:
			event.progress = values[i]
		else:
			event.time_left = values[i]
		_events.append(event)
	queue_redraw()


@rpc("authority", "call_remote", "reliable")
func _receive_announcement(text: String) -> void:
	announced.emit(text)
