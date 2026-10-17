class_name Arena
extends Node3D
## Ironworks: an original, enclosed industrial deathmatch map.
## Offset doors connect covered chambers, narrow corridors and three upper
## ledges. There is no long cross-map sightline or mirrored four-side layout.
## All item positions are fixed and shared by every peer.

const HALF := 32.0

var spawn_points: Array = []   # [Vector3, yaw]
var pickup_defs: Array = []    # {kind, pos, weapon?}
var jump_pads: Array = []      # {pos, vel}
var waypoints: Array[Vector3] = []
var nav_region: NavigationRegion3D

var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _steel_mat: StandardMaterial3D
var _rust_mat: StandardMaterial3D
var _grate_mat: StandardMaterial3D
var _ceiling_mat: StandardMaterial3D
var _light_mat: StandardMaterial3D
var _guide_mat: StandardMaterial3D
var _dark_metal_mat: StandardMaterial3D
var _edge_mat: StandardMaterial3D
var _warning_mat: StandardMaterial3D
var _panel_mat: StandardMaterial3D


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


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


func _surface_material(asset: String, tint: Color, metallic: float, roughness: float, tile_scale: float) -> StandardMaterial3D:
	var m := _material(tint, metallic, roughness)
	var folder := "res://assets/materials/%s/" % asset
	m.albedo_texture = load(folder + "Color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(folder + "NormalGL.jpg")
	m.normal_scale = 0.55
	m.roughness_texture = load(folder + "Roughness.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * tile_scale
	return m


func _make_materials() -> void:
	_floor_mat = _surface_material("Concrete022", Color(0.78, 0.76, 0.73), 0.03, 0.88, 0.32)
	_wall_mat = _surface_material("PaintedBricks004", Color(0.82, 0.83, 0.82), 0.04, 0.86, 0.42)
	_steel_mat = _surface_material("MetalPlates013", Color(0.76, 0.77, 0.78), 0.22, 0.70, 0.36)
	_steel_mat.roughness_texture = null
	_steel_mat.roughness = 0.78
	_steel_mat.metallic = 0.16
	_rust_mat = _material(Color(0.43, 0.26, 0.18), 0.18, 0.84)
	_grate_mat = _material(Color(0.29, 0.31, 0.32), 0.18, 0.76)
	_ceiling_mat = _surface_material("PaintedMetal012", Color(0.62, 0.63, 0.63), 0.12, 0.82, 0.36)
	_ceiling_mat.roughness_texture = null
	_ceiling_mat.roughness = 0.92
	_ceiling_mat.metallic = 0.02
	_light_mat = _material(Color(0.95, 0.79, 0.53), 0.15, 0.42)
	_light_mat.emission_enabled = true
	_light_mat.emission = Color(1.0, 0.70, 0.34)
	_light_mat.emission_energy_multiplier = 1.6
	_guide_mat = _material(Color(0.57, 0.40, 0.19), 0.10, 0.84)
	_dark_metal_mat = _surface_material("PaintedMetal012", Color(0.32, 0.34, 0.34), 0.35, 0.7, 0.5)
	_edge_mat = _material(Color(0.13, 0.16, 0.17), 0.45, 0.62)
	_warning_mat = _material(Color(0.78, 0.45, 0.14), 0.2, 0.68)
	_panel_mat = _surface_material("MetalPlates013", Color(0.72, 0.73, 0.72), 0.24, 0.76, 0.55)
	_panel_mat.roughness_texture = null


func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.055, 0.055, 0.06)
	sm.sky_horizon_color = Color(0.15, 0.12, 0.10)
	sm.ground_bottom_color = Color(0.035, 0.035, 0.04)
	sm.ground_horizon_color = Color(0.11, 0.09, 0.08)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.63, 0.60)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_bloom = 0.08
	env.fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Solid box, also used by the navmesh bake.
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


func _deco(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _wall_x(x: float, z0: float, z1: float, height := 3.5) -> void:
	_box(Vector3(x, height * 0.5, (z0 + z1) * 0.5),
		Vector3(0.9, height, z1 - z0), _wall_mat)
	_clad_wall_x(x, z0, z1, height)


func _wall_z(z: float, x0: float, x1: float, height := 3.5) -> void:
	_box(Vector3((x0 + x1) * 0.5, height * 0.5, z),
		Vector3(x1 - x0, height, 0.9), _wall_mat)
	_clad_wall_z(z, x0, x1, height)


func _clad_wall_x(x: float, z0: float, z1: float, height: float,
		face_offset := 0.51, interior_side := 0.0) -> void:
	var length := z1 - z0
	if length < 1.0:
		return
	for side in [-1.0, 1.0]:
		if interior_side != 0.0 and side != interior_side:
			continue
		var face: float = x + side * face_offset
		_deco(Vector3(face, 0.84, (z0 + z1) * 0.5), Vector3(0.09, 1.68, length - 0.08), _dark_metal_mat)
		_deco(Vector3(face + side * 0.03, 1.71, (z0 + z1) * 0.5), Vector3(0.1, 0.12, length - 0.08), _guide_mat)
		var panel_count := maxi(1, int(length / 4.0))
		var pitch := length / float(panel_count)
		for n in panel_count:
			var middle := z0 + (n + 0.5) * pitch
			_deco(Vector3(face + side * 0.04, 3.72, middle), Vector3(0.07, 2.85, pitch - 0.30), _edge_mat)
			_deco(Vector3(face + side * 0.09, 3.72, middle), Vector3(0.07, 2.58, pitch - 0.54), _panel_mat)
			if height > 8.0:
				_deco(Vector3(face + side * 0.04, 7.0, middle), Vector3(0.07, 1.72, pitch - 0.30), _edge_mat)
				_deco(Vector3(face + side * 0.09, 7.0, middle), Vector3(0.07, 1.45, pitch - 0.54), _panel_mat)
		for n in range(1, panel_count):
			var z := z0 + n * pitch
			_deco(Vector3(face + side * 0.03, height * 0.54, z), Vector3(0.12, height * 0.88, 0.18), _edge_mat)
			_deco(Vector3(face + side * 0.10, 2.18, z), Vector3(0.03, 0.09, 0.26), _warning_mat)


func _clad_wall_z(z: float, x0: float, x1: float, height: float,
		face_offset := 0.51, interior_side := 0.0) -> void:
	var length := x1 - x0
	if length < 1.0:
		return
	for side in [-1.0, 1.0]:
		if interior_side != 0.0 and side != interior_side:
			continue
		var face: float = z + side * face_offset
		_deco(Vector3((x0 + x1) * 0.5, 0.84, face), Vector3(length - 0.08, 1.68, 0.09), _dark_metal_mat)
		_deco(Vector3((x0 + x1) * 0.5, 1.71, face + side * 0.03), Vector3(length - 0.08, 0.12, 0.1), _guide_mat)
		var panel_count := maxi(1, int(length / 4.0))
		var pitch := length / float(panel_count)
		for n in panel_count:
			var middle := x0 + (n + 0.5) * pitch
			_deco(Vector3(middle, 3.72, face + side * 0.04), Vector3(pitch - 0.30, 2.85, 0.07), _edge_mat)
			_deco(Vector3(middle, 3.72, face + side * 0.09), Vector3(pitch - 0.54, 2.58, 0.07), _panel_mat)
			if height > 8.0:
				_deco(Vector3(middle, 7.0, face + side * 0.04), Vector3(pitch - 0.30, 1.72, 0.07), _edge_mat)
				_deco(Vector3(middle, 7.0, face + side * 0.09), Vector3(pitch - 0.54, 1.45, 0.07), _panel_mat)
		for n in range(1, panel_count):
			var x := x0 + n * pitch
			_deco(Vector3(x, height * 0.54, face + side * 0.03), Vector3(0.18, height * 0.88, 0.12), _edge_mat)
			_deco(Vector3(x, 2.18, face + side * 0.10), Vector3(0.26, 0.09, 0.03), _warning_mat)


## A walkable incline from low to high, with the top surface near both points.
func _ramp(low: Vector3, high: Vector3, width: float) -> void:
	var thickness := 0.55
	var dir := (high - low).normalized()
	var length := low.distance_to(high) + 0.6
	var basis := Basis.looking_at(dir, Vector3.UP)
	var center := (low + high) * 0.5 - basis.y * thickness * 0.5
	var sb := _box(Vector3.ZERO, Vector3(width, thickness, length), _steel_mat)
	sb.transform = Transform3D(basis, center)
	# Raised edging makes the route obvious without obstructing a strafe jump.
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.12, 0.1, length)
		rail.mesh = rail_mesh
		rail.material_override = _rust_mat
		rail.position = Vector3(side * (width * 0.5 - 0.12), thickness * 0.5 + 0.04, 0)
		sb.add_child(rail)


func _partition_x(x: float, openings: Array, height := 10.7) -> void:
	var from := -32.0
	for gap in openings:
		if gap[0] > from:
			_wall_x(x, from, gap[0], height)
		# Low lintels make the gaps read as doorways, not wall-height slots.
		var middle: float = (gap[0] + gap[1]) * 0.5
		var width: float = gap[1] - gap[0]
		_box(Vector3(x, (height + 5.5) * 0.5, middle),
			Vector3(0.9, height - 5.5, width), _steel_mat)
		_deco(Vector3(x, 0.025, middle), Vector3(2.5, 0.05, width - 0.8), _guide_mat)
		for edge in [gap[0], gap[1]]:
			_deco(Vector3(x, 2.72, edge), Vector3(1.18, 5.45, 0.24), _edge_mat)
			_deco(Vector3(x, 1.2, edge), Vector3(1.24, 0.14, 0.27), _warning_mat)
		for side in [-1.0, 1.0]:
			_deco(Vector3(x + side * 0.52, 5.25, middle),
				Vector3(0.10, 0.16, width - 0.8), _light_mat)
		_omni(Vector3(x, 4.7, middle), Color(1.0, 0.83, 0.62), 1.1, 9.0)
		from = gap[1]
	if from < 32.0:
		_wall_x(x, from, 32.0, height)


func _partition_z(z: float, openings: Array, height := 10.7) -> void:
	var from := -32.0
	for gap in openings:
		if gap[0] > from:
			_wall_z(z, from, gap[0], height)
		var middle: float = (gap[0] + gap[1]) * 0.5
		var width: float = gap[1] - gap[0]
		_box(Vector3(middle, (height + 5.5) * 0.5, z),
			Vector3(width, height - 5.5, 0.9), _steel_mat)
		_deco(Vector3(middle, 0.025, z), Vector3(width - 0.8, 0.05, 2.5), _guide_mat)
		for edge in [gap[0], gap[1]]:
			_deco(Vector3(edge, 2.72, z), Vector3(0.24, 5.45, 1.18), _edge_mat)
			_deco(Vector3(edge, 1.2, z), Vector3(0.27, 0.14, 1.24), _warning_mat)
		for side in [-1.0, 1.0]:
			_deco(Vector3(middle, 5.25, z + side * 0.52),
				Vector3(width - 0.8, 0.16, 0.10), _light_mat)
		_omni(Vector3(middle, 4.7, z), Color(1.0, 0.83, 0.62), 1.1, 9.0)
		from = gap[1]
	if from < 32.0:
		_wall_z(z, from, 32.0, height)


func _roof(x: float, z: float, width: float, depth: float, height: float) -> void:
	_box(Vector3(x, height, z), Vector3(width, 0.65, depth), _steel_mat)
	_deco(Vector3(x, height - 0.36, z), Vector3(width - 1.2, 0.06, depth - 1.2), _ceiling_mat)


func _geometry() -> void:
	# The nine connected chambers have different proportions and roof heights.
	# Doorways are offset rather than opposite each other, forcing turns and
	# making the main combat loops read as rooms and corridors.
	_box(Vector3(0, -0.5, 0), Vector3(68, 1, 68), _floor_mat)
	_box(Vector3(-33, 6, 0), Vector3(2, 12, 68), _wall_mat)
	_box(Vector3(33, 6, 0), Vector3(2, 12, 68), _wall_mat)
	_box(Vector3(0, 6, -33), Vector3(68, 12, 2), _wall_mat)
	_box(Vector3(0, 6, 33), Vector3(68, 12, 2), _wall_mat)
	_clad_wall_x(-33, -32, 32, 12.0, 1.06, 1.0)
	_clad_wall_x(33, -32, 32, 12.0, 1.06, -1.0)
	_clad_wall_z(-33, -32, 32, 12.0, 1.06, 1.0)
	_clad_wall_z(33, -32, 32, 12.0, 1.06, -1.0)

	_partition_x(-14.0, [[-27.0, -22.0], [-5.0, 0.0], [20.0, 25.0]])
	_partition_x(15.0, [[-26.0, -21.0], [3.0, 8.0], [21.0, 26.0]])
	_partition_z(-15.0, [[-27.0, -22.0], [-2.0, 3.0], [20.0, 25.0]])
	_partition_z(16.0, [[-26.0, -21.0], [5.0, 10.0], [22.0, 27.0]])

	# Doglegs break up the long sightlines inside the side chambers.
	_wall_z(-3.0, -20.0, -15.0, 5.5)
	_wall_x(-22.0, 4.0, 14.0, 5.5)
	_wall_z(-10.0, 20.0, 31.0, 5.5)
	_wall_x(28.0, 6.0, 14.0, 5.5)
	_wall_z(-24.0, -31.0, -23.0, 5.5)
	_wall_x(-23.0, -31.0, -24.0, 5.5)
	_wall_x(24.0, -31.0, -24.0, 5.5)
	_wall_z(25.0, 17.0, 23.0, 5.5)
	# Two broken walls give the main room a winding rocket-fight route.
	_wall_z(-5.0, -12.0, -5.0, 4.8)
	_wall_x(6.0, 6.0, 14.0, 4.8)

	# Upper ledges stay inside three different rooms. Long ramps give bots a
	# reliable route; pads give human players a fast alternative.
	_box(Vector3(-27.0, 3.75, 9.0), Vector3(8, 0.5, 10), _steel_mat)
	_ramp(Vector3(-27, 0, -13), Vector3(-27, 4, 4), 3.5)
	_box(Vector3(24.0, 3.75, -3.0), Vector3(10, 0.5, 10), _steel_mat)
	_ramp(Vector3(23, 0, 14), Vector3(23, 4, 2), 4.0)
	_box(Vector3(3.0, 3.75, -24.0), Vector3(7, 0.5, 10), _steel_mat)
	_ramp(Vector3(-12, 0, -24), Vector3(0, 4, -24), 4.0)
	# A short mezzanine overlooks the reactor room without spanning the map.
	_box(Vector3(0, 3.75, 10.0), Vector3(11, 0.5, 5), _grate_mat)
	_ramp(Vector3(-10, 0, 4), Vector3(-5, 4, 10), 3.5)
	# Light undersides keep the ground-level routes visible beneath ledges.
	_deco(Vector3(-27, 3.42, 9), Vector3(7.4, 0.06, 9.4), _ceiling_mat)
	_deco(Vector3(24, 3.42, -3), Vector3(9.4, 0.06, 9.4), _ceiling_mat)
	_deco(Vector3(3, 3.42, -24), Vector3(6.4, 0.06, 9.4), _ceiling_mat)
	_deco(Vector3(0, 3.42, 10), Vector3(10.4, 0.06, 4.4), _ceiling_mat)

	# Roofs close every room. The central ceiling is taller than the corridors.
	_roof(0.5, 0.5, 28, 30, 10.5)
	_roof(-23.0, 0.5, 18, 30, 8.2)
	_roof(23.5, 0.5, 17, 30, 9.2)
	_roof(0.5, -23.5, 28, 17, 9.0)
	_roof(0.5, 24.0, 28, 16, 7.5)
	_roof(-23.0, -23.5, 18, 17, 7.0)
	_roof(23.5, -23.5, 17, 17, 7.0)
	_roof(-23.0, 24.0, 18, 16, 7.0)
	_roof(23.5, 24.0, 17, 16, 7.0)

	# A few pieces of cover, never placed on a doorway, ramp or pickup.
	_cover(Vector3(-7, 1.1, 5), Vector3(2.4, 2.2, 2.4))
	_cover(Vector3(9, 1.1, -7), Vector3(2.4, 2.2, 2.4))
	_cover(Vector3(-27, 1.0, 22), Vector3(2.3, 2.0, 2.3))
	_cover(Vector3(27, 1.0, -22), Vector3(2.3, 2.0, 2.3))
	_cover(Vector3(2, 1.0, 25), Vector3(3.0, 2.0, 2.0))


func _cover(pos: Vector3, size: Vector3) -> void:
	_box(pos, size, _dark_metal_mat)
	var top := pos.y + size.y * 0.5
	_deco(Vector3(pos.x, top + 0.035, pos.z), Vector3(size.x + 0.12, 0.08, size.z + 0.12), _rust_mat)
	for side in [-1.0, 1.0]:
		_deco(Vector3(pos.x + side * (size.x * 0.5 + 0.035), pos.y, pos.z),
			Vector3(0.07, size.y * 0.8, size.z * 0.75), _steel_mat)
		_deco(Vector3(pos.x, pos.y, pos.z + side * (size.z * 0.5 + 0.035)),
			Vector3(size.x * 0.75, size.y * 0.8, 0.07), _steel_mat)
		_deco(Vector3(pos.x, top + 0.085, pos.z + side * (size.z * 0.5 - 0.25)),
			Vector3(size.x * 0.7, 0.02, 0.10), _warning_mat)


func _decor() -> void:
	# Door frames and roof beams make the enclosed route legible.
	for x in [-14.0, 15.0]:
		for z in [-24.0, -2.5, 6.0, 23.0]:
			_deco(Vector3(x, 6.8, z), Vector3(1.2, 0.22, 4.5), _rust_mat)
	for z in [-15.0, 16.0]:
		for x in [-24.5, 0.5, 7.5, 24.0]:
			_deco(Vector3(x, 6.8, z), Vector3(4.5, 0.22, 1.2), _rust_mat)
	for x in [-23.0, 0.0, 23.0]:
		for z in [-23.0, 0.0, 24.0]:
			var ceiling_y := 6.35 if absf(x) > 15.0 or absf(z) > 15.0 else 9.8
			_deco(Vector3(x, ceiling_y + 0.11, z), Vector3(3.75, 0.20, 0.74), _edge_mat)
			_deco(Vector3(x, ceiling_y, z), Vector3(3.4, 0.08, 0.48), _light_mat)
			for side in [-1.0, 1.0]:
				_deco(Vector3(x + side * 1.92, ceiling_y, z), Vector3(0.12, 0.18, 0.76), _warning_mat)
	# Overhead girders break the flat ceilings into readable room volumes.
	for x in [-28.0, -19.0, -8.0, 7.0, 21.0, 28.0]:
		var beam_y := 9.6 if absf(x) < 14.0 else 7.1
		_deco(Vector3(x, beam_y, 0), Vector3(0.42, 0.38, 28.0), _edge_mat)
		_deco(Vector3(x, beam_y - 0.22, 0), Vector3(0.72, 0.07, 28.0), _rust_mat)
	for z in [-27.0, -20.0, 22.0, 28.0]:
		_deco(Vector3(0, 6.55, z), Vector3(27.0, 0.34, 0.42), _edge_mat)
		_deco(Vector3(0, 6.33, z), Vector3(27.0, 0.07, 0.72), _rust_mat)
	# Exposed pipes along the long side corridors.
	for x in [-30.8, 30.8]:
		for y in [5.4, 5.9]:
			_pipe(Vector3(x, y, -13), Vector3(x, y, 13), 0.11, _rust_mat)
			for z in [-11.0, 0.0, 11.0]:
				_deco(Vector3(x, y, z), Vector3(0.34, 0.28, 0.16), _edge_mat)
	_pipe(Vector3(-13, 6.3, 30.7), Vector3(13, 6.3, 30.7), 0.13, _rust_mat)
	# A suspended power unit gives the central chamber a focal point without
	# changing the walkable floor or the rocket pickup below it.
	_deco(Vector3(0, 9.4, 0), Vector3(3.8, 0.7, 3.8), _edge_mat)
	_deco(Vector3(0, 8.75, 0), Vector3(2.8, 0.65, 2.8), _dark_metal_mat)
	_deco(Vector3(0, 8.38, 0), Vector3(2.2, 0.12, 2.2), _light_mat)
	for x in [-1.5, 1.5]:
		for z in [-1.5, 1.5]:
			_deco(Vector3(x, 8.75, z), Vector3(0.18, 1.1, 0.18), _warning_mat)
	# Wall turbines and a marked rocket-pickup bay make the central room distinct.
	_vent(Vector3(-8.2, 4.1, -14.2), 0.0)
	_vent(Vector3(8.2, 4.1, -14.2), 0.0)
	_vent(Vector3(-31.8, 4.2, 0), PI * 0.5)
	_vent(Vector3(31.8, 4.2, 0), -PI * 0.5)
	_floor_bay(Vector3(1, 0, 1))
	# Thin floor direction marks pick out the main combat route.
	for x in [-11.8, 12.8]:
		for z in [-24.0, -2.5, 23.0]:
			_deco(Vector3(x, 0.012, z), Vector3(0.14, 0.02, 2.0), _warning_mat)
	# Rust-colored edge strips on each raised ledge.
	for at in [Vector3(-27, 4.03, 4), Vector3(24, 4.03, -8), Vector3(3, 4.03, -29)]:
		_deco(at, Vector3(8.5, 0.08, 0.12), _rust_mat)


func _pipe(from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 8
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = (from + to) * 0.5
	part.basis = Basis.from_euler(Vector3(PI * 0.5, 0, 0)) if absf(to.z - from.z) > absf(to.x - from.x) else Basis.from_euler(Vector3(0, 0, PI * 0.5))
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)


func _vent(at: Vector3, yaw: float) -> void:
	var unit := Node3D.new()
	unit.position = at
	unit.rotation.y = yaw
	add_child(unit)
	var backing := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.06
	disc.bottom_radius = 1.06
	disc.height = 0.10
	disc.radial_segments = 16
	backing.mesh = disc
	backing.rotation.x = PI * 0.5
	backing.material_override = _edge_mat
	unit.add_child(backing)
	var inset := MeshInstance3D.new()
	var inner := CylinderMesh.new()
	inner.top_radius = 0.82
	inner.bottom_radius = 0.82
	inner.height = 0.11
	inner.radial_segments = 16
	inset.mesh = inner
	inset.rotation.x = PI * 0.5
	inset.position.z = 0.08
	inset.material_override = _dark_metal_mat
	unit.add_child(inset)
	for i in 8:
		var vane := MeshInstance3D.new()
		var vane_mesh := BoxMesh.new()
		vane_mesh.size = Vector3(0.16, 0.76, 0.09)
		vane.mesh = vane_mesh
		vane.material_override = _steel_mat
		vane.position = Vector3(sin(i * TAU / 8.0), cos(i * TAU / 8.0), 0) * 0.43 + Vector3(0, 0, 0.16)
		vane.rotation.z = -i * TAU / 8.0 + 0.5
		unit.add_child(vane)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.19
	hub_mesh.bottom_radius = 0.19
	hub_mesh.height = 0.14
	hub.mesh = hub_mesh
	hub.rotation.x = PI * 0.5
	hub.position.z = 0.2
	hub.material_override = _warning_mat
	unit.add_child(hub)


func _floor_bay(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.8
	disc.bottom_radius = 1.8
	disc.height = 0.025
	disc.radial_segments = 24
	ring.mesh = disc
	ring.material_override = _edge_mat
	ring.position = at + Vector3(0, 0.018, 0)
	add_child(ring)
	var center := MeshInstance3D.new()
	var inner := CylinderMesh.new()
	inner.top_radius = 1.46
	inner.bottom_radius = 1.46
	inner.height = 0.025
	inner.radial_segments = 24
	center.mesh = inner
	center.material_override = _steel_mat
	center.position = at + Vector3(0, 0.035, 0)
	add_child(center)
	for side in [-1.0, 1.0]:
		_deco(at + Vector3(side * 1.58, 0.05, 0), Vector3(0.13, 0.02, 0.55), _warning_mat)
		_deco(at + Vector3(0, 0.05, side * 1.58), Vector3(0.55, 0.02, 0.13), _warning_mat)


func _lights() -> void:
	# Local warm fixtures light the covered rooms; no sunlight enters.
	var lights := [
		[Vector3(0, 8.7, 0), 2.6, 23.0],
		[Vector3(-23, 6.5, 0), 2.0, 18.0],
		[Vector3(23, 7.3, 0), 2.0, 18.0],
		[Vector3(0, 7.3, -24), 1.9, 17.0],
		[Vector3(0, 6.1, 24), 1.9, 17.0],
		[Vector3(-23, 5.8, -24), 1.5, 15.0],
		[Vector3(23, 5.8, -24), 1.5, 15.0],
		[Vector3(-23, 5.8, 24), 1.5, 15.0],
		[Vector3(23, 5.8, 24), 1.5, 15.0],
		[Vector3(-27, 2.8, 9), 1.2, 9.0],
		[Vector3(24, 2.8, -3), 1.2, 9.0],
		[Vector3(3, 2.8, -24), 1.2, 9.0],
		[Vector3(0, 2.8, 10), 1.2, 8.0],
	]
	for i in lights.size():
		var item: Array = lights[i]
		_omni(item[0], Color(1.0, 0.84, 0.69), item[1], item[2], i == 0)


func _omni(pos: Vector3, color: Color, energy: float, light_range: float, shadows := false) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = shadows
	add_child(l)


func _launch_velocity(from: Vector3, to: Vector3, apex: float) -> Vector3:
	var gravity := Player.GRAVITY
	var top := maxf(from.y, to.y) + apex
	var vy := sqrt(2.0 * gravity * (top - from.y))
	var t := vy / gravity + sqrt(2.0 * (top - to.y) / gravity)
	return Vector3((to.x - from.x) / t, vy, (to.z - from.z) / t)


func _add_pad(pos: Vector3, target: Vector3, apex: float) -> void:
	jump_pads.append({"pos": pos, "vel": _launch_velocity(pos, target, apex)})
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.1
	mesh.bottom_radius = 1.2
	mesh.height = 0.12
	disc.mesh = mesh
	disc.material_override = _rust_mat
	disc.position = pos + Vector3(0, 0.06, 0)
	add_child(disc)
	_deco(pos + Vector3(0, 0.14, 0), Vector3(0.16, 0.03, 1.2), _light_mat)
	_deco(pos + Vector3(0, 0.14, 0), Vector3(1.2, 0.03, 0.16), _light_mat)


func _pickup(kind: String, pos: Vector3, weapon_id := -1) -> void:
	var item := {"kind": kind, "pos": pos}
	if weapon_id >= 0:
		item.weapon = weapon_id
	pickup_defs.append(item)
	waypoints.append(pos)


func _gameplay_points() -> void:
	# The gun loop crosses three distinct rooms instead of one open square.
	_add_pad(Vector3(2, 0, -17), Vector3(3, 4, -24), 1.1)
	_add_pad(Vector3(-27, 0, 15), Vector3(-27, 4, 9), 1.0)
	_add_pad(Vector3(17, 0, -12), Vector3(24, 4, -3), 1.0)

	var ground_spawns := [
		Vector3(-18, 0, 10), Vector3(-23, 0, 27),
		Vector3(8, 0, 25), Vector3(29, 0, 9),
		Vector3(22, 0, -27), Vector3(-27, 0, -20),
		Vector3(-1, 0, 3), Vector3(8, 0, -24),
	]
	var upper_spawns := [
		Vector3(5, 4, -28), Vector3(-28, 4, 13),
		Vector3(28, 4, -7),
	]
	for pos: Vector3 in ground_spawns + upper_spawns:
		spawn_points.append([pos + Vector3(0, 0.1, 0), atan2(pos.x, pos.z)])
		waypoints.append(pos)

	_pickup("weapon", Vector3(-23, 0, 23), Weapons.SHOTGUN)
	_pickup("weapon", Vector3(1, 0, 1), Weapons.ROCKET)
	_pickup("weapon", Vector3(3, 4, -24), Weapons.RAIL)
	for pos: Vector3 in [
		Vector3(-24, 0, -22), Vector3(24, 0, 22),
		Vector3(10, 0, -8), Vector3(-7, 0, 24),
	]:
		_pickup("health", pos)
	_pickup("armor", Vector3(-27, 4, 9))
	_pickup("mega", Vector3(24, 4, -3))
