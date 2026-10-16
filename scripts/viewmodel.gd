class_name Viewmodel
extends Node3D
## First-person weapon models (built from primitives) with recoil, sway, bob and muzzle flash.

const REST := Vector3(0.24, -0.22, -0.42)

var player: Player
var models: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _flash_t := 0.0
var _kick := 0.0
var _switch := 0.0
var _sway := Vector2.ZERO
var _bob_t := 0.0
var _rail_coils: Array[MeshInstance3D] = []


func _ready() -> void:
	position = REST
	scale = Vector3.ONE * 0.8
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.42, 0.44, 0.48)
	metal.metallic = 0.3
	metal.roughness = 0.45
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.12, 0.12, 0.13)
	grip.roughness = 0.8
	for i in Weapons.LIST.size():
		var w: Dictionary = Weapons.LIST[i]
		var accent := Fx.neon_material(w.color, 0.8)
		var root := Node3D.new()
		add_child(root)
		var muzzle := Node3D.new()
		root.add_child(muzzle)
		match i:
			Weapons.MG:
				_box(root, Vector3(0.08, 0.1, 0.42), Vector3(0, 0, 0), metal)
				_cyl(root, 0.022, 0.32, Vector3(0, 0.015, -0.36), metal)
				_box(root, Vector3(0.05, 0.14, 0.08), Vector3(0, -0.1, -0.05), grip)
				_box(root, Vector3(0.05, 0.12, 0.06), Vector3(0, -0.09, 0.12), grip)
				_box(root, Vector3(0.085, 0.015, 0.3), Vector3(0, 0.055, -0.02), accent)
				muzzle.position = Vector3(0, 0.015, -0.54)
			Weapons.SHOTGUN:
				_box(root, Vector3(0.12, 0.11, 0.38), Vector3(0, 0, 0.02), metal)
				_cyl(root, 0.03, 0.4, Vector3(-0.03, 0.02, -0.33), metal)
				_cyl(root, 0.03, 0.4, Vector3(0.03, 0.02, -0.33), metal)
				_box(root, Vector3(0.1, 0.06, 0.18), Vector3(0, -0.05, -0.22), grip)
				_box(root, Vector3(0.06, 0.14, 0.08), Vector3(0, -0.1, 0.12), grip)
				_box(root, Vector3(0.125, 0.02, 0.2), Vector3(0, 0.065, 0.05), accent)
				muzzle.position = Vector3(0, 0.02, -0.55)
			Weapons.ROCKET:
				_cyl(root, 0.075, 0.62, Vector3(0, 0.02, -0.12), metal)
				_cyl(root, 0.085, 0.06, Vector3(0, 0.02, -0.42), accent)
				_cyl(root, 0.08, 0.04, Vector3(0, 0.02, 0.17), accent)
				_box(root, Vector3(0.05, 0.14, 0.08), Vector3(0, -0.12, 0.02), grip)
				_box(root, Vector3(0.04, 0.06, 0.12), Vector3(0, 0.11, -0.05), metal)
				muzzle.position = Vector3(0, 0.02, -0.46)
			Weapons.RAIL:
				_box(root, Vector3(0.07, 0.09, 0.62), Vector3(0, 0, -0.08), metal)
				for z in [-0.3, -0.2, -0.1, 0.0]:
					_rail_coils.append(_cyl(root, 0.055, 0.03, Vector3(0, 0.0, z), accent))
				_box(root, Vector3(0.015, 0.04, 0.16), Vector3(-0.03, 0.03, -0.45), metal)
				_box(root, Vector3(0.015, 0.04, 0.16), Vector3(0.03, 0.03, -0.45), metal)
				_box(root, Vector3(0.05, 0.14, 0.08), Vector3(0, -0.1, 0.1), grip)
				muzzle.position = Vector3(0, 0.03, -0.52)
		models.append(root)
		muzzles.append(muzzle)

	_flash_light = OmniLight3D.new()
	_flash_light.omni_range = 5.0
	_flash_light.light_energy = 0.0
	add_child(_flash_light)
	_flash_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	_flash_mesh.mesh = sm
	_flash_mesh.visible = false
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash_mesh)
	show_weapon(player.weapon)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func show_weapon(i: int) -> void:
	for j in models.size():
		models[j].visible = j == i
	_switch = 1.0
	var w: Dictionary = Weapons.LIST[i]
	_flash_light.light_color = w.color
	_flash_mesh.material_override = Fx.glow_material(w.color, 2.0)


func kick(amount: float) -> void:
	_kick = minf(_kick + amount, 1.6)


func flash() -> void:
	_flash_t = 0.085 if player.weapon == Weapons.SHOTGUN else 0.07 if player.weapon == Weapons.RAIL else 0.05
	_flash_light.light_energy = 6.0 if player.weapon == Weapons.SHOTGUN else 5.0


func get_muzzle() -> Vector3:
	return muzzles[player.weapon].global_position


func _process(delta: float) -> void:
	_kick = lerpf(_kick, 0.0, minf(delta * 9.0, 1.0))
	_switch = maxf(_switch - delta * 7.0, 0.0)

	var target_sway := Vector2(-player.mouse_delta.x, player.mouse_delta.y) * 0.0006
	player.mouse_delta = Vector2.ZERO
	target_sway = target_sway.limit_length(0.06)
	_sway = _sway.lerp(target_sway, minf(delta * 10.0, 1.0))

	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	var bob := Vector2.ZERO
	if player.is_on_floor() and hspeed > 1.0:
		_bob_t += delta * hspeed * 1.1
		var amt := clampf(hspeed / Player.MAX_SPEED, 0.0, 1.0)
		bob = Vector2(cos(_bob_t * 0.5) * 0.012, absf(sin(_bob_t * 0.5)) * -0.014) * amt
	var air_offset := clampf(-player.velocity.y * 0.003, -0.04, 0.04) if not player.is_on_floor() else 0.0

	position = REST + Vector3(_sway.x + bob.x, _sway.y + bob.y - _switch * 0.25 + air_offset, _kick * 0.1)
	rotation = Vector3(_kick * 0.22 - _switch * 0.6, _sway.x * 2.0, 0)

	# Railgun coils glow brighter as it recharges.
	if player.weapon == Weapons.RAIL:
		var ready := 1.0 - clampf(player.cooldown / float(Weapons.LIST[Weapons.RAIL].cooldown), 0.0, 1.0)
		for c in _rail_coils:
			(c.material_override as StandardMaterial3D).emission_energy_multiplier = 0.3 + ready * 3.5

	if _flash_t > 0.0:
		_flash_t -= delta
		_flash_mesh.visible = true
		_flash_mesh.position = muzzles[player.weapon].position + models[player.weapon].position
		_flash_mesh.scale = Vector3.ONE * randf_range(0.5, 1.0)
	else:
		_flash_mesh.visible = false
	_flash_light.position = _flash_mesh.position
	_flash_light.light_energy = maxf(_flash_light.light_energy - delta * 40.0, 0.0)
