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
var _light_mat: StandardMaterial3D


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


func _make_materials() -> void:
	_floor_mat = _material(Color(0.24, 0.235, 0.22), 0.05, 0.9)
	_wall_mat = _material(Color(0.32, 0.30, 0.28), 0.08, 0.86)
	_steel_mat = _material(Color(0.20, 0.22, 0.23), 0.62, 0.6)
	_rust_mat = _material(Color(0.35, 0.19, 0.12), 0.32, 0.82)
	_grate_mat = _material(Color(0.12, 0.14, 0.15), 0.72, 0.55)
	_light_mat = _material(Color(0.72, 0.45, 0.22), 0.25, 0.45)
	_light_mat.emission_enabled = true
	_light_mat.emission = Color(0.55, 0.27, 0.08)
	_light_mat.emission_energy_multiplier = 0.7


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
	env.ambient_light_color = Color(0.40, 0.39, 0.37)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.13, 0.11, 0.10)
	env.fog_density = 0.003
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


func _wall_z(z: float, x0: float, x1: float, height := 3.5) -> void:
	_box(Vector3((x0 + x1) * 0.5, height * 0.5, z),
		Vector3(x1 - x0, height, 0.9), _wall_mat)


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
		_box(Vector3(x, (height + 5.5) * 0.5, (gap[0] + gap[1]) * 0.5),
			Vector3(0.9, height - 5.5, gap[1] - gap[0]), _steel_mat)
		from = gap[1]
	if from < 32.0:
		_wall_x(x, from, 32.0, height)


func _partition_z(z: float, openings: Array, height := 10.7) -> void:
	var from := -32.0
	for gap in openings:
		if gap[0] > from:
			_wall_z(z, from, gap[0], height)
		_box(Vector3((gap[0] + gap[1]) * 0.5, (height + 5.5) * 0.5, z),
			Vector3(gap[1] - gap[0], height - 5.5, 0.9), _steel_mat)
		from = gap[1]
	if from < 32.0:
		_wall_z(z, from, 32.0, height)


func _roof(x: float, z: float, width: float, depth: float, height: float) -> void:
	_box(Vector3(x, height, z), Vector3(width, 0.65, depth), _steel_mat)
	_deco(Vector3(x, height - 0.36, z), Vector3(width - 1.2, 0.06, depth - 1.2), _grate_mat)


func _geometry() -> void:
	# The nine connected chambers have different proportions and roof heights.
	# Doorways are offset rather than opposite each other, forcing turns and
	# making the main combat loops read as rooms and corridors.
	_box(Vector3(0, -0.5, 0), Vector3(68, 1, 68), _floor_mat)
	_box(Vector3(-33, 6, 0), Vector3(2, 12, 68), _wall_mat)
	_box(Vector3(33, 6, 0), Vector3(2, 12, 68), _wall_mat)
	_box(Vector3(0, 6, -33), Vector3(68, 12, 2), _wall_mat)
	_box(Vector3(0, 6, 33), Vector3(68, 12, 2), _wall_mat)

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
	_box(Vector3(-7, 1.1, 5), Vector3(2.4, 2.2, 2.4), _rust_mat)
	_box(Vector3(9, 1.1, -7), Vector3(2.4, 2.2, 2.4), _rust_mat)
	_box(Vector3(-27, 1.0, 22), Vector3(2.3, 2.0, 2.3), _steel_mat)
	_box(Vector3(27, 1.0, -22), Vector3(2.3, 2.0, 2.3), _steel_mat)
	_box(Vector3(2, 1.0, 25), Vector3(3.0, 2.0, 2.0), _rust_mat)


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
			_deco(Vector3(x, 6.35 if absf(x) > 15.0 or absf(z) > 15.0 else 9.8, z),
				Vector3(3.4, 0.08, 0.48), _light_mat)
	# Exposed pipes along the long side corridors.
	_deco(Vector3(-30.8, 5.7, 0), Vector3(0.32, 0.32, 27), _rust_mat)
	_deco(Vector3(30.8, 6.1, 0), Vector3(0.32, 0.32, 27), _rust_mat)
	_deco(Vector3(0, 6.5, 30.7), Vector3(26, 0.28, 0.28), _rust_mat)
	# Rust-colored edge strips on each raised ledge.
	for at in [Vector3(-27, 4.03, 4), Vector3(24, 4.03, -8), Vector3(3, 4.03, -29)]:
		_deco(at, Vector3(8.5, 0.08, 0.12), _rust_mat)


func _lights() -> void:
	# Local warm fixtures light the covered rooms; no sunlight enters.
	var lights := [
		[Vector3(0, 8.7, 0), 1.9, 19.0],
		[Vector3(-23, 6.5, 0), 1.5, 15.0],
		[Vector3(23, 7.3, 0), 1.5, 15.0],
		[Vector3(0, 7.3, -24), 1.3, 14.0],
		[Vector3(0, 6.1, 24), 1.3, 14.0],
		[Vector3(-23, 5.8, -24), 1.0, 12.0],
		[Vector3(23, 5.8, -24), 1.0, 12.0],
		[Vector3(-23, 5.8, 24), 1.0, 12.0],
		[Vector3(23, 5.8, 24), 1.0, 12.0],
	]
	for item in lights:
		_omni(item[0], Color(1.0, 0.68, 0.42), item[1], item[2])


func _omni(pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
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
