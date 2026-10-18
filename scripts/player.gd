class_name Player
extends CharacterBody3D
## A deathmatch player. Humans are simulated on their own machine, bots on the host.
## Movement is Quake/Half-Life style: ground friction, air strafing and bunny hopping.

# Movement tuning (metres / seconds). These numbers ARE the game feel.
const MAX_SPEED := 9.0
const GROUND_ACCEL := 12.0
const FRICTION := 6.0
const STOP_SPEED := 3.0
const AIR_ACCEL := 14.0
const AIR_CAP := 0.9        # low cap + high accel = strafe jumping works
const JUMP_VELOCITY := 7.2
const GRAVITY := 20.0
const EYE_HEIGHT := 1.6

var peer_id := 0
var is_bot := false
var is_local_human := false
var display_name := ""
var color := Color.WHITE

var yaw := 0.0
var pitch := 0.0
var health := 100.0
var armor := 0.0
var dead := false
var spawn_count := 0

var weapon := Weapons.MG
var last_weapon := Weapons.MG
var owned_weapons := 1 << Weapons.MG
var ammo := PackedInt32Array(Weapons.START_AMMO)
var cooldown := 0.0
var zooming := false

# Inputs: filled from keyboard/mouse for humans, by BotBrain for bots.
var in_move := Vector2.ZERO
var in_jump := false
var in_fire := false

var brain: BotBrain = null
var head: Node3D
var camera: Camera3D = null
var viewmodel: Viewmodel = null
var viewmodel_overlay: ViewmodelOverlay = null
var body_root: Node3D
var gun_pivot: Node3D
var gun_accent: StandardMaterial3D
var name_label: Label3D
var muzzle_light: OmniLight3D
var mouse_delta := Vector2.ZERO

var _air_lock := 0.0
var _was_on_floor := true
var _prev_vy := 0.0
var _pad_cooldown := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _bob_t := 0.0
var _land_dip := 0.0
var _shake := 0.0
var _anim_t := 0.0


func setup(id: int, info: Dictionary) -> void:
	peer_id = id
	is_bot = info.bot
	display_name = info.name
	color = Game.COLORS[int(info.color) % Game.COLORS.size()]
	set_multiplayer_authority(id if id > 0 else 1)
	is_local_human = not is_bot and id == Game.multiplayer.get_unique_id()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE_HEIGHT
	add_child(head)
	_build_body()
	if is_local_human:
		camera = Camera3D.new()
		camera.keep_aspect = Camera3D.KEEP_WIDTH  # FOV is horizontal, like Quake
		camera.fov = float(Game.settings.fov)
		camera.near = 0.03
		camera.far = 400.0
		head.add_child(camera)
		camera.current = true
		viewmodel_overlay = ViewmodelOverlay.new()
		viewmodel_overlay.player = self
		add_child(viewmodel_overlay)
		viewmodel = viewmodel_overlay.model
		body_root.visible = false
		name_label.visible = false
	if is_bot and multiplayer.is_server():
		brain = BotBrain.new(self)


func _build_body() -> void:
	body_root = Node3D.new()
	add_child(body_root)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.3, 0.3, 0.34)
	dark.metallic = 0.3
	dark.roughness = 0.4
	var accent := Fx.neon_material(color, 2.5)
	_part(body_root, _capsule(0.33, 1.25), Vector3(0, 0.9, 0), dark)
	_part(body_root, _boxm(Vector3(0.7, 0.09, 0.5)), Vector3(0, 1.18, 0), accent)
	_part(body_root, _boxm(Vector3(0.4, 0.36, 0.42)), Vector3(0, 1.66, 0), dark)
	_part(body_root, _boxm(Vector3(0.34, 0.09, 0.06)), Vector3(0, 1.69, -0.21), accent)
	for s in [-1.0, 1.0]:
		_part(body_root, _boxm(Vector3(0.22, 0.22, 0.32)), Vector3(0.42 * s, 1.34, 0), dark)
		_part(body_root, _boxm(Vector3(0.24, 0.05, 0.34)), Vector3(0.42 * s, 1.46, 0), accent)
	gun_pivot = Node3D.new()
	gun_pivot.position = Vector3(0.32, 1.3, -0.1)
	body_root.add_child(gun_pivot)
	_part(gun_pivot, _boxm(Vector3(0.11, 0.13, 0.65)), Vector3(0, 0, -0.3), dark)
	gun_accent = Fx.neon_material(Color.WHITE, 2.5)
	_part(gun_pivot, _boxm(Vector3(0.12, 0.03, 0.5)), Vector3(0, 0.07, -0.3), gun_accent)
	muzzle_light = OmniLight3D.new()
	muzzle_light.position = Vector3(0, 0, -0.75)
	muzzle_light.omni_range = 4.0
	muzzle_light.light_energy = 0.0
	gun_pivot.add_child(muzzle_light)
	_update_gun_color()
	name_label = Label3D.new()
	name_label.text = display_name
	name_label.modulate = color
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 40
	name_label.outline_size = 8
	name_label.pixel_size = 0.006
	name_label.position = Vector3(0, 2.2, 0)
	add_child(name_label)


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _update_gun_color() -> void:
	var w: Dictionary = Weapons.LIST[weapon]
	if gun_accent:
		gun_accent.emission = w.color
	if muzzle_light:
		muzzle_light.light_color = w.color


func teleport(pos: Vector3, new_yaw: float) -> void:
	global_position = pos
	_net_pos = pos
	velocity = Vector3.ZERO
	yaw = new_yaw
	_net_yaw = new_yaw
	pitch = 0.0
	_net_pitch = 0.0
	rotation.y = yaw
	if head:
		head.rotation.x = 0.0


# --- Input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_human or dead or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var mm := event as InputEventMouseMotion
	if mm and Time.get_ticks_msec() < Game.ignore_mouse_until:
		return
	if mm:
		var sens := float(Game.settings.sensitivity) * (0.35 if zooming and weapon == Weapons.RAIL else 1.0)
		yaw = wrapf(yaw - deg_to_rad(mm.relative.x * sens), -PI, PI)
		pitch = clampf(pitch - deg_to_rad(mm.relative.y * sens), -1.55, 1.55)
		rotation.y = yaw
		head.rotation.x = pitch
		mouse_delta += mm.relative
	elif event.is_action_pressed("weapon_next"):
		_cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		_cycle_weapon(-1)


func _read_human_input() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not captured:
		in_move = Vector2.ZERO
		in_jump = false
		in_fire = false
		zooming = false
		return
	in_move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	in_jump = Input.is_action_pressed("jump")
	in_fire = Input.is_action_pressed("fire")
	zooming = Input.is_action_pressed("zoom")
	for i in Weapons.LIST.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			select_weapon(i)
	if Input.is_action_just_pressed("weapon_last"):
		select_weapon(last_weapon)


func select_weapon(i: int) -> void:
	if i == weapon or not has_weapon(i):
		return
	last_weapon = weapon
	weapon = i
	cooldown = maxf(cooldown, 0.15)
	_update_gun_color()
	if viewmodel:
		viewmodel.show_weapon(i)
		Sfx.play_2d("switch", -8.0)


func has_weapon(i: int) -> bool:
	return i >= 0 and i < Weapons.LIST.size() and (owned_weapons & (1 << i)) != 0


func grant_weapon(i: int) -> void:
	if i < 0 or i >= Weapons.LIST.size() or has_weapon(i):
		return
	owned_weapons |= 1 << i
	add_ammo(i, Weapons.WEAPON_PICKUP_AMMO[i])
	last_weapon = weapon
	weapon = i
	cooldown = maxf(cooldown, 0.15)
	_update_gun_color()
	if viewmodel:
		viewmodel.show_weapon(i)


func add_ammo(i: int, amount: int) -> void:
	if i < 0 or i >= ammo.size():
		return
	ammo[i] = mini(ammo[i] + amount, Weapons.AMMO_CAPACITY[i])


func set_loadout(mask: int, active_weapon: int, remaining := PackedInt32Array()) -> void:
	owned_weapons = mask | (1 << Weapons.MG)
	weapon = active_weapon if has_weapon(active_weapon) else Weapons.MG
	if remaining.size() == Weapons.LIST.size():
		ammo = remaining.duplicate()
	last_weapon = Weapons.MG
	_update_gun_color()
	if viewmodel:
		viewmodel.show_weapon(weapon)


func _cycle_weapon(step: int) -> void:
	for offset in range(1, Weapons.LIST.size() + 1):
		var candidate := posmod(weapon + offset * step, Weapons.LIST.size())
		if has_weapon(candidate):
			select_weapon(candidate)
			return


# --- Simulation -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if not dead:
			if is_local_human:
				_read_human_input()
			elif brain:
				brain.think(delta)
			rotation.y = yaw
			head.rotation.x = pitch
			_move(delta)
			_weapons(delta)
		for t in Game.targets():
			_net_state.rpc_id(t, global_position, velocity, yaw, pitch, weapon, ammo, spawn_count)
	else:
		var k := 1.0 - exp(-18.0 * delta)
		global_position = global_position.lerp(_net_pos, k)
		yaw = lerp_angle(yaw, _net_yaw, k)
		pitch = lerpf(pitch, _net_pitch, k)
		rotation.y = yaw
		head.rotation.x = pitch


func _move(delta: float) -> void:
	var wish := Basis(Vector3.UP, yaw) * Vector3(in_move.x, 0, in_move.y)
	var wish_speed := minf(wish.length(), 1.0) * MAX_SPEED
	var wish_dir := wish.normalized() if wish.length() > 0.01 else Vector3.ZERO

	_air_lock = maxf(_air_lock - delta, 0.0)
	var grounded := is_on_floor() and _air_lock <= 0.0
	if grounded and in_jump:
		velocity.y = JUMP_VELOCITY
		grounded = false
		if is_local_human:
			Sfx.play_2d("jump", -12.0, randf_range(0.95, 1.05))
	if grounded:
		_apply_friction(delta)
		_accelerate(wish_dir, wish_speed, delta)
	else:
		_air_accelerate(wish_dir, wish_speed, delta)
	velocity.y -= GRAVITY * delta
	_prev_vy = velocity.y
	move_and_slide()

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _prev_vy < -6.0:
		_land_dip = clampf(-_prev_vy * 0.012, 0.0, 0.25)
		if is_local_human:
			Sfx.play_2d("land", -10.0)
	_was_on_floor = on_floor

	_pad_cooldown -= delta
	if global_position.y < -30.0 and multiplayer.is_server():
		Game.server_damage(peer_id, peer_id, 10000.0, -1)


func _apply_friction(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var drop := maxf(speed, STOP_SPEED) * FRICTION * delta
	var scale_factor := maxf(speed - drop, 0.0) / speed
	velocity.x *= scale_factor
	velocity.z *= scale_factor


func _accelerate(dir: Vector3, wish_speed: float, delta: float) -> void:
	if dir == Vector3.ZERO:
		return
	var current := Vector3(velocity.x, 0, velocity.z).dot(dir)
	var add := wish_speed - current
	if add <= 0.0:
		return
	velocity += dir * minf(GROUND_ACCEL * wish_speed * delta, add)


func _air_accelerate(dir: Vector3, wish_speed: float, delta: float) -> void:
	if dir == Vector3.ZERO:
		return
	var current := Vector3(velocity.x, 0, velocity.z).dot(dir)
	var add := minf(wish_speed, AIR_CAP) - current
	if add <= 0.0:
		return
	velocity += dir * minf(AIR_ACCEL * wish_speed * delta, add)


func can_use_jump_pad() -> bool:
	return _pad_cooldown <= 0.0 and not dead


func launch(vel: Vector3) -> void:
	velocity = vel
	_air_lock = 0.3
	_pad_cooldown = 0.6
	if is_local_human:
		Sfx.play_2d("jumppad", -4.0)
	else:
		Sfx.play_3d("jumppad", global_position, -4.0)


func apply_knockback(impulse: Vector3) -> void:
	velocity += impulse
	if impulse.y > 0.5:
		_air_lock = 0.22


# --- Weapons --------------------------------------------------------------------

func _weapons(delta: float) -> void:
	cooldown -= delta
	if in_fire and cooldown <= 0.0:
		_fire()


func _fire() -> void:
	var w: Dictionary = Weapons.LIST[weapon]
	if ammo[weapon] <= 0:
		cooldown = 0.25
		if weapon != Weapons.MG and ammo[Weapons.MG] > 0:
			select_weapon(Weapons.MG)
		return
	ammo[weapon] -= 1
	cooldown = w.cooldown
	var origin := head.global_position
	var aim := -head.global_basis.z
	var muzzle := get_muzzle_position()
	if viewmodel:
		viewmodel.kick(w.kick)
		viewmodel.flash()
		_shake = maxf(_shake, 0.05 * float(w.kick))
	if w.type == "rocket":
		Game.world.fire_rocket(peer_id, origin + aim * 0.3, aim)
		if viewmodel:
			Sfx.play_2d(w.sfx, w.vol)
		else:
			Sfx.play_3d(w.sfx, origin, w.vol)
		return

	var space := get_world_3d().direct_space_state
	var right := head.global_basis.x
	var up := head.global_basis.y
	var spread: float = w.spread
	var max_range: float = w.range
	var ends := PackedVector3Array()
	var dmg_by_victim := {}
	for i in int(w.pellets):
		var dir := aim
		# One straight pellet makes a centred close-range blast dependable.
		if spread > 0.0 and not (weapon == Weapons.SHOTGUN and i == 0):
			var a := randf() * TAU
			var r := sqrt(randf()) * spread
			dir = (aim + right * cos(a) * r + up * sin(a) * r).normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range, 3, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			ends.append(origin + dir * max_range)
			continue
		ends.append(hit.position)
		var victim := hit.collider as Player
		if victim and not victim.dead:
			dmg_by_victim[victim.peer_id] = dmg_by_victim.get(victim.peer_id, 0.0) + float(w.damage)
	for vid in dmg_by_victim:
		_deal(vid, dmg_by_victim[vid])
	Game.world.shot_fx(peer_id, weapon, muzzle, ends)


func _deal(victim_id: int, dmg: float) -> void:
	if is_bot:
		Game.server_damage(victim_id, peer_id, dmg, weapon)
	else:
		Game.report_hit(victim_id, dmg, weapon)


func get_muzzle_position() -> Vector3:
	if viewmodel:
		return viewmodel.get_muzzle()
	return gun_pivot.global_position + gun_pivot.global_basis * Vector3(0, 0, -0.7)


func flash_muzzle() -> void:
	muzzle_light.light_energy = 3.0


# --- Networking -------------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(pos: Vector3, vel: Vector3, y: float, p: float, w: int,
		remaining: PackedInt32Array, sc: int) -> void:
	if sc != spawn_count:
		return
	if pos.distance_to(global_position) > 10.0:
		global_position = pos
	_net_pos = pos
	velocity = vel
	_net_yaw = y
	_net_pitch = p
	ammo = remaining.duplicate()
	if w != weapon:
		weapon = w
		_update_gun_color()


# --- Life & death ---------------------------------------------------------------

func on_hurt(_attacker_id: int) -> void:
	if is_local_human:
		Sfx.play_2d("hurt", -5.0, randf_range(0.9, 1.1))
		Game.world.hud.flash_damage()
		_shake = maxf(_shake, 0.12)


func die() -> void:
	dead = true
	collision_layer = 0
	velocity = Vector3.ZERO
	body_root.visible = false
	name_label.visible = false
	zooming = false
	Fx.gib(Game.world.fx_root, global_position + Vector3(0, 1, 0), color)
	Sfx.play_3d("death", global_position + Vector3(0, 1, 0))
	if viewmodel:
		viewmodel.visible = false


func set_dead_silent() -> void:
	dead = true
	collision_layer = 0
	body_root.visible = false
	name_label.visible = false


func respawn(pos: Vector3, new_yaw: float) -> void:
	dead = false
	health = 100.0
	armor = 0.0
	owned_weapons = 1 << Weapons.MG
	ammo = PackedInt32Array(Weapons.START_AMMO)
	weapon = Weapons.MG
	last_weapon = Weapons.MG
	_update_gun_color()
	spawn_count += 1
	collision_layer = 2
	cooldown = 0.3
	_air_lock = 0.0
	teleport(pos, new_yaw)
	body_root.visible = not is_local_human
	name_label.visible = not is_local_human
	if viewmodel:
		viewmodel.visible = true
		viewmodel.show_weapon(weapon)
	if camera:
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
	Fx.spawn_flash(Game.world.fx_root, pos, color)
	Sfx.play_3d("respawn", pos, -4.0)


# --- Per-frame visuals ------------------------------------------------------------

func _process(delta: float) -> void:
	muzzle_light.light_energy = maxf(muzzle_light.light_energy - delta * 30.0, 0.0)
	if camera:
		_update_camera(delta)
	elif body_root.visible:
		gun_pivot.rotation.x = pitch
		var hspeed := Vector2(velocity.x, velocity.z).length()
		_anim_t += delta * hspeed * 1.3
		body_root.position.y = absf(sin(_anim_t)) * 0.05 * clampf(hspeed / MAX_SPEED, 0.0, 1.0)


func _update_camera(delta: float) -> void:
	if dead:
		var watched: Player = null
		if Game.world:
			for other in Game.world.players_root.get_children():
				var candidate := other as Player
				if candidate != null and candidate != self and not candidate.dead:
					watched = candidate
					break
		if watched:
			var look_at_point := watched.global_position + Vector3(0, 1.4, 0)
			var viewpoint := look_at_point + watched.global_basis.z * 4.0 + Vector3(0, 2.1, 0)
			camera.global_position = camera.global_position.lerp(viewpoint, minf(delta * 7.0, 1.0))
			camera.look_at(look_at_point, Vector3.UP)
		else:
			camera.global_position = camera.global_position.lerp(Vector3(0, 15, 20), minf(delta * 4.0, 1.0))
			camera.look_at(Vector3.ZERO, Vector3.UP)
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var bob := 0.0
	if is_on_floor() and hspeed > 1.0:
		_bob_t += delta * hspeed * 1.1
		bob = sin(_bob_t) * 0.035 * clampf(hspeed / MAX_SPEED, 0.0, 1.0)
	_land_dip = lerpf(_land_dip, 0.0, minf(delta * 8.0, 1.0))
	var shake := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 1.5, 0.0)
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.15
	camera.position = Vector3(0, bob - _land_dip, 0) + shake
	var base_fov := float(Game.settings.fov)
	var target_fov := base_fov + clampf((hspeed - MAX_SPEED) * 0.9, 0.0, 15.0)
	if zooming:
		target_fov = 35.0 if weapon == Weapons.RAIL else base_fov * 0.75
	camera.fov = lerpf(camera.fov, target_fov, minf(delta * 12.0, 1.0))
	camera.rotation.z = lerpf(camera.rotation.z, -in_move.x * 0.012, minf(delta * 8.0, 1.0))
	viewmodel.visible = not (zooming and weapon == Weapons.RAIL)


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)
