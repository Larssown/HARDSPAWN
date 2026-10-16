extends Node
## Run with: Godot --headless --path . res://tools/test_pickups.tscn

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	# Keep this runner alive when host_game replaces the active scene with World.
	get_tree().current_scene = null
	Game.match_cfg.bots = 0
	if Game.host_game() != OK:
		_fail("Could not start local host")
		return
	await get_tree().physics_frame
	var world: World = Game.world
	var player: Player = world.get_player(1)
	if player == null or player.weapon != Weapons.MG or player.owned_weapons != 1:
		_fail("Player did not start with only the machinegun")
		return
	var nav_map := world.get_world_3d().navigation_map
	# Runtime baking completes before the server publishes the polygons.
	await get_tree().create_timer(1.0).timeout
	for item in world.pickups:
		if item.kind == "weapon":
			var route := NavigationServer3D.map_get_path(nav_map, Vector3(8, 0, 11), item.position, true)
			if route.size() < 2 or route[-1].distance_to(item.position) > 2.5:
				_fail("Weapon pickup has no walkable route: %d" % item.weapon_id)
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
		if not player.has_weapon(weapon_id) or pickup.available:
			_fail("Weapon pickup %d was not granted by host" % weapon_id)
			return
		pickup.timer = 0.01
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not pickup.available:
			_fail("Weapon pickup %d did not respawn" % weapon_id)
			return

	player.respawn(Vector3(0, 0.1, 0), 0.0)
	if player.weapon != Weapons.MG or player.owned_weapons != 1:
		_fail("Loadout did not reset on respawn")
		return
	print("PASS: map routes, fixed weapon pickups, host grant, respawn timer and MG-only restart")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
