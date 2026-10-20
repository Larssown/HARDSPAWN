class_name World
extends Node3D
## The running match: arena, players, pickups, projectiles, effects and HUD.
## Lives at /root/World on every machine so RPC paths match.

const PICKUP_INFO := {
	"health": {"respawn": 20.0, "sfx": "pickup_health"},
	"mega": {"respawn": 35.0, "sfx": "pickup_mega"},
	"armor": {"respawn": 25.0, "sfx": "pickup_armor"},
	"ammo": {"respawn": 12.0, "sfx": "switch"},
	# Temporary tuning value; final weapon timing is still Patrik's decision.
	"weapon": {"respawn": 10.0, "sfx": "switch"},
}

var arena: Arena
var players_root: Node3D
var fx_root: Node3D
var hud: Hud
var local_player: Player = null
var pickups: Array[PickupNode] = []
var _rocket_counter := 0


func _ready() -> void:
	Music.play("ingame", 2.0)
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build()
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	fx_root = Node3D.new()
	fx_root.name = "FX"
	add_child(fx_root)
	for i in arena.pickup_defs.size():
		var d: Dictionary = arena.pickup_defs[i]
		var pk := PickupNode.new()
		pk.kind = d.kind
		if d.has("weapon"):
			pk.weapon_id = d.weapon
		pk.name = "Pickup%d" % i
		pk.position = d.pos
		add_child(pk)
		pickups.append(pk)
	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	if multiplayer.is_server():
		arena.bake_navigation()
	Game.capture_mouse()


# --- Players ----------------------------------------------------------------------

func spawn_player(id: int, info: Dictionary, pos: Vector3, yaw: float) -> void:
	if get_player(id):
		return
	var p := Player.new()
	p.name = "P%d" % id
	p.setup(id, info)
	players_root.add_child(p)
	p.teleport(pos, yaw)
	if p.is_local_human:
		local_player = p
		hud.bind_player(p)


func remove_player(id: int) -> void:
	var p := get_player(id)
	if p:
		if p == local_player:
			local_player = null
		p.queue_free()
		p.name = "Removed%d" % p.get_instance_id()


func get_player(id: int) -> Player:
	return players_root.get_node_or_null("P%d" % id) as Player


func pick_spawn(for_id: int) -> Array:
	var scored := []
	for sp in arena.spawn_points:
		var pos: Vector3 = sp[0]
		var nearest := 1e9
		for c in players_root.get_children():
			var pl := c as Player
			if pl and not pl.dead and pl.peer_id != for_id:
				nearest = minf(nearest, pl.global_position.distance_to(pos))
		scored.append([nearest + randf() * 10.0, sp])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	return scored[0][1]


# --- Pickups (host decides) ---------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for i in pickups.size():
		var pk := pickups[i]
		if not pk.available:
			pk.timer -= delta
			if pk.timer <= 0.0:
				_set_pickup(i, true)
			continue
		for c in players_root.get_children():
			var pl := c as Player
			if pl == null or pl.dead:
				continue
			if pl.global_position.distance_to(pk.position) < 1.5 and _try_take(pl, pk):
				pk.timer = PICKUP_INFO[pk.kind].respawn
				_set_pickup(i, false)
				break


func _try_take(pl: Player, pk: PickupNode) -> bool:
	var hp := pl.health
	var ar := pl.armor
	match pk.kind:
		"weapon":
			# A weapon pickup is a full load (10 / 6 / 5). Walking over it again tops you
			# back up to a full load; if you already have that much it stays for others.
			var load: int = Weapons.WEAPON_PICKUP_AMMO[pk.weapon_id]
			if pl.has_weapon(pk.weapon_id):
				if pl.ammo[pk.weapon_id] >= load:
					return false
				_grant_ammo.rpc(pl.peer_id, pk.weapon_id, load - pl.ammo[pk.weapon_id])
				return true
			_grant_weapon.rpc(pl.peer_id, pk.weapon_id)
			return true
		"ammo":
			if pl.ammo[pk.weapon_id] >= Weapons.AMMO_CAPACITY[pk.weapon_id]:
				return false
			_grant_ammo.rpc(pl.peer_id, pk.weapon_id, Weapons.AMMO_BOX_AMOUNT[pk.weapon_id])
			return true
		"health":
			if hp >= 100.0:
				return false
			hp = minf(hp + 25.0, 100.0)
		"mega":
			if hp >= 200.0:
				return false
			hp = minf(hp + 100.0, 200.0)
		"armor":
			if ar >= 150.0:
				return false
			ar = minf(ar + 50.0, 150.0)
	Game.server_set_vitals(pl.peer_id, hp, ar)
	return true


@rpc("authority", "call_local", "reliable")
func _grant_weapon(player_id: int, weapon_id: int) -> void:
	var pl := get_player(player_id)
	if pl:
		pl.grant_weapon(weapon_id)


@rpc("authority", "call_local", "reliable")
func _grant_ammo(player_id: int, weapon_id: int, amount: int) -> void:
	var pl := get_player(player_id)
	if pl:
		pl.add_ammo(weapon_id, amount)


func _set_pickup(i: int, avail: bool) -> void:
	_pickup_state(i, avail)
	for t in Game.targets():
		_pickup_state.rpc_id(t, i, avail)


@rpc("authority", "reliable")
func _pickup_state(i: int, avail: bool) -> void:
	if i < 0 or i >= pickups.size():
		return
	var pk := pickups[i]
	pk.set_available(avail)
	if not avail:
		Sfx.play_3d(PICKUP_INFO[pk.kind].sfx, pk.global_position + Vector3(0, 1, 0))


func get_pickup_states() -> Array:
	var out := []
	for pk in pickups:
		out.append(pk.available)
	return out


func set_pickup_states(states: Array) -> void:
	for i in mini(states.size(), pickups.size()):
		pickups[i].set_available(states[i])


func reset_pickups() -> void:
	for i in pickups.size():
		if not pickups[i].available:
			_set_pickup(i, true)


# --- Shots & effects ----------------------------------------------------------------

func shot_fx(shooter_id: int, weapon: int, from: Vector3, ends: PackedVector3Array) -> void:
	_do_shot_fx(shooter_id, weapon, from, ends)
	for t in Game.targets():
		_rpc_shot_fx.rpc_id(t, shooter_id, weapon, from, ends)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_shot_fx(shooter_id: int, weapon: int, from: Vector3, ends: PackedVector3Array) -> void:
	_do_shot_fx(shooter_id, weapon, from, ends)


func _do_shot_fx(shooter_id: int, weapon: int, from: Vector3, ends: PackedVector3Array) -> void:
	var w: Dictionary = Weapons.LIST[weapon]
	var shooter := get_player(shooter_id)
	var is_local := shooter != null and shooter == local_player
	if is_local:
		Sfx.play_2d(w.sfx, w.vol, randf_range(0.97, 1.03))
	else:
		Sfx.play_3d(w.sfx, from, w.vol, randf_range(0.97, 1.03))
		if shooter:
			shooter.flash_muzzle()
	var col: Color = w.color
	if weapon == Weapons.RAIL and shooter:
		col = shooter.color
	if weapon == Weapons.SHOTGUN:
		Fx.shotgun_blast(fx_root, from, col)
	for i in ends.size():
		var e := ends[i]
		if weapon == Weapons.RAIL:
			Fx.rail(fx_root, from, e, col)
			Fx.rail_impact(fx_root, e, col)
		elif weapon == Weapons.SHOTGUN:
			# A handful of visible pellet trails reads as a blast without twelve
			# full tracers and particle bursts per shot.
			if i % 3 == 0:
				Fx.tracer(fx_root, from, e, col)
			if i % 2 == 0:
				Fx.impact(fx_root, e, col)
		else:
			# Rapid local machinegun trails can form an almost continuous line
			# through the crosshair. Keep short intermittent streaks nearby.
			if not is_local or weapon != Weapons.MG or randf() < 0.35:
				var trail_end := e
				if is_local and weapon == Weapons.MG:
					trail_end = from + (e - from).limit_length(6.0)
				Fx.tracer(fx_root, from, trail_end, col)
			Fx.impact(fx_root, e, col)
	if weapon == Weapons.SHOTGUN:
		if is_local:
			Sfx.play_2d_delayed("shotgun_pump", 0.32, -7.0)
		else:
			Sfx.play_3d_delayed("shotgun_pump", 0.32, from, -7.0)


func fire_rocket(owner_id: int, from: Vector3, dir: Vector3) -> void:
	_rocket_counter += 1
	var rname := "R%d_%d" % [owner_id, _rocket_counter]
	_spawn_rocket(owner_id, rname, from, dir, true)
	for t in Game.targets():
		_rpc_spawn_rocket.rpc_id(t, owner_id, rname, from, dir)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_spawn_rocket(owner_id: int, rname: String, from: Vector3, dir: Vector3) -> void:
	_spawn_rocket(owner_id, rname, from, dir, false)
	Sfx.play_3d("rocket_fire", from, -2.0)


func _spawn_rocket(owner_id: int, rname: String, from: Vector3, dir: Vector3, real: bool) -> void:
	var r := Rocket.new()
	r.name = rname
	r.setup(owner_id, dir, real)
	r.position = from
	fx_root.add_child(r)


@rpc("authority", "reliable")
func fx_explosion(pos: Vector3, rocket_name: String) -> void:
	var r := fx_root.get_node_or_null(rocket_name)
	if r is Rocket:
		r.queue_free()
	Fx.explosion(fx_root, pos)
	Sfx.play_3d("explosion", pos, 2.0, randf_range(0.92, 1.05))
	if local_player and not local_player.dead:
		var d := local_player.global_position.distance_to(pos)
		local_player.add_shake(clampf(1.0 - d / 18.0, 0.0, 1.0) * 0.5)
