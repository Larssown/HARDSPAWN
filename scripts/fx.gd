class_name Fx
extends RefCounted
## Visual effects built from simple meshes, an additive glow shader and particles.

const GLOW_SHADER := preload("res://shaders/glow.gdshader")


static func glow_material(color: Color, energy := 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("alpha", 1.0)
	return m


static func neon_material(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.02)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func fade_and_free(node: Node, mat: ShaderMaterial, time: float, from := 1.0) -> void:
	var tw := node.create_tween()
	tw.tween_method(func(a: float): mat.set_shader_parameter("alpha", a), from, 0.0, time)
	tw.tween_callback(node.queue_free)


static func free_after(node: Node, time: float) -> void:
	node.get_tree().create_timer(time).timeout.connect(node.queue_free)


## Orients a unit-height cylinder so it spans from -> to.
static func beam(parent: Node, from: Vector3, to: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var dir := to - from
	var length := maxf(dir.length(), 0.01)
	var y := dir / length
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y * length, z), (from + to) * 0.5)
	return mi


static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var mat := glow_material(color, 2.5)
	var b := beam(parent, from, to, 0.018, mat)
	fade_and_free(b, mat, 0.08)


static func rail(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var core_mat := glow_material(color.lerp(Color.WHITE, 0.6), 5.0)
	var core := beam(parent, from, to, 0.03, core_mat)
	fade_and_free(core, core_mat, 0.6)
	var halo_mat := glow_material(color, 1.2)
	var halo := beam(parent, from, to, 0.12, halo_mat)
	fade_and_free(halo, halo_mat, 1.0, 0.8)
	# Spiral of glowing beads around the beam, Quake style.
	var dir := to - from
	var length := dir.length()
	if length < 0.5:
		return
	var y := dir / length
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	var count := mini(int(length / 0.2), 600)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 6
	sphere.rings = 3
	mm.mesh = sphere
	mm.instance_count = count
	for i in count:
		var t := float(i) * 0.2
		var a := t * 4.0
		var p := from + y * t + (x * cos(a) + z * sin(a)) * 0.16
		mm.set_instance_transform(i, Transform3D(Basis(), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var spiral_mat := glow_material(color, 2.0)
	mmi.material_override = spiral_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	fade_and_free(mmi, spiral_mat, 1.2)


static func _particles(parent: Node, pos: Vector3, color: Color, amount: int, speed_min: float,
		speed_max: float, life: float, size: float, gravity := -14.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size
	p.mesh = bm
	p.material_override = glow_material(color, 3.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	free_after(p, life + 0.2)


static func _flash_sphere(parent: Node, pos: Vector3, color: Color, radius: float, grow: float,
		time: float, energy := 3.0) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	var mat := glow_material(color, energy)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * grow, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(a: float): mat.set_shader_parameter("alpha", a), 1.0, 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


static func _light_flash(parent: Node, pos: Vector3, color: Color, energy: float, light_range: float, time: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time)
	tw.tween_callback(l.queue_free)


static func impact(parent: Node, pos: Vector3, color: Color) -> void:
	_flash_sphere(parent, pos, color, 0.08, 2.0, 0.12, 3.0)
	_particles(parent, pos, color, 6, 2.0, 6.0, 0.3, 0.04)


static func shotgun_blast(parent: Node, pos: Vector3, color: Color) -> void:
	_flash_sphere(parent, pos, color.lerp(Color.WHITE, 0.45), 0.12, 2.2, 0.09, 3.2)
	_light_flash(parent, pos, color, 4.0, 5.0, 0.10)
	_particles(parent, pos, color, 8, 2.0, 5.0, 0.16, 0.04, 0.0)


static func rail_impact(parent: Node, pos: Vector3, color: Color) -> void:
	_flash_sphere(parent, pos, color.lerp(Color.WHITE, 0.5), 0.16, 3.0, 0.22, 4.0)
	_light_flash(parent, pos, color, 4.0, 6.0, 0.16)
	_particles(parent, pos, color, 12, 3.0, 8.0, 0.34, 0.06)


static func explosion(parent: Node, pos: Vector3) -> void:
	_flash_sphere(parent, pos, Color(1.0, 0.85, 0.5), 0.5, 4.0, 0.18, 4.0)
	_flash_sphere(parent, pos, Color(1.0, 0.4, 0.1), 0.6, 6.5, 0.45, 2.5)
	_light_flash(parent, pos, Color(1.0, 0.55, 0.2), 10.0, 14.0, 0.45)
	_particles(parent, pos, Color(1.0, 0.6, 0.2), 28, 5.0, 14.0, 0.8, 0.09)
	# Smoke puff
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.6
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	var smoke := StandardMaterial3D.new()
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.albedo_color = Color(0.15, 0.13, 0.15, 0.55)
	mi.material_override = smoke
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 3.5, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(smoke, "albedo_color:a", 0.0, 1.1)
	tw.chain().tween_callback(mi.queue_free)


static func gib(parent: Node, pos: Vector3, color: Color) -> void:
	_flash_sphere(parent, pos, color, 0.4, 3.0, 0.25, 3.0)
	_particles(parent, pos, color, 24, 3.0, 9.0, 1.2, 0.12, -18.0)
	_particles(parent, pos, Color(0.8, 0.05, 0.05), 16, 2.0, 7.0, 1.0, 0.1, -18.0)


static func spawn_flash(parent: Node, pos: Vector3, color: Color) -> void:
	var mat := glow_material(color, 2.0)
	var b := beam(parent, pos, pos + Vector3(0, 2.2, 0), 0.7, mat)
	fade_and_free(b, mat, 0.5, 0.6)
	_particles(parent, pos + Vector3(0, 1, 0), color, 14, 1.0, 4.0, 0.6, 0.06, 2.0)
