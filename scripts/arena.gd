class_name Arena
extends Node3D
## Builds the arena "Neon Foundry": geometry, lights, environment, jump pads,
## spawn points and pickup spots. Everything is made of boxes, so no 3D modelling needed.
##
## Layout (64 x 64 m): a raised centre platform reached by jump pads, four corner
## towers with ramps, walkways along the east/west walls, and cover on the floor.

const GRID_SHADER := preload("res://shaders/grid.gdshader")
const HALF := 32.0

var spawn_points: Array = []   # [Vector3, yaw]
var pickup_defs: Array = []    # {kind, pos}
var jump_pads: Array = []      # {pos, vel}
var waypoints: Array[Vector3] = []
var nav_region: NavigationRegion3D

var _mat_floor: ShaderMaterial
var _mat_wall: ShaderMaterial
var _mat_struct: ShaderMaterial
var _mat_metal: StandardMaterial3D


func build() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Nav"
	add_child(nav_region)
	_make_materials()
	_environment()
	_geometry()
	_decor()
	_lights()
	_gameplay_points()


func bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nav_region.navigation_mesh = nm
	nav_region.bake_navigation_mesh(false)


func _grid(base: Color, line: Color, size: float, width: float, emission: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRID_SHADER
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("line_color", line)
	m.set_shader_parameter("grid_size", size)
	m.set_shader_parameter("line_width", width)
	m.set_shader_parameter("line_emission", emission)
	return m


func _make_materials() -> void:
	_mat_floor = _grid(Color(0.36, 0.38, 0.43), Color(0.1, 0.6, 1.0), 2.0, 0.015, 1.1)
	_mat_wall = _grid(Color(0.4, 0.36, 0.46), Color(0.8, 0.2, 0.9), 4.0, 0.02, 0.6)
	_mat_struct = _grid(Color(0.55, 0.53, 0.56), Color(1.0, 0.5, 0.15), 1.0, 0.012, 0.8)
	_mat_metal = StandardMaterial3D.new()
	_mat_metal.albedo_color = Color(0.32, 0.33, 0.37)
	_mat_metal.metallic = 0.35
	_mat_metal.roughness = 0.4


func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.02, 0.02, 0.06)
	sm.sky_horizon_color = Color(0.2, 0.06, 0.25)
	sm.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sm.ground_horizon_color = Color(0.2, 0.06, 0.25)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.65)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.03
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.08, 0.2)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Solid box with collision (part of the navmesh).
func _box(pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation = rot
	nav_region.add_child(sb)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	sb.add_child(mi)
	return sb


## Visual-only box (no collision).
func _deco(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Ramp whose top surface runs from `low` to `high`.
func _ramp(low: Vector3, high: Vector3, width: float) -> void:
	var thickness := 0.6
	var dir := (high - low).normalized()
	var length := low.distance_to(high) + 0.6
	var b := Basis.looking_at(dir, Vector3.UP)
	var center := (low + high) * 0.5 - b.y * thickness * 0.5
	var sb := _box(Vector3.ZERO, Vector3(width, thickness, length), _mat_struct)
	sb.transform = Transform3D(b, center)


func _geometry() -> void:
	# Floor and outer walls
	_box(Vector3(0, -0.5, 0), Vector3(HALF * 2 + 4, 1, HALF * 2 + 4), _mat_floor)
	for s in [-1.0, 1.0]:
		_box(Vector3((HALF + 1) * s, 8, 0), Vector3(2, 16, HALF * 2 + 4), _mat_wall)
		_box(Vector3(0, 8, (HALF + 1) * s), Vector3(HALF * 2 + 4, 16, 2), _mat_wall)

	# Centre platform (top at y = 4), reached by jump pads
	_box(Vector3(0, 2, 0), Vector3(10, 4, 10), _mat_struct)

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			# Corner tower (top at y = 6) with a ramp down towards the middle
			_box(Vector3(27 * sx, 3, 27 * sz), Vector3(10, 6, 10), _mat_struct)
			_ramp(Vector3(9 * sx, 0, 27 * sz), Vector3(22 * sx, 6, 27 * sz), 4.0)
			# Pillars
			_box(Vector3(12 * sx, 4, 13 * sz), Vector3(1.6, 8, 1.6), _mat_wall)
			# Crates
			_box(Vector3(6 * sx, 0.6, 17 * sz), Vector3(1.2, 1.2, 1.2), _mat_struct)
			_box(Vector3(17 * sx, 0.6, 6 * sz), Vector3(1.2, 1.2, 1.2), _mat_struct)

	for s in [-1.0, 1.0]:
		# East/west walkways between towers (top at y = 6) with supports and a low rail
		_box(Vector3(30 * s, 5.75, 0), Vector3(4, 0.5, 44), _mat_struct)
		_box(Vector3(28.1 * s, 6.4, 0), Vector3(0.2, 0.8, 44), _mat_metal)
		for z in [-11.0, 0.0, 11.0]:
			_box(Vector3(30 * s, 2.75, z), Vector3(1, 5.5, 1), _mat_metal)
		# Floor cover walls
		_box(Vector3(16 * s, 1.5, 0), Vector3(2, 3, 7), _mat_wall)
		_box(Vector3(0, 1.5, 17 * s), Vector3(7, 3, 2), _mat_wall)


func _decor() -> void:
	var cyan := Fx.neon_material(Color(0.1, 0.8, 1.0), 4.0)
	var magenta := Fx.neon_material(Color(1.0, 0.15, 0.7), 4.0)
	var orange := Fx.neon_material(Color(1.0, 0.45, 0.1), 4.0)
	var inner := HALF - 0.06
	# Horizontal light strips on the outer walls
	for s in [-1.0, 1.0]:
		_deco(Vector3(inner * s, 2.5, 0), Vector3(0.12, 0.15, HALF * 2), cyan)
		_deco(Vector3(0, 2.5, inner * s), Vector3(HALF * 2, 0.15, 0.12), cyan)
		_deco(Vector3(inner * s, 11.0, 0), Vector3(0.12, 0.25, HALF * 2), magenta)
		_deco(Vector3(0, 11.0, inner * s), Vector3(HALF * 2, 0.25, 0.12), magenta)
		# Vertical strips
		for i in range(-3, 4):
			var t := i * 8.0
			_deco(Vector3(inner * s, 8, t), Vector3(0.12, 16, 0.2), magenta if i % 2 == 0 else cyan)
			_deco(Vector3(t, 8, inner * s), Vector3(0.2, 16, 0.12), magenta if i % 2 == 0 else cyan)
	# Centre platform edges
	for s in [-1.0, 1.0]:
		_deco(Vector3(5.02 * s, 3.9, 0), Vector3(0.06, 0.12, 10.1), cyan)
		_deco(Vector3(0, 3.9, 5.02 * s), Vector3(10.1, 0.12, 0.06), cyan)
		_deco(Vector3(5.02 * s, 0.6, 0), Vector3(0.06, 0.1, 10.1), cyan)
		_deco(Vector3(0, 0.6, 5.02 * s), Vector3(10.1, 0.1, 0.06), cyan)
	# Tower edges
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_deco(Vector3(21.97 * sx, 5.9, 27 * sz), Vector3(0.06, 0.12, 10), orange)
			_deco(Vector3(27 * sx, 5.9, 21.97 * sz), Vector3(10, 0.12, 0.06), orange)
	# Walkway edges
	for s in [-1.0, 1.0]:
		_deco(Vector3(27.97 * s, 5.55, 0), Vector3(0.06, 0.1, 44), magenta)


func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color(0.6, 0.65, 1.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	_omni(Vector3(0, 9, 0), Color(0.2, 0.8, 1.0), 3.0, 16.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_omni(Vector3(27 * sx, 10, 27 * sz), Color(1.0, 0.5, 0.2), 2.5, 16.0)
			_omni(Vector3(14 * sx, 5, 14 * sz), Color(0.6, 0.3, 1.0), 1.4, 13.0)
	for s in [-1.0, 1.0]:
		_omni(Vector3(25 * s, 8, 0), Color(1.0, 0.2, 0.7), 2.0, 14.0)
		_omni(Vector3(0, 6, 25 * s), Color(0.2, 0.5, 1.0), 2.0, 14.0)


func _omni(pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	add_child(l)


func _launch_velocity(from: Vector3, to: Vector3, apex: float) -> Vector3:
	var g := Player.GRAVITY
	var top := maxf(from.y, to.y) + apex
	var vy := sqrt(2.0 * g * (top - from.y))
	var t := vy / g + sqrt(2.0 * (top - to.y) / g)
	return Vector3((to.x - from.x) / t, vy, (to.z - from.z) / t)


func _add_pad(pos: Vector3, target: Vector3, apex: float) -> void:
	jump_pads.append({"pos": pos, "vel": _launch_velocity(pos, target, apex)})
	var green := Color(0.3, 1.0, 0.4)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.2
	cm.height = 0.12
	disc.mesh = cm
	disc.material_override = Fx.neon_material(green, 1.6)
	disc.position = pos + Vector3(0, 0.06, 0)
	add_child(disc)
	var col := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.7
	cc.bottom_radius = 1.0
	cc.height = 2.5
	cc.cap_top = false
	cc.cap_bottom = false
	col.mesh = cc
	var gm := Fx.glow_material(green, 0.035)
	col.material_override = gm
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	col.position = pos + Vector3(0, 1.25, 0)
	add_child(col)
	var l := OmniLight3D.new()
	l.light_color = green
	l.light_energy = 1.5
	l.omni_range = 4.0
	l.position = pos + Vector3(0, 0.8, 0)
	add_child(l)


func _gameplay_points() -> void:
	# Jump pads: four around the centre, one on each tower roof (long flight to the middle)
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		_add_pad(d * 8.0, d * 2.0 + Vector3(0, 4, 0), 2.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_pad(Vector3(25.5 * sx, 6, 25.5 * sz), Vector3(2.5 * sx, 4, 2.5 * sz), 5.0)

	var spots := [
		Vector3(24, 0, 12), Vector3(24, 0, -12), Vector3(-24, 0, 12), Vector3(-24, 0, -12),
		Vector3(6, 0, 24), Vector3(-6, 0, 24), Vector3(6, 0, -24), Vector3(-6, 0, -24),
		Vector3(29, 6, 29), Vector3(-29, 6, 29), Vector3(29, 6, -29), Vector3(-29, 6, -29),
		Vector3(30, 6, 10), Vector3(-30, 6, -10),
	]
	for s: Vector3 in spots:
		spawn_points.append([s + Vector3(0, 0.1, 0), atan2(s.x, s.z)])
		waypoints.append(s)

	for p in [Vector3(16, 0, 16), Vector3(-16, 0, 16), Vector3(16, 0, -16), Vector3(-16, 0, -16),
			Vector3(0, 0, 27), Vector3(0, 0, -27), Vector3(26, 0, 0), Vector3(-26, 0, 0)]:
		pickup_defs.append({"kind": "health", "pos": p})
		waypoints.append(p)
	pickup_defs.append({"kind": "armor", "pos": Vector3(30, 6, 0)})
	pickup_defs.append({"kind": "armor", "pos": Vector3(-30, 6, 0)})
	pickup_defs.append({"kind": "mega", "pos": Vector3(0, 4, 0)})
	waypoints.append(Vector3(30, 6, 0))
	waypoints.append(Vector3(-30, 6, 0))
	waypoints.append(Vector3(10, 0, 0))
	waypoints.append(Vector3(-10, 0, 0))
