class_name ArenaHudFeed
extends Node
## Everyone: fills the HUD from the arena's state every frame (health, timer,
## boss bar, banners, minimap, edge arrows, the revive line and the host's invite).
##
## A child node of the Arena (in arena.tscn). It reads the arena's managers and
## players directly; nothing here changes the game.

const COPIED_FEEDBACK_SECONDS: float = 4.0
const BOSS_BANNER_SECONDS: float = 3.0

## We've seen this stage's boss (for the intro banner and the "BOSS" timer).
var boss_seen: bool = false
var _boss_banner_left: float = 0.0
## Seconds the invite line still says "copied to clipboard!".
var _copied_feedback_left: float = 0.0
var _announced_invite: bool = false

@onready var arena: Arena = get_parent() as Arena


## The invite was just copied (F1, or automatically once it's known).
func note_invite_copied() -> void:
	_copied_feedback_left = COPIED_FEEDBACK_SECONDS


## Host: the invite is copied automatically the moment the address is known.
func on_invite_changed() -> void:
	if not Net.invite.address.is_empty() and not _announced_invite:
		_announced_invite = true
		note_invite_copied()


func refresh(delta: float) -> void:
	_copied_feedback_left = maxf(_copied_feedback_left - delta, 0.0)
	_boss_banner_left = maxf(_boss_banner_left - delta, 0.0)
	var hud := arena._hud
	var phase := arena._phase
	var local := arena._local_player()
	if local != null:
		hud.set_health(local.health.hp, local.health.max_hp)
		hud.set_coins(local.coins)
		hud.set_build(local)
		hud.set_quest(arena._quests.text_for(local), local.quest_id >= 0 and local.quest_progress >= Quests.TARGETS[local.quest_id])
	var boss := arena._enemies.find_boss()
	if boss == null and arena._elapsed < arena._wave_duration:
		# New stage: the next boss gets its own intro banner.
		boss_seen = false
	if boss != null and not boss_seen:
		boss_seen = true
		Sfx.play(&"boss")
		_boss_banner_left = BOSS_BANNER_SECONDS
	if arena._is_between_stages():
		hud.set_timer_text("")
	elif boss_seen:
		hud.set_timer_text("BOSS")
	else:
		hud.set_time_left(arena._wave_duration - arena._elapsed)
	hud.set_boss(boss.type.display_name if boss != null else "", boss.hp_ratio if boss != null else 0.0)
	hud.set_progress(arena._team.level, arena._team.progress_ratio())
	_update_minimap(local, boss)
	if local != null:
		local.show_here_marker = phase == Arena.Phase.COUNTDOWN and not local.is_downed()

	var status := "Solo"
	if Net.is_online():
		status = "Host" if multiplayer.is_server() else "Client  ping %d ms" % Net.ping_ms()
	hud.set_status("Stage %d/%d   %s   players %d" % [arena._run_depth(), arena._stage_count(), status, arena._player_nodes().size()])

	# No controls line any more (owner: they're easy to remember); only the
	# host's invite, so it can still be copied with F1.
	hud.set_info(_invite_text() if Net.is_online() and multiplayer.is_server() else "")

	var name_of := func(peer_id: int) -> String:
		var player := arena._player_by_id(peer_id)
		return player.display_name() if player != null else "someone"
	arena._level_up.refresh_panel_status(name_of)
	arena._shop.refresh_panel(local, name_of)
	match phase:
		Arena.Phase.SHOP:
			if arena._shop.is_open_locally():
				hud.hide_banner()
			else:
				hud.show_banner("Shop", "Other players are shopping...")
		Arena.Phase.LEVEL_UP:
			if arena._level_up.has_local_choices():
				hud.hide_banner()
			else:
				hud.show_banner("Level up!", "Others are choosing.   " + arena._level_up.status_text(name_of))
		Arena.Phase.COUNTDOWN:
			hud.show_banner(str(maxi(ceili(arena._resume_left), 1)), "Get ready!")
		Arena.Phase.STAGE_CLEAR:
			hud.show_banner("Stage %d cleared!" % arena._run_depth(), "Stage %d of %d is next. Everyone respawns." % [arena._run_depth() + 1, arena._stage_count()])
		Arena.Phase.VICTORY, Arena.Phase.RUN_OVER:
			hud.hide_banner()  # The run summary panel shows instead.
		_:
			if _boss_banner_left > 0.0 and boss != null:
				hud.show_banner("%s rises!" % boss.type.display_name, "Destroy it to clear the stage.")
			else:
				hud.hide_banner()
	hud.set_notice(_revive_notice(local))


## The line near the bottom of the screen about downed teammates ("" = none).
func _revive_notice(local: Player) -> String:
	if local == null or arena._phase != Arena.Phase.PLAYING or arena._player_nodes().size() < 2:
		return ""
	if local.is_downed():
		var text := "You're down! A teammate can revive you by standing in your circle."
		if arena._is_spectating():
			var watching := local.spectate_target
			var who := "yourself" if watching == null or watching == local else watching.display_name()
			text += "\nWatching %s.   Space / A / RB: switch view" % who
		return text
	var names := PackedStringArray()
	for player: Player in arena._player_nodes():
		if not player.is_downed():
			continue
		if Revive.in_range(player.world_position(), local.world_position()):
			return "Reviving %s... %d%%" % [player.display_name(), roundi(player.revive_progress * 100.0)]
		names.append(player.display_name())
	if names.is_empty():
		return ""
	return "%s %s down! Stand in the circle to revive." % [" and ".join(names), "is" if names.size() == 1 else "are"]


func _update_minimap(local: Player, boss: Enemy) -> void:
	var hud := arena._hud
	hud.minimap.visible = not arena._is_between_stages()
	hud.teammate_arrows.visible = hud.minimap.visible
	if not hud.minimap.visible:
		return
	var markers: Array[Array] = []
	var teammates: Array[Array] = []
	var standing := PackedVector2Array()
	for player: Player in arena._player_nodes():
		var color := Player.SLOT_COLORS[player.slot % Player.SLOT_COLORS.size()]
		markers.append([player.world_position(), color, player.is_local(), player.is_downed()])
		if not player.is_downed():
			standing.append(player.world_position())
		# Edge arrows only for downed teammates (go revive them; v0.18.0, owner
		# request: arrows to healthy teammates were clutter). While we watch a
		# teammate, an arrow also points back to our own body.
		if player.is_downed() and (not player.is_local() or player.spectate_target != null):
			teammates.append([player.world_position(), color, player.is_downed(),
				"You" if player.is_local() else player.display_name()])
	var view := Rect2()
	if local != null:
		var screen := arena.get_viewport_rect().size
		view = Rect2(local.view_center() - screen / 2.0, screen)
	arena._events.player_positions = standing  # For the ritual's "x2" when several stand in it.
	var events := arena._events.markers()
	hud.teammate_arrows.show_state(view, teammates, events)
	hud.minimap.events = events
	hud.minimap.show_state(view, markers, arena._enemies.active_positions(), arena._weapons.altar_positions(),
		boss.position if boss != null else Vector2.INF, local.world_position() if local != null else Vector2.INF)


func _invite_text() -> String:
	var invite := Net.invite
	var line := "Invite: finding your public address..."
	if not invite.address.is_empty():
		var hint := "copied to clipboard!" if _copied_feedback_left > 0.0 else "F1 to copy"
		line = "Invite: %s   (%s)" % [invite.address, hint]
	return line + "\n" + invite.status
