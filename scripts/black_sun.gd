class_name BlackSun
extends MeshInstance3D
## One billboarded quad, one material and a slow, subtle pulse.

const ECLIPSE_IMAGE := preload("res://assets/sky/black_sun.jpg")
const ECLIPSE_SHADER := preload("res://shaders/black_sun.gdshader")

@export var diameter := 180.0
@export var pulse_period := 7.5
@export var scale_pulse := 0.012
@export var emission_base := 1.25
@export var emission_pulse := 0.08

var _elapsed := 0.0
var _material: ShaderMaterial


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * diameter
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = ECLIPSE_SHADER
	_material.render_priority = 100
	_material.set_shader_parameter("eclipse_texture", ECLIPSE_IMAGE)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_update_visual(0.0)


func _process(delta: float) -> void:
	var period := maxf(pulse_period, 0.01)
	_elapsed = fmod(_elapsed + delta, period)
	_update_visual(sin(_elapsed * TAU / period))


func _update_visual(wave: float) -> void:
	scale = Vector3.ONE * (1.0 + scale_pulse * wave)
	_material.set_shader_parameter("emission_energy", emission_base + emission_pulse * wave)
	var camera := get_viewport().get_camera_3d()
	if camera:
		look_at(camera.global_position, Vector3.UP)
