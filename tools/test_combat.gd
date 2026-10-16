extends Node
## Run with: Godot --headless --path . res://tools/test_combat.tscn

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	get_tree().current_scene = null
	Game.match_cfg.bots = 0
	if Game.host_game() != OK:
		_fail("Could not start local host")
		return
	await get_tree().physics_frame
	Game._add_bot()
	await get_tree().physics_frame

	var player: Player = Game.world.get_player(1)
	var dummy: Player = Game.world.get_player(-1)
	if player == null or dummy == null:
		_fail("Missing players")
		return
	var brain := dummy.brain
	dummy.brain = null
	player.teleport(Vector3(0, 0.1, 0), 0.0)
	dummy.teleport(Vector3(0, 0.1, -5), PI)
	await get_tree().physics_frame

	if not Sfx.streams.has("hit_heavy") or not Sfx.streams.has("shotgun_pump"):
		_fail("New combat sounds did not load")
		return
	var confirmations := []
	Game.hit_confirmed.connect(func(damage: float): confirmations.append(damage))

	player.grant_weapon(Weapons.SHOTGUN)
	player.cooldown = 0.0
	player._fire()
	await get_tree().physics_frame
	if dummy.health >= 100.0:
		_fail("Centred shotgun shot missed")
		return

	dummy.respawn(Vector3(0, 0.1, -5), PI)
	player.grant_weapon(Weapons.RAIL)
	player.cooldown = 0.0
	player._fire()
	await get_tree().physics_frame
	if dummy.health > 10.1:
		_fail("Railgun did not deliver its direct hit")
		return
	if confirmations.size() < 2:
		_fail("Host did not confirm both hits")
		return

	dummy.respawn(Vector3(0, 0.1, -5), PI)
	for weapon_id in [Weapons.SHOTGUN, Weapons.ROCKET, Weapons.RAIL]:
		dummy.grant_weapon(weapon_id)
	brain._weapon_t = 0.0
	brain._choose_weapon(4.0, 0.016)
	if dummy.weapon != Weapons.SHOTGUN:
		_fail("Bot did not choose shotgun at close range")
		return
	brain._weapon_t = 0.0
	brain._choose_weapon(30.0, 0.016)
	if dummy.weapon != Weapons.RAIL:
		_fail("Bot did not choose railgun at long range")
		return

	player.teleport(Vector3(0, 0.1, 0), 0.0)
	player.grant_weapon(Weapons.ROCKET)
	player.select_weapon(Weapons.ROCKET)
	player.pitch = -1.45
	player.head.rotation.x = player.pitch
	player.velocity.y = Player.JUMP_VELOCITY
	player.cooldown = 0.0
	player._fire()
	var peak := player.global_position.y
	for i in 55:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	if player.health >= 100.0 or peak < 3.5:
		_fail("Rocket jump did not lift player above a normal jump: peak=%.2f hp=%.1f" % [peak, player.health])
		return

	# A slightly angled floor shot should still reach the raised ledges.
	player.respawn(Vector3(0, 0.1, 0), 0.0)
	player.grant_weapon(Weapons.ROCKET)
	player.pitch = -1.08
	player.head.rotation.x = player.pitch
	player.velocity.y = Player.JUMP_VELOCITY
	player.cooldown = 0.0
	player._fire()
	peak = player.global_position.y
	for i in 55:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	if player.health >= 100.0 or peak < 3.5:
		_fail("Angled rocket jump lacked lift: peak=%.2f hp=%.1f" % [peak, player.health])
		return

	print("PASS: shotgun centre hit, rail damage, hit confirmation, bot weapon choice, two real rocket jumps")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
