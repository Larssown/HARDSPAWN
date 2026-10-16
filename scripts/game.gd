extends Node
## Global game state: settings, LAN networking, match flow, scoring and damage.
## The host (peer 1) is authoritative for health, kills, pickups and bots.
## Every human moves and aims on their own machine and reports hits to the host.

signal players_changed
signal kill_event(victim_id: int, killer_id: int, weapon: int)
signal hit_confirmed(damage: float)
signal match_ended
signal match_restarted
signal menu_status(text: String)

const PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_TOTAL := 8
const RESPAWN_TIME := 2.5
const END_SCREEN_TIME := 12.0
const SELF_DAMAGE_SCALE := 0.35
const SPLASH_RADIUS := 4.5
const SPLASH_DAMAGE := 100.0
const DIRECT_DAMAGE := 100.0
const KNOCKBACK := 12.0
const SETTINGS_PATH := "user://settings.cfg"

const BOT_NAMES := ["Razor", "Vex", "Kordo", "Nyx", "Brick", "Sable", "Hex", "Grunt", "Volt", "Mako", "Zenith", "Crank"]
const COLORS := [
	Color(0.2, 0.8, 1.0), Color(1.0, 0.3, 0.5), Color(0.5, 1.0, 0.3), Color(1.0, 0.75, 0.2),
	Color(0.75, 0.4, 1.0), Color(1.0, 0.5, 0.15), Color(0.3, 1.0, 0.85), Color(0.95, 0.95, 0.95),
]

var settings := {"name": "Player", "sensitivity": 0.12, "fov": 100.0, "fps_cap": 30, "volume": 0.8}
var match_cfg := {"bots": 3, "difficulty": 1, "time_limit": 600}
## id -> {name, kills, deaths, bot, color}. Bots have negative ids.
var players: Dictionary = {}
var time_left := 0.0
var match_over := false
var world: World = null
var menu_message := ""
## Mouse motion is ignored until this time (ms) so the cursor-capture jump doesn't spin the view.
var ignore_mouse_until := 0
## Clients that have loaded the world and can receive per-frame updates.
var ready_peers: Array[int] = []

var _end_timer := 0.0
var _broadcaster: PacketPeerUDP = null
var _broadcast_t := 0.0
var _sync_t := 0.0
var _decay_t := 0.0
var _next_bot := 0
var _quit_after := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_settings()
	apply_settings()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_parse_cmdline()


func _process(delta: float) -> void:
	if _quit_after > 0.0:
		_quit_after -= delta
		if _quit_after <= 0.0:
			_print_summary()
			get_tree().quit()
	if world == null:
		return
	if not match_over:
		time_left = maxf(time_left - delta, 0.0)
	if not multiplayer.is_server():
		return
	_broadcast_t -= delta
	if _broadcast_t <= 0.0:
		_broadcast_t = 1.0
		_broadcast()
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 2.0
		_time_sync.rpc(time_left)
	_decay_t -= delta
	if _decay_t <= 0.0:
		_decay_t = 1.0
		_decay_vitals()
	if match_over:
		_end_timer -= delta
		if _end_timer <= 0.0:
			_restart_match.rpc()
	elif time_left <= 0.0:
		_end_match.rpc()


# --- Settings -----------------------------------------------------------------

func apply_settings() -> void:
	Engine.max_fps = int(settings.fps_cap)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings.volume), 0.001)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	for k in match_cfg:
		cfg.set_value("match", k, match_cfg[k])
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])
	for k in match_cfg:
		match_cfg[k] = cfg.get_value("match", k, match_cfg[k])


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "weapon_1": [KEY_1], "weapon_2": [KEY_2], "weapon_3": [KEY_3],
		"weapon_4": [KEY_4], "weapon_last": [KEY_Q], "scoreboard": [KEY_TAB], "pause": [KEY_ESCAPE],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mouse := {"fire": MOUSE_BUTTON_LEFT, "zoom": MOUSE_BUTTON_RIGHT,
		"weapon_next": MOUSE_BUTTON_WHEEL_UP, "weapon_prev": MOUSE_BUTTON_WHEEL_DOWN}
	for action in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse[action]
		InputMap.action_add_event(action, mb)


func _parse_cmdline() -> void:
	# Test helpers: godot --path . -- --host --bots=3 --quit=10   or   -- --join=127.0.0.1
	var cmd := {}
	for a in OS.get_cmdline_user_args():
		var parts := a.trim_prefix("--").split("=")
		cmd[parts[0]] = parts[1] if parts.size() > 1 else "1"
	if cmd.has("name"):
		settings.name = cmd.name
	if cmd.has("bots"):
		match_cfg.bots = int(cmd.bots)
	if cmd.has("time"):
		match_cfg.time_limit = int(cmd.time)
	if cmd.has("quit"):
		_quit_after = float(cmd.quit)
	if cmd.has("shot"):
		get_tree().create_timer(float(cmd.get("shot_delay", "4"))).timeout.connect(func():
			get_viewport().get_texture().get_image().save_png(cmd.shot))
	if cmd.has("host"):
		host_game.call_deferred()
	elif cmd.has("join"):
		join_game.call_deferred(cmd.join)


func _print_summary() -> void:
	print("--- HARDSPAWN summary (peer %d) ---" % multiplayer.get_unique_id())
	for id in players:
		var p: Player = world.get_player(id) if world else null
		var pos := p.global_position if p else Vector3.ZERO
		print("  %s  frags=%d deaths=%d hp=%d pos=%s yaw=%.2f pitch=%.2f" % [players[id].name, players[id].kills,
			players[id].deaths, p.health if p else 0, pos, p.yaw if p else 0.0, p.pitch if p else 0.0])


# --- Hosting / joining --------------------------------------------------------

func host_game() -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_TOTAL - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players.clear()
	ready_peers.clear()
	_next_bot = 0
	match_over = false
	time_left = float(match_cfg.time_limit)
	_create_world()
	_add_player(1, settings.name, false)
	for i in int(match_cfg.bots):
		_add_bot()
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	return OK


func join_game(ip: String) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave_game(message := "") -> void:
	if _broadcaster:
		_broadcaster.close()
		_broadcaster = null
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	ready_peers.clear()
	world = null
	menu_message = message
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ignore_mouse_until = Time.get_ticks_msec() + 150


func get_lan_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"


func _create_world() -> void:
	var w := World.new()
	w.name = "World"
	var tree := get_tree()
	var old := tree.current_scene
	tree.root.add_child(w)
	tree.current_scene = w
	if old:
		old.queue_free()
	world = w


func _broadcast() -> void:
	if _broadcaster == null:
		return
	var humans := 0
	for id in players:
		if not players[id].bot:
			humans += 1
	var data := JSON.stringify({"game": "HARDSPAWN", "host": settings.name, "humans": humans,
		"total": players.size(), "max": MAX_TOTAL}).to_utf8_buffer()
	var targets := ["255.255.255.255"]
	var ip := get_lan_ip()
	if ip != "127.0.0.1":
		var parts := ip.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for t in targets:
		_broadcaster.set_dest_address(t, DISCOVERY_PORT)
		_broadcaster.put_packet(data)


func _on_connected_to_server() -> void:
	_register.rpc_id(1, str(settings.name))


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	menu_status.emit("Could not connect to the host.")


func _on_server_disconnected() -> void:
	leave_game("The host left the game.")


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	ready_peers.erase(id)
	_set_ready_peers.rpc(ready_peers)
	if players.has(id):
		_remove_player.rpc(id)


@rpc("authority", "reliable")
func _set_ready_peers(peers: Array) -> void:
	ready_peers.assign(peers)


## Everyone (except me) who should receive gameplay updates right now.
func targets() -> Array[int]:
	var me := multiplayer.get_unique_id()
	var out: Array[int] = []
	if me != 1:
		out.append(1)
	for id in ready_peers:
		if id != me:
			out.append(id)
	return out


func _free_color() -> int:
	var used := []
	for id in players:
		used.append(int(players[id].color))
	for i in COLORS.size():
		if not i in used:
			return i
	return randi() % COLORS.size()


func _add_player(id: int, pname: String, bot: bool) -> void:
	var info := {"name": pname, "kills": 0, "deaths": 0, "bot": bot, "color": _free_color()}
	players[id] = info
	var sp: Array = world.pick_spawn(id)
	_spawn_player.rpc(id, info, sp[0], sp[1])


func _add_bot() -> void:
	_next_bot += 1
	var used := []
	for id in players:
		used.append(players[id].name)
	var bname := "Bot %d" % _next_bot
	for n in BOT_NAMES:
		if not n in used:
			bname = n
			break
	_add_player(-_next_bot, bname, true)


func _remove_one_bot() -> void:
	for id in players:
		if players[id].bot:
			_remove_player.rpc(id)
			return


@rpc("any_peer", "reliable")
func _register(pname: String) -> void:
	if not multiplayer.is_server() or world == null:
		return
	var id := multiplayer.get_remote_sender_id()
	pname = pname.strip_edges().substr(0, 16)
	if pname == "":
		pname = "Player"
	if players.size() >= MAX_TOTAL:
		_remove_one_bot()
	var snapshot := {}
	for pid in players:
		var p := world.get_player(pid)
		if p == null:
			continue
		snapshot[pid] = {"info": players[pid], "pos": p.global_position, "yaw": p.yaw,
			"dead": p.dead, "hp": p.health, "armor": p.armor,
			"owned_weapons": p.owned_weapons, "weapon": p.weapon}
	_client_init.rpc_id(id, match_cfg, time_left, match_over, snapshot, world.get_pickup_states())
	_add_player(id, pname, false)
	ready_peers.append(id)
	_set_ready_peers.rpc(ready_peers)


@rpc("authority", "reliable")
func _client_init(cfg: Dictionary, t: float, over: bool, snapshot: Dictionary, pickup_states: Array) -> void:
	match_cfg = cfg
	time_left = t
	match_over = over
	players.clear()
	_create_world()
	for pid in snapshot:
		var s: Dictionary = snapshot[pid]
		players[pid] = s.info
		world.spawn_player(pid, s.info, s.pos, s.yaw)
		var p := world.get_player(pid)
		p.health = s.hp
		p.armor = s.armor
		p.set_loadout(s.owned_weapons, s.weapon)
		if s.dead:
			p.set_dead_silent()
	world.set_pickup_states(pickup_states)
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _spawn_player(id: int, info: Dictionary, pos: Vector3, yaw: float) -> void:
	players[id] = info
	if world:
		world.spawn_player(id, info, pos, yaw)
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _remove_player(id: int) -> void:
	players.erase(id)
	if world:
		world.remove_player(id)
	players_changed.emit()


# --- Damage & kills (host only) ----------------------------------------------

## Called by a human shooter on their own machine.
func report_hit(victim_id: int, dmg: float, weapon: int) -> void:
	if multiplayer.is_server():
		server_damage(victim_id, multiplayer.get_unique_id(), dmg, weapon)
	else:
		_report_hit.rpc_id(1, victim_id, dmg, weapon)


@rpc("any_peer", "reliable")
func _report_hit(victim_id: int, dmg: float, weapon: int) -> void:
	if multiplayer.is_server():
		server_damage(victim_id, multiplayer.get_remote_sender_id(), clampf(dmg, 0.0, 999.0), weapon)


## Called by whoever owns a real rocket when it explodes.
func report_explosion(owner_id: int, pos: Vector3, direct_id: int, rocket_name: String) -> void:
	if multiplayer.is_server():
		_server_explosion(owner_id, pos, direct_id, rocket_name)
	else:
		_report_explosion.rpc_id(1, pos, direct_id, rocket_name)


@rpc("any_peer", "reliable")
func _report_explosion(pos: Vector3, direct_id: int, rocket_name: String) -> void:
	if multiplayer.is_server():
		_server_explosion(multiplayer.get_remote_sender_id(), pos, direct_id, rocket_name)


func _server_explosion(owner_id: int, pos: Vector3, direct_id: int, rocket_name: String) -> void:
	if world == null:
		return
	world.fx_explosion(pos, rocket_name)
	for t in targets():
		world.fx_explosion.rpc_id(t, pos, rocket_name)
	for pid in players.keys():
		var p := world.get_player(pid)
		if p == null or p.dead:
			continue
		var center := p.global_position + Vector3(0, 0.9, 0)
		var d := center.distance_to(pos)
		var dmg := 0.0
		var knock := Vector3.ZERO
		if d < SPLASH_RADIUS:
			var f := 1.0 - d / SPLASH_RADIUS
			dmg = SPLASH_DAMAGE * f
			var dir := center - pos
			if dir.length() < 0.05:
				dir = Vector3.UP
			knock = dir.normalized() * KNOCKBACK * (0.35 + 0.65 * f)
		if pid == owner_id and knock != Vector3.ZERO and pos.y < p.global_position.y + 0.6:
			# A near-ground self blast keeps useful lift even with imperfect aim.
			knock.y = maxf(knock.y, 10.0 * (1.0 - d / SPLASH_RADIUS))
		if pid == direct_id:
			dmg = maxf(dmg, DIRECT_DAMAGE)
		if dmg > 0.0 or knock != Vector3.ZERO:
			server_damage(pid, owner_id, dmg, Weapons.ROCKET, knock)


func server_damage(victim_id: int, attacker_id: int, dmg: float, weapon: int, knock := Vector3.ZERO) -> void:
	if world == null or not multiplayer.is_server():
		return
	var v := world.get_player(victim_id)
	if v == null or v.dead:
		return
	if victim_id == attacker_id:
		dmg *= SELF_DAMAGE_SCALE
	if knock != Vector3.ZERO:
		if v.is_multiplayer_authority():
			v.apply_knockback(knock)
		else:
			_knockback.rpc_id(victim_id, knock)
	if dmg <= 0.0 or match_over:
		return
	var absorbed := minf(v.armor, dmg * 0.66)
	var new_armor := v.armor - absorbed
	var new_hp := v.health - (dmg - absorbed)
	if attacker_id != victim_id and attacker_id > 0:
		if attacker_id == multiplayer.get_unique_id():
			_hit_confirm(dmg)
		elif players.has(attacker_id):
			_hit_confirm.rpc_id(attacker_id, dmg)
	_vitals.rpc(victim_id, new_hp, new_armor, attacker_id)
	if new_hp <= 0.0:
		_died.rpc(victim_id, attacker_id, weapon)
		get_tree().create_timer(RESPAWN_TIME).timeout.connect(_server_respawn.bind(victim_id))


func server_set_vitals(id: int, hp: float, ar: float) -> void:
	_vitals.rpc(id, hp, ar, 0)


func _decay_vitals() -> void:
	for pid in players:
		var p := world.get_player(pid)
		if p == null or p.dead or (p.health <= 100.0 and p.armor <= 100.0):
			continue
		var hp := p.health - 1.0 if p.health > 100.0 else p.health
		var ar := p.armor - 1.0 if p.armor > 100.0 else p.armor
		server_set_vitals(pid, hp, ar)


func _server_respawn(id: int) -> void:
	if world == null or not players.has(id) or match_over:
		return
	var p := world.get_player(id)
	if p == null or not p.dead:
		return
	var sp: Array = world.pick_spawn(id)
	_respawn.rpc(id, sp[0], sp[1])


@rpc("authority", "reliable")
func _knockback(impulse: Vector3) -> void:
	if world and world.local_player:
		world.local_player.apply_knockback(impulse)


@rpc("authority", "reliable")
func _hit_confirm(dmg: float) -> void:
	hit_confirmed.emit(dmg)


@rpc("authority", "call_local", "reliable")
func _vitals(id: int, hp: float, ar: float, attacker: int) -> void:
	if world == null:
		return
	var p := world.get_player(id)
	if p == null:
		return
	var hurt := hp < p.health
	p.health = hp
	p.armor = ar
	if hurt:
		p.on_hurt(attacker)


@rpc("authority", "call_local", "reliable")
func _died(victim: int, killer: int, weapon: int) -> void:
	if players.has(victim):
		players[victim].deaths += 1
		if killer == victim or not players.has(killer):
			players[victim].kills -= 1
		else:
			players[killer].kills += 1
	if world:
		var p := world.get_player(victim)
		if p:
			p.die()
	kill_event.emit(victim, killer, weapon)
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _respawn(id: int, pos: Vector3, yaw: float) -> void:
	if world:
		var p := world.get_player(id)
		if p:
			p.respawn(pos, yaw)


# --- Match flow ---------------------------------------------------------------

@rpc("authority", "unreliable")
func _time_sync(t: float) -> void:
	time_left = t


@rpc("authority", "call_local", "reliable")
func _end_match() -> void:
	match_over = true
	time_left = 0.0
	_end_timer = END_SCREEN_TIME
	match_ended.emit()


@rpc("authority", "call_local", "reliable")
func _restart_match() -> void:
	match_over = false
	time_left = float(match_cfg.time_limit)
	for id in players:
		players[id].kills = 0
		players[id].deaths = 0
	match_restarted.emit()
	players_changed.emit()
	if multiplayer.is_server() and world:
		world.reset_pickups()
		for id in players:
			var sp: Array = world.pick_spawn(id)
			_respawn.rpc(id, sp[0], sp[1])


func sorted_scores() -> Array:
	var list := []
	for id in players:
		list.append({"id": id, "name": players[id].name, "kills": players[id].kills,
			"deaths": players[id].deaths, "color": COLORS[int(players[id].color) % COLORS.size()]})
	list.sort_custom(func(a, b):
		return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
	return list
