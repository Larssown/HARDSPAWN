extends Node
## Run with: godot --headless --path . res://tools/test_announcer.tscn


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	get_tree().current_scene = null
	Game.match_cfg.bots = 0
	Game.match_cfg.time_limit = 65
	if Game.host_game(17779) != OK:
		_fail("Could not start local host")
		return
	Game._add_bot()
	await get_tree().physics_frame
	var player: Player = Game.world.get_player(1)
	var victim: Player = Game.world.get_player(-1)
	if player == null or victim == null:
		_fail("Missing test players")
		return
	victim.brain = null
	var start_pos := victim.global_position
	victim.velocity = Vector3(8, 4, 0)
	var start_ammo := player.ammo[Weapons.MG]
	player._fire()
	await get_tree().physics_frame
	if Game.can_act() or victim.global_position.distance_to(start_pos) > 0.01 or player.ammo[Weapons.MG] != start_ammo:
		_fail("Countdown did not lock movement and firing")
		return
	await get_tree().create_timer(3.1).timeout
	if not Game.can_act() or Game.time_left < 64.5:
		_fail("Countdown did not unlock after three seconds with full match time")
		return
	for sound in Sfx.ANNOUNCER_NAMES:
		if not Sfx.streams.has(sound):
			_fail("Missing announcer sound: " + sound)
			return

	# A real camera-centred rail shot at head height must trigger both calls.
	player.teleport(Vector3(0, 0.1, -18), 0.0)
	victim.teleport(Vector3(0, 0.1, -23), PI)
	victim.health = 40.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.grant_weapon(Weapons.RAIL)
	player.cooldown = 0.0
	player._fire()
	await get_tree().physics_frame
	if not victim.dead or not Game._first_blood_done or Game._kill_streaks.get(player.peer_id, 0) != 1:
		_fail("First headshot kill was not recorded: hp=%.1f dead=%s can_act=%s streak=%s" % [
			victim.health, victim.dead, Game.can_act(), Game._kill_streaks])
		return
	if not _pending("first_blood") or not _pending("terminated"):
		_fail("First blood or headshot announcement missing")
		return

	var streak_sounds := ["dualelimination", "tripple", "overkill", "insanity", "monsterkill"]
	for sound in streak_sounds:
		victim.respawn(start_pos, 0.0)
		Game.server_damage(victim.peer_id, player.peer_id, 200.0, Weapons.MG)
		if not _pending(sound):
			_fail("Missing streak announcement: " + sound)
			return
	if Game._kill_streaks.get(player.peer_id, 0) != 6:
		_fail("Six-kill streak was counted incorrectly")
		return
	Game.server_damage(player.peer_id, player.peer_id, 10000.0, -1)
	if Game._kill_streaks.get(player.peer_id, -1) != 0:
		_fail("Death did not reset the streak")
		return

	Game._last_match_time = 61.0
	Game.time_left = 60.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not _pending("1minute"):
		_fail("One-minute announcement missing")
		return
	Game._last_match_time = 31.0
	Game.time_left = 30.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not _pending("30seconds"):
		_fail("Thirty-second announcement missing")
		return

	Game._restart_match()
	if Game.can_act() or Game._first_blood_done or not Game._kill_streaks.is_empty():
		_fail("New match did not reset announcements and countdown")
		return
	print("PASS: countdown lock, ten sounds, headshot, first blood, 2-6 streaks, death reset, time calls, restart")
	get_tree().quit(0)


func _pending(sound: String) -> bool:
	return Sfx._announcer_queue.has(sound) or (Sfx._announcer.stream == Sfx.streams[sound] and Sfx._announcer.playing)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
