class_name WeaponSprite
extends TextureRect
## Local first-person sprite. The black JPEG pixels contribute nothing in ADD
## blend mode; only its cyan/orange light is drawn over the 3D arena.

const MACHINEGUN_IMAGE := preload("res://assets/sprites/holo_machinegun.jpg")

var player: Player
var _look_delta := Vector2.ZERO
var _sway := Vector2.ZERO
var _recoil := Vector2.ZERO
var _bob_time := 0.0
var _switch := 0.0
var _flash := 0.0


func _ready() -> void:
	name = "WeaponSprite"
	texture = MACHINEGUN_IMAGE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	resized.connect(_update_pivot)
	_update_pivot()


func show_weapon(weapon_id: int) -> void:
	visible = weapon_id == Weapons.MG
	if visible:
		_recoil = Vector2.ZERO
		_switch = 1.0


func add_look_delta(motion: Vector2) -> void:
	_look_delta += motion


func kick(amount: float) -> void:
	_recoil = (_recoil + Vector2(18.0, 27.0) * amount).limit_length(48.0)


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	if not visible:
		_look_delta = Vector2.ZERO
		return
	var smooth := 1.0 - exp(-12.0 * delta)
	var target_sway := Vector2(-_look_delta.x * 0.16, _look_delta.y * 0.12).limit_length(20.0)
	_look_delta = Vector2.ZERO
	_sway = _sway.lerp(target_sway, smooth)
	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-17.0 * delta))
	_switch = maxf(_switch - delta * 6.5, 0.0)
	_flash = maxf(_flash - delta * 16.0, 0.0)

	var bob := Vector2.ZERO
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor() and speed > 1.0:
		_bob_time += delta * speed * 0.85
		var strength := clampf(speed / Player.MAX_SPEED, 0.0, 1.0)
		bob = Vector2(sin(_bob_time) * 6.0, sin(_bob_time * 2.0) * 3.5) * strength
	position = bob + _sway + _recoil + Vector2(0, _switch * 55.0)
	rotation = clampf(-_sway.x * 0.0010 - _recoil.y * 0.0008, -0.035, 0.035)
	modulate = Color(1.0 + _flash * 0.25, 1.0 + _flash * 0.18, 1.0 + _flash * 0.10)


func _update_pivot() -> void:
	pivot_offset = size * Vector2(0.82, 0.78)
