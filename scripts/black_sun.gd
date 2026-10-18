class_name BlackSun
extends Node3D
## A geometric eclipse: a shadow-casting moon, an emissive sun and backlight.

@export var moon_radius := 55.0
@export var corona_radius := 72.0
@export var corona_offset := 25.0
@export var pulse_period := 7.5
@export var pulse_amount := 0.025

var _elapsed := 0.0
var _corona: MeshInstance3D
var _corona_material: StandardMaterial3D


func _ready() -> void:
	var moon := MeshInstance3D.new()
	moon.name = "BlackMoon"
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = moon_radius
	moon_mesh.height = moon_radius * 2.0
	moon_mesh.radial_segments = 32
	moon_mesh.rings = 16
	moon.mesh = moon_mesh
	var moon_material := StandardMaterial3D.new()
	moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_material.albedo_color = Color(0.001, 0.001, 0.001)
	moon_material.roughness = 1.0
	# Keep the disk black; it still has real depth and casts volumetric shadows.
	moon_material.disable_fog = true
	moon.material_override = moon_material
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	moon.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(moon)

	_corona = MeshInstance3D.new()
	_corona.name = "CoronaSphere"
	_corona.position = Vector3(0.0, 30.0, -corona_offset)
	var corona_mesh := SphereMesh.new()
	corona_mesh.radius = corona_radius
	corona_mesh.height = corona_radius * 2.0
	corona_mesh.radial_segments = 32
	corona_mesh.rings = 16
	_corona.mesh = corona_mesh
	_corona_material = StandardMaterial3D.new()
	_corona_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_corona_material.albedo_color = Color(1.0, 0.54, 0.24)
	_corona_material.emission_enabled = true
	_corona_material.emission = Color(1.0, 0.52, 0.2)
	_corona_material.emission_energy_multiplier = 10.0
	_corona.material_override = _corona_material
	_corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corona.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_corona)

	var backlight := DirectionalLight3D.new()
	backlight.name = "EclipseBacklight"
	# Position documents the alignment; a DirectionalLight only uses rotation.
	backlight.position = Vector3(0.0, 55.0, -85.0)
	backlight.light_color = Color(1.0, 0.75, 0.55)
	backlight.light_energy = 0.9
	backlight.light_volumetric_fog_energy = 6.0
	backlight.shadow_enabled = true
	backlight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	backlight.directional_shadow_max_distance = 320.0
	backlight.shadow_blur = 2.0
	add_child(backlight)
	backlight.look_at(to_global(Vector3(0.0, -105.0, 225.0)), Vector3.UP)


func _process(delta: float) -> void:
	var period := maxf(pulse_period, 0.01)
	_elapsed = fmod(_elapsed + delta, period)
	var pulse := sin(_elapsed * TAU / period)
	_corona.scale = Vector3.ONE * (1.0 + pulse_amount * pulse)
	_corona_material.emission_energy_multiplier = 10.0 + 0.55 * pulse
