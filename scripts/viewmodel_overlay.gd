class_name ViewmodelOverlay
extends CanvasLayer
## Draws the first-person gun over the arena so nearby walls cannot cut it off.

var player: Player
var model: Viewmodel
var weapon_camera: Camera3D
var _viewport: SubViewport
var _weapon_image: TextureRect
var _sprite: WeaponSprite


func _ready() -> void:
	layer = 5  # The HUD uses layer 10 and stays above the gun.
	_viewport = SubViewport.new()
	_viewport.name = "WeaponViewport"
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_resize()
	get_viewport().size_changed.connect(_resize)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.92, 0.91, 0.88)
	environment.ambient_light_energy = 1.3
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, -30, 0)
	key_light.light_energy = 1.2
	_viewport.add_child(key_light)

	weapon_camera = Camera3D.new()
	weapon_camera.name = "WeaponCamera"
	weapon_camera.keep_aspect = Camera3D.KEEP_WIDTH
	weapon_camera.fov = player.camera.fov
	weapon_camera.near = 0.03
	weapon_camera.current = true
	_viewport.add_child(weapon_camera)

	model = Viewmodel.new()
	model.player = player
	weapon_camera.add_child(model)

	_weapon_image = TextureRect.new()
	_weapon_image.name = "WeaponImage"
	_weapon_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_weapon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_image.stretch_mode = TextureRect.STRETCH_SCALE
	_weapon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_image.texture = _viewport.get_texture()
	add_child(_weapon_image)
	var sprite_root := Control.new()
	sprite_root.name = "SpriteRoot"
	sprite_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sprite_root)
	_sprite = WeaponSprite.new()
	_sprite.player = player
	sprite_root.add_child(_sprite)
	show_weapon(player.weapon)


func show_weapon(weapon_id: int) -> void:
	model.show_weapon(weapon_id)
	_sprite.show_weapon(weapon_id)
	_weapon_image.visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	model.models[weapon_id].visible = false


func kick(amount: float) -> void:
	_sprite.kick(amount)


func flash() -> void:
	_sprite.flash()


func _process(_delta: float) -> void:
	weapon_camera.fov = player.camera.fov
	weapon_camera.rotation.z = player.camera.rotation.z
	var look_delta := player.mouse_delta
	player.mouse_delta = Vector2.ZERO
	model.add_look_delta(look_delta)
	_sprite.add_look_delta(look_delta)


func _resize() -> void:
	_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
