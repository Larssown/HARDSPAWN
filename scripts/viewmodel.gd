class_name Viewmodel
extends Node3D
## First-person imported weapon models with recoil, sway, bob and muzzle flash.

const REST := Vector3(0.32, -0.40, -0.42)
const MUZZLE_TIP_X := [0.95, 0.62, 1.31, 1.59]

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
func _ready() -> void:
	position = REST
	scale = Vector3.ONE * 0.8
	for i in Weapons.LIST.size():
		var root := Node3D.new()
		add_child(root)
		var visual := WeaponVisual.create(i)
		visual.position = Vector3(0, -0.01, -0.20)
		# The supplied guns point along +X. Angle them into the screen and lift
		# the muzzle so the stock sits low right, like a classic arena FPS view.
		visual.basis = Basis(Vector3.UP, deg_to_rad(110.0)) * Basis(Vector3.BACK, deg_to_rad(13.0))
		visual.scale = Vector3.ONE * 0.48
		root.add_child(visual)
		var muzzle := Node3D.new()
		muzzle.position = Vector3(MUZZLE_TIP_X[i], 0.03, 0)
		visual.add_child(muzzle)
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

	if _flash_t > 0.0:
		_flash_t -= delta
		_flash_mesh.visible = true
		_flash_mesh.position = to_local(muzzles[player.weapon].global_position)
		_flash_mesh.scale = Vector3.ONE * randf_range(0.5, 1.0)
	else:
		_flash_mesh.visible = false
	_flash_light.position = _flash_mesh.position
	_flash_light.light_energy = maxf(_flash_light.light_energy - delta * 40.0, 0.0)
