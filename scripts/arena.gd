class_name Arena
extends Node3D
## Ironworks: an original, compact industrial deathmatch map.
## The centre is exposed; four side chambers, upper galleries and ramps keep
## players circulating. Geometry is deliberately simple until the route layout
## has been playtested. All item positions are fixed and shared by every peer.

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


func _geometry() -> void:
	# Arena shell. The tall perimeter encloses the map; the inner, low walls
	# form rooms without hiding the upper-level fights.
	_box(Vector3(0, -0.5, 0), Vector3(68, 1, 68), _floor_mat)
	for s in [-1.0, 1.0]:
		_box(Vector3(33 * s, 7, 0), Vector3(2, 14, 68), _wall_mat)
		_box(Vector3(0, 7, 33 * s), Vector3(68, 14, 2), _wall_mat)

	# Each wall has three wide doorways. This gives a looping ground route
	# through the side rooms instead of four disconnected corners.
	for z in [-15.0, 15.0]:
		for segment in [[-31.0, -24.0], [-16.0, -6.0], [6.0, 16.0], [24.0, 31.0]]:
			_wall_z(z, segment[0], segment[1])
	for x in [-15.0, 15.0]:
		for segment in [[-31.0, -24.0], [-16.0, -6.0], [6.0, 16.0], [24.0, 31.0]]:
			_wall_x(x, segment[0], segment[1])

	# Four upper galleries, all reachable by a long ramp from a different
	# corner. A narrow bridge connects east and west above the open atrium.
	_box(Vector3(0, 3.75, -23), Vector3(19, 0.5, 7), _steel_mat)
	_box(Vector3(0, 3.75, 23), Vector3(19, 0.5, 7), _steel_mat)
	_box(Vector3(23, 3.75, 0), Vector3(7, 0.5, 19), _steel_mat)
	_box(Vector3(-23, 3.75, 0), Vector3(7, 0.5, 19), _steel_mat)
	_box(Vector3(0, 3.75, -8.5), Vector3(43, 0.5, 3), _grate_mat)
	_ramp(Vector3(-24, 0, -22), Vector3(-9, 4, -23), 4.0)
	_ramp(Vector3(24, 0, 22), Vector3(9, 4, 23), 4.0)
	_ramp(Vector3(22, 0, -24), Vector3(23, 4, -9), 4.0)
	_ramp(Vector3(-22, 0, 24), Vector3(-23, 4, 9), 4.0)

	# Structural columns, upper-floor supports and low combat cover.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(11 * sx, 3, 11 * sz), Vector3(1.5, 6, 1.5), _steel_mat)
			_box(Vector3(7 * sx, 0.8, 7 * sz), Vector3(2.2, 1.6, 2.2), _rust_mat)
			_box(Vector3(27 * sx, 2, 7 * sz), Vector3(1.2, 4, 1.2), _steel_mat)
			_box(Vector3(7 * sx, 2, 27 * sz), Vector3(1.2, 4, 1.2), _steel_mat)
			# Solid ceilings cap the corner maintenance bays.
			_box(Vector3(24 * sx, 7.8, 24 * sz), Vector3(12, 0.5, 12), _steel_mat)
			_deco(Vector3(24 * sx, 7.48, 24 * sz), Vector3(10, 0.08, 10), _grate_mat)
	for s in [-1.0, 1.0]:
		_box(Vector3(21 * s, 0.7, 13), Vector3(3.0, 1.4, 1.4), _steel_mat)
		_box(Vector3(13, 0.7, 21 * s), Vector3(1.4, 1.4, 3.0), _steel_mat)


func _decor() -> void:
	# Repeated metalwork gives the prototype a heavy industrial rhythm while
	# keeping all sightlines, collision and pickup routes easy to inspect.
	for s in [-1.0, 1.0]:
		_deco(Vector3(31.8 * s, 2.8, 0), Vector3(0.16, 0.2, 63), _rust_mat)
		_deco(Vector3(0, 2.8, 31.8 * s), Vector3(63, 0.2, 0.16), _rust_mat)
		_deco(Vector3(31.8 * s, 10.8, 0), Vector3(0.16, 0.25, 63), _steel_mat)
		_deco(Vector3(0, 10.8, 31.8 * s), Vector3(63, 0.25, 0.16), _steel_mat)
		for i in range(-3, 4):
			var at := float(i) * 8.0
			_deco(Vector3(31.75 * s, 6.5, at), Vector3(0.24, 12.5, 0.45), _steel_mat)
			_deco(Vector3(at, 6.5, 31.75 * s), Vector3(0.45, 12.5, 0.24), _steel_mat)
	# Grate bars on the bridge and safety-color edging on upper floors.
	for x in range(-19, 20, 2):
		_deco(Vector3(float(x), 4.02, -8.5), Vector3(0.10, 0.04, 2.8), _rust_mat)
	for z in [-26.5, -19.5, 19.5, 26.5]:
		_deco(Vector3(0, 3.95, z), Vector3(18.5, 0.1, 0.12), _rust_mat)
	for x in [-26.5, -19.5, 19.5, 26.5]:
		_deco(Vector3(x, 3.95, 0), Vector3(0.12, 0.1, 18.5), _rust_mat)
	# Warm ceiling fixtures and exposed pipe runs in the side chambers.
	for x in [-23.0, 23.0]:
		for z in [-23.0, 23.0]:
			_deco(Vector3(x, 7.4, z), Vector3(3.0, 0.06, 0.45), _light_mat)
	for s in [-1.0, 1.0]:
		_deco(Vector3(29.5 * s, 6, 0), Vector3(0.28, 0.28, 49), _rust_mat)
		_deco(Vector3(0, 6, 29.5 * s), Vector3(49, 0.28, 0.28), _rust_mat)


func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_color = Color(0.72, 0.65, 0.55)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	_omni(Vector3(0, 11, 0), Color(0.86, 0.68, 0.48), 1.6, 26.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_omni(Vector3(23 * sx, 7.1, 23 * sz), Color(1.0, 0.57, 0.29), 1.1, 11.0)


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
	# Four quick vertical routes, plus long ramps for bots and deliberate
	# movement. Railgun is on the exposed north gallery, rockets at centre.
	_add_pad(Vector3(0, 0, -11), Vector3(0, 4, -23), 2.2)
	_add_pad(Vector3(0, 0, 11), Vector3(0, 4, 23), 2.2)
	_add_pad(Vector3(11, 0, 0), Vector3(23, 4, 0), 2.2)
	_add_pad(Vector3(-11, 0, 0), Vector3(-23, 4, 0), 2.2)

	var ground_spawns := [
		Vector3(-8, 0, -11), Vector3(8, 0, 11),
		Vector3(22, 0, 11), Vector3(-22, 0, -11),
		Vector3(-9, 0, 24), Vector3(9, 0, -24),
		Vector3(25, 0, -7), Vector3(-25, 0, 7),
	]
	var upper_spawns := [
		Vector3(5, 4, -23), Vector3(-5, 4, 23),
		Vector3(23, 4, 5), Vector3(-23, 4, -5),
	]
	for pos: Vector3 in ground_spawns + upper_spawns:
		spawn_points.append([pos + Vector3(0, 0.1, 0), atan2(pos.x, pos.z)])
		waypoints.append(pos)

	_pickup("weapon", Vector3(-22, 0, 21), Weapons.SHOTGUN)
	_pickup("weapon", Vector3(0, 0, 0), Weapons.ROCKET)
	_pickup("weapon", Vector3(0, 4, -23), Weapons.RAIL)
	for pos: Vector3 in [Vector3(7, 0, 12), Vector3(-7, 0, -12),
			Vector3(25, 0, 13), Vector3(-25, 0, -13)]:
		_pickup("health", pos)
	_pickup("armor", Vector3(-23, 4, 0))
	_pickup("mega", Vector3(23, 4, 0))
