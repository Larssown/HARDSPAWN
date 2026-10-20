class_name DustField
extends Node3D
## Floating dust around the active camera: tiny sunlit motes up close and a few
## larger, softer specks, drifting slowly. Follows the camera so it is always present
## but only costs one small particle volume.

const AREA := Vector3(26.0, 12.0, 26.0)

var _motes: GPUParticles3D
var _specks: GPUParticles3D


func _ready() -> void:
	_motes = _make(900, 9.0, 0.06, Color(0.46, 0.43, 0.38, 0.7), 0.25)
	_specks = _make(120, 12.0, 0.14, Color(0.6, 0.56, 0.5, 0.3), 0.15)


func _make(amount: int, life: float, size: float, color: Color, speed: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.visibility_aabb = AABB(-AREA, AREA * 2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = AREA * 0.5
	pm.direction = Vector3(0.3, 0.15, 0.1)
	pm.spread = 180.0
	pm.gravity = Vector3(0.05, -0.02, 0.03)
	pm.initial_velocity_min = speed * 0.3
	pm.initial_velocity_max = speed
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_speed_random = 0.2
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(color.r, color.g, color.b, 0.0))
	fade.add_point(0.2, color)
	fade.add_point(0.8, color)
	fade.set_color(fade.get_point_count() - 1, Color(color.r, color.g, color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position
