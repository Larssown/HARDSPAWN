extends Node
## Run with: godot --headless --path . res://tools/test_pickups.tscn

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	get_tree().current_scene = null
	Game.match_cfg.bots = 0
	if Game.host_game() != OK:
		_fail("Could not start local host")
		return
	await get_tree().create_timer(1.0).timeout
	var world: World = Game.world
	var player: Player = world.get_player(1)
	var arena := world.arena
	if player == null or player.weapon != Weapons.MG or player.owned_weapons != 1:
		_fail("Player did not start with only the machinegun")
		return
	if arena.jump_pads.size() != 4 or world.pickups.size() < 12:
		_fail("Missing pads or fixed pickups in the new arena")
		return

	var nav_map := world.get_world_3d().navigation_map
	var origin := Vector3(-24, 0, 13)
	for item in world.pickups:
		var route := NavigationServer3D.map_get_path(nav_map, origin, item.position, true)
		if route.size() < 2 or route[-1].distance_to(item.position) > 2.6:
			_fail("Pickup has no walkable route: %s at %s" % [item.kind, item.position])
			return
	for spawn in arena.spawn_points:
		var spawn_pos: Vector3 = spawn[0]
		var route := NavigationServer3D.map_get_path(nav_map, origin, spawn_pos, true)
		if route.size() < 2 or route[-1].distance_to(spawn_pos) > 2.6:
			_fail("Spawn has no walkable route: %s" % spawn_pos)
			return
		var sphere := SphereShape3D.new()
		sphere.radius = 0.35
		var body_check := PhysicsShapeQueryParameters3D.new()
		body_check.shape = sphere
		body_check.transform = Transform3D(Basis.IDENTITY, spawn_pos + Vector3(0, 1.0, 0))
		body_check.collision_mask = 1
		if not world.get_world_3d().direct_space_state.intersect_shape(body_check).is_empty():
			_fail("Spawn intersects solid geometry: %s" % spawn_pos)
			return

	for surface in [Vector3(-24, 0, 13), Vector3(0, 5, 0), Vector3(-17, 10, -18)]:
		var query := PhysicsRayQueryParameters3D.create(surface + Vector3(0, 1, 0),
			surface - Vector3(0, 1, 0), 1)
		if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			_fail("Level has no collision under %s" % surface)
			return
	for void_pos in [Vector3(0, 3, 4), Vector3(38, 3, 0)]:
		var query := PhysicsRayQueryParameters3D.create(void_pos, void_pos - Vector3(0, 20, 0), 1)
		if not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			_fail("The void has an invisible floor at %s" % void_pos)
			return

	player.select_weapon(Weapons.RAIL)
	if player.weapon != Weapons.MG:
		_fail("Uncollected weapon could be selected")
		return
	for weapon_id in [Weapons.SHOTGUN, Weapons.ROCKET, Weapons.RAIL]:
		var pickup: PickupNode = null
		for item in world.pickups:
			if item.kind == "weapon" and item.weapon_id == weapon_id:
				pickup = item
				break
		if pickup == null:
			_fail("Missing fixed weapon pickup %d" % weapon_id)
			return
		player.teleport(pickup.position + Vector3(0, 0.1, 0), 0.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not player.has_weapon(weapon_id) or pickup.available or player.ammo[weapon_id] <= 0:
			_fail("Weapon pickup %d did not grant a loaded gun" % weapon_id)
			return
		pickup.timer = 0.01
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not pickup.available:
			_fail("Weapon pickup %d did not respawn" % weapon_id)
			return

	player.ammo[Weapons.MG] = 0
	for item in world.pickups:
		if item.kind == "ammo":
			player.teleport(item.position + Vector3(0, 0.1, 0), 0.0)
			await get_tree().physics_frame
			await get_tree().physics_frame
			break
	if player.ammo[Weapons.MG] < Weapons.AMMO_BOX_AMOUNT[Weapons.MG]:
		_fail("Ground ammo box did not reload the machinegun")
		return

	player.respawn(Vector3(-24, 0.1, 13), 0.0)
	if player.weapon != Weapons.MG or player.owned_weapons != 1 or player.ammo[Weapons.MG] != Weapons.START_AMMO[Weapons.MG]:
		_fail("Loadout or ammo did not reset on respawn")
		return
	player.teleport(Vector3(-22, 0.1, 4), 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if player.velocity.y <= Player.JUMP_VELOCITY:
		_fail("Area3D jump pad did not launch the player")
		return

	player.teleport(Vector3(0, -2, 0), 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not player.dead:
		_fail("KillZone did not trigger a death over the central void")
		return
	print("PASS: three collidable levels, voids, routes, pickups, ammo, jump pad and lethal fall")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
