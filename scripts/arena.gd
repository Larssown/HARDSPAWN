class_name Arena
extends Node3D
## The Crucible: a compact three-level duel arena around an open furnace void.
## Every solid platform is a CSG primitive with collision. The two upper
## galleries are connected by walkable ramps; jump pads are faster shortcuts.

const EDGE := 30.0
const LOWER := 0.0
const MID := 5.0
const TOP := 10.0

var spawn_points: Array = []
var pickup_defs: Array = []
var jump_pads: Array[JumpPad] = []
var waypoints: Array[Vector3] = []
var nav_region: NavigationRegion3D

var _floor: StandardMaterial3D
var _wall: StandardMaterial3D
var _metal: StandardMaterial3D
var _dark: StandardMaterial3D
var _rust: StandardMaterial3D
var _warning: StandardMaterial3D
var _lava: StandardMaterial3D
var _lamp: StandardMaterial3D


func build() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	add_child(nav_region)
	_make_materials()
	_environment()
	_geometry()
	_navigation_links()
	_details()
	_lighting()
	_hazards()
	_gameplay_points()


func bake_navigation() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# CSG physics bodies are not parsed by the runtime navmesh baker, so every
	# solid also has a lightweight layer-4 source collider for bot navigation.
	mesh.geometry_collision_mask = 4
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 40.0
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	nav_region.navigation_mesh = mesh
	nav_region.bake_navigation_mesh(false)


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _surface(asset: String, tint: Color, metallic: float, roughness: float, tiling: float) -> StandardMaterial3D:
	var material := _material(tint, metallic, roughness)
	var folder := "res://assets/materials/%s/" % asset
	material.albedo_texture = load(folder + "Color.jpg")
	material.normal_enabled = true
	material.normal_texture = load(folder + "NormalGL.jpg")
	material.normal_scale = 0.5
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * tiling
	return material


func _make_materials() -> void:
	_floor = _surface("Concrete022", Color(0.72, 0.69, 0.64), 0.02, 0.9, 0.34)
	_wall = _surface("PaintedBricks004", Color(0.70, 0.68, 0.63), 0.03, 0.9, 0.44)
	_metal = _surface("MetalPlates013", Color(0.75, 0.74, 0.70), 0.22, 0.77, 0.48)
	_dark = _surface("PaintedMetal012", Color(0.46, 0.46, 0.44), 0.20, 0.82, 0.46)
	_rust = _material(Color(0.38, 0.23, 0.17), 0.16, 0.8)
	_warning = _material(Color(0.92, 0.42, 0.12), 0.08, 0.68)
	_lava = _material(Color(0.55, 0.13, 0.025), 0.0, 0.75)
	_lava.emission_enabled = true
	_lava.emission = Color(1.0, 0.24, 0.035)
	_lava.emission_energy_multiplier = 2.1
	_lamp = _material(Color(1.0, 0.73, 0.40), 0.0, 0.4)
	_lamp.emission_enabled = true
	_lamp.emission = Color(1.0, 0.65, 0.25)
	_lamp.emission_energy_multiplier = 1.8


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.09, 0.12, 0.16)
	sky_material.sky_horizon_color = Color(0.49, 0.29, 0.20)
	sky_material.ground_horizon_color = Color(0.30, 0.16, 0.13)
	sky_material.ground_bottom_color = Color(0.10, 0.07, 0.08)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.64, 0.60)
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.18
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _box(at: Vector3, size: Vector3, material: Material, solid := true) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.position = at
	box.size = size
	box.material = material
	box.use_collision = solid
	box.collision_layer = 1 if solid else 0
	box.collision_mask = 0
	if solid:
		nav_region.add_child(box)
		var source := StaticBody3D.new()
		source.collision_layer = 4
		source.collision_mask = 0
		box.add_child(source)
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		source.add_child(collider)
	else:
		add_child(box)
	return box


func _cylinder(at: Vector3, radius: float, height: float, material: Material, solid := true) -> CSGCylinder3D:
	var cylinder := CSGCylinder3D.new()
	cylinder.position = at
	cylinder.radius = radius
	cylinder.height = height
	cylinder.sides = 20
	cylinder.material = material
	cylinder.use_collision = solid
	cylinder.collision_layer = 1 if solid else 0
	cylinder.collision_mask = 0
	if solid:
		nav_region.add_child(cylinder)
		var source := StaticBody3D.new()
		source.collision_layer = 4
		source.collision_mask = 0
		cylinder.add_child(source)
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		var collider := CollisionShape3D.new()
		collider.shape = shape
		source.add_child(collider)
	else:
		add_child(cylinder)
	return cylinder


func _ramp(low: Vector3, high: Vector3, width: float) -> void:
	var thickness := 0.55
	var direction := (high - low).normalized()
	var basis := Basis.looking_at(direction, Vector3.UP)
	var length := low.distance_to(high) + 0.8
	var center := (low + high) * 0.5 - basis.y * thickness * 0.5
	var ramp := _box(center, Vector3(width, thickness, length), _metal)
	ramp.basis = basis
	for side in [-1.0, 1.0]:
		var rail := _box(Vector3.ZERO, Vector3(0.12, 0.12, length), _rust, false)
		rail.transform = ramp.transform * Transform3D(Basis.IDENTITY,
			Vector3(side * (width * 0.5 - 0.12), thickness * 0.5 + 0.06, 0))


func _geometry() -> void:
	# Four thick slabs make a cruciform perimeter. Missing corners expose the
	# outside void and give the floating fortress a distinct silhouette.
	_box(Vector3(0, -1.0, -18.5), Vector3(46, 2.0, 23), _floor)
	_box(Vector3(0, -1.0, 18.5), Vector3(46, 2.0, 23), _floor)
	_box(Vector3(-18.5, -1.0, 0), Vector3(23, 2.0, 44), _floor)
	_box(Vector3(18.5, -1.0, 0), Vector3(23, 2.0, 44), _floor)
	# Short wings extend each cardinal approach without lengthening the loop.
	_box(Vector3(0, -1.0, -32.0), Vector3(14, 2.0, 5), _metal)
	_box(Vector3(0, -1.0, 32.0), Vector3(14, 2.0, 5), _metal)
	_box(Vector3(-32.0, -1.0, 0), Vector3(5, 2.0, 14), _metal)
	_box(Vector3(32.0, -1.0, 0), Vector3(5, 2.0, 14), _metal)

	# Level two is a four-sided gallery with one exposed bridge across the pit.
	_box(Vector3(0, 4.65, -11), Vector3(28, 0.7, 4.2), _metal)
	_box(Vector3(0, 4.65, 11), Vector3(28, 0.7, 4.2), _metal)
	_box(Vector3(-11, 4.65, 0), Vector3(4.2, 0.7, 22), _metal)
	_box(Vector3(11, 4.65, 0), Vector3(4.2, 0.7, 22), _metal)
	_box(Vector3(0, 4.65, 0), Vector3(22, 0.7, 2.8), _dark)
	# Wide walkable ramps keep the entire gallery reachable without a pad.
	_ramp(Vector3(-11.5, 0, -25), Vector3(-11.5, MID, -11), 3.5)
	_ramp(Vector3(11.5, 0, 25), Vector3(11.5, MID, 11), 3.5)

	# Two offset crowns form the third level and opposing rail sightlines.
	_box(Vector3(-17, 9.65, -18), Vector3(10.5, 0.7, 8.5), _metal)
	_box(Vector3(17, 9.65, 18), Vector3(10.5, 0.7, 8.5), _metal)
	_ramp(Vector3(-11.5, MID, -11), Vector3(-17, TOP, -18), 3.2)
	_ramp(Vector3(11.5, MID, 11), Vector3(17, TOP, 18), 3.2)

	# Large silhouettes give the towers scale, without filling combat lanes.
	_cylinder(Vector3(-21, 4.6, -21), 2.15, 9.2, _wall)
	_cylinder(Vector3(21, 4.6, 21), 2.15, 9.2, _wall)
	for x in [-27.0, 27.0]:
		for z in [-18.5, 18.5]:
			_cylinder(Vector3(x, 4.5, z), 1.05, 9.0, _dark)
	for z in [-27.0, 27.0]:
		for x in [-18.5, 18.5]:
			_cylinder(Vector3(x, 3.2, z), 0.85, 6.4, _dark)

	# Low cover leaves the central approach and both ramp mouths clear.
	for at in [Vector3(-23, 1.0, 10), Vector3(23, 1.0, -10),
			Vector3(-4, 1.0, -23), Vector3(4, 1.0, 23),
			Vector3(-23, 1.0, -15), Vector3(23, 1.0, 15)]:
		_box(at, Vector3(2.7, 2.0, 2.7), _dark)
		_box(at + Vector3(0, 1.04, 0), Vector3(2.95, 0.09, 2.95), _rust, false)


func _details() -> void:
	# Thin hazard stripes mark every walkable edge without preventing falls.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 7.15, 0.012, 0), Vector3(0.14, 0.024, 13.9), _warning, false)
		_box(Vector3(0, 0.012, side * 7.15), Vector3(13.9, 0.024, 0.14), _warning, false)
		_box(Vector3(side * 29.65, 0.016, 0), Vector3(0.18, 0.03, 43), _warning, false)
		_box(Vector3(0, 0.016, side * 29.65), Vector3(45, 0.03, 0.18), _warning, false)
		_box(Vector3(side * 9.0, 5.03, 0), Vector3(0.12, 0.04, 21), _warning, false)
		_box(Vector3(0, 5.03, side * 9.0), Vector3(27, 0.04, 0.12), _warning, false)
		_box(Vector3(side * 1.38, 5.03, 0), Vector3(0.08, 0.04, 13.0), _warning, false)
	# Underside girders expose the bridge structure from ground level.
	for z in [-11.0, 0.0, 11.0]:
		_box(Vector3(0, 4.15, z), Vector3(24, 0.22, 0.28), _rust, false)
	for x in [-11.0, 11.0]:
		_box(Vector3(x, 4.15, 0), Vector3(0.28, 0.22, 20), _rust, false)
	# Tower crowns and vertical ribs create a recognizable skyline.
	for tower in [Vector3(-21, 0, -21), Vector3(21, 0, 21)]:
		_cylinder(tower + Vector3(0, 9.5, 0), 2.45, 0.45, _rust, false)
		_cylinder(tower + Vector3(0, 12.2, 0), 1.25, 5.0, _dark, false)
		_cylinder(tower + Vector3(0, 15.2, 0), 1.55, 0.55, _rust, false)
		_cylinder(tower + Vector3(0, 17.0, 0), 0.45, 3.2, _dark, false)
		_cylinder(tower + Vector3(0, 18.7, 0), 0.57, 0.18, _lamp, false)
	# Arches mark the exposed center crossing and break up long sightlines.
	for x in [-11.0, 11.0]:
		for z in [-2.55, 2.55]:
			_box(Vector3(x, 7.0, z), Vector3(0.35, 4.0, 0.35), _rust, false)
		_box(Vector3(x, 9.0, 0), Vector3(0.46, 0.32, 5.5), _metal, false)
	# Recessed strips make the gallery underside readable from ground level.
	for x in [-8.0, 0.0, 8.0]:
		for z in [-11.0, 11.0]:
			_box(Vector3(x, 4.24, z), Vector3(2.4, 0.05, 0.24), _lamp, false)
	for z in [-25.0, 25.0]:
		_box(Vector3(0, 0.018, z), Vector3(7.0, 0.035, 0.12), _warning, false)


func _navigation_links() -> void:
	# CSG ramp and deck surfaces can bake as adjacent islands. These links
	# connect their ends for bots while the physical ramps remain walkable.
	_link(Vector3(-11.5, LOWER, -25), Vector3(-11.5, MID, -11))
	_link(Vector3(11.5, LOWER, 25), Vector3(11.5, MID, 11))
	_link(Vector3(-11.5, MID, -11), Vector3(-17, TOP, -18))
	_link(Vector3(11.5, MID, 11), Vector3(17, TOP, 18))


func _link(from: Vector3, to: Vector3) -> void:
	var link := NavigationLink3D.new()
	link.start_position = from + Vector3(0, 0.35, 0)
	link.end_position = to + Vector3(0, 0.35, 0)
	link.bidirectional = true
	add_child(link)


func _lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -34, 0)
	sun.light_color = Color(1.0, 0.74, 0.52)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	for at in [Vector3(-17, 8.7, -18), Vector3(17, 8.7, 18),
			Vector3(-11, 4.1, 0), Vector3(11, 4.1, 0)]:
		_box(at + Vector3(0, 0.2, 0), Vector3(2.2, 0.2, 0.6), _dark, false)
		_box(at, Vector3(1.9, 0.08, 0.38), _lamp, false)
		var light := OmniLight3D.new()
		light.position = at - Vector3(0, 0.35, 0)
		light.light_color = Color(1.0, 0.64, 0.37)
		light.light_energy = 1.1
		light.omni_range = 8.0
		add_child(light)
	var furnace := OmniLight3D.new()
	furnace.position = Vector3(0, -4.4, 0)
	furnace.light_color = Color(1.0, 0.24, 0.05)
	furnace.light_energy = 2.3
	furnace.omni_range = 16.0
	add_child(furnace)


func _zone(at: Vector3, size: Vector3) -> void:
	var zone := KillZone.new()
	zone.position = at
	add_child(zone)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	zone.add_child(collider)


func _hazards() -> void:
	# A visible furnace sits below the bridge; neither it nor the void has a floor.
	_box(Vector3(0, -4.0, 0), Vector3(13.8, 0.2, 13.8), _lava, false)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 6.95, -2.0, 0), Vector3(0.10, 4.0, 13.8), _dark, false)
		_box(Vector3(0, -2.0, side * 6.95), Vector3(13.8, 4.0, 0.10), _dark, false)
		_box(Vector3(side * 6.87, -2.8, 0), Vector3(0.02, 0.22, 12.8), _lamp, false)
		_box(Vector3(0, -2.8, side * 6.87), Vector3(12.8, 0.22, 0.02), _lamp, false)
	for offset in [-4.5, -1.5, 1.5, 4.5]:
		_box(Vector3(offset, -3.87, 0), Vector3(0.22, 0.025, 12.8), _warning, false)
	_zone(Vector3(0, -6.1, 0), Vector3(12.8, 10.4, 12.8))
	# The broad lower zone catches falls outside the platform perimeter.
	_zone(Vector3(0, -10.5, 0), Vector3(160, 18, 160))


func _launch_solution(from: Vector3, to: Vector3, apex: float) -> Dictionary:
	var peak := maxf(from.y, to.y) + apex
	var rise := peak - from.y
	var up_time := sqrt(2.0 * rise / Player.GRAVITY)
	var down_time := sqrt(2.0 * (peak - to.y) / Player.GRAVITY)
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	return {"height": rise, "direction": flat.normalized(),
		"speed": flat.length() / (up_time + down_time)}


func _add_pad(pos: Vector3, target: Vector3, apex: float) -> void:
	var pad := JumpPad.new()
	var solution := _launch_solution(pos, target, apex)
	pad.launch_height = solution.height
	pad.launch_direction = solution.direction
	pad.horizontal_speed = solution.speed
	pad.position = pos + Vector3(0, 0.45, 0)
	pad.name = "JumpPad%d" % jump_pads.size()
	add_child(pad)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.9, 2.4)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	pad.add_child(collider)
	_cylinder(pos + Vector3(0, 0.08, 0), 1.25, 0.16, _rust, false)
	_cylinder(pos + Vector3(0, 0.17, 0), 0.93, 0.04, _warning, false)
	_box(pos + Vector3(0, 0.205, 0), Vector3(0.18, 0.03, 1.25), _lamp, false)
	jump_pads.append(pad)


func _pickup(kind: String, pos: Vector3, weapon_id := -1) -> void:
	var item := {"kind": kind, "pos": pos}
	if weapon_id >= 0:
		item.weapon = weapon_id
	pickup_defs.append(item)
	waypoints.append(pos)


func _gameplay_points() -> void:
	_add_pad(Vector3(-17, 0, -26), Vector3(-17, TOP, -18), 3.0)
	_add_pad(Vector3(17, 0, 26), Vector3(17, TOP, 18), 3.0)
	_add_pad(Vector3(-22, 0, 4), Vector3(-11, MID, 0), 2.2)
	_add_pad(Vector3(22, 0, -4), Vector3(11, MID, 0), 2.2)

	for pos: Vector3 in [
		Vector3(-24, 0, 13), Vector3(-11, 0, 24),
		Vector3(11, 0, -24), Vector3(24, 0, -13),
		Vector3(-24, 0, -13), Vector3(-5, 0, -24),
		Vector3(5, 0, 24), Vector3(24, 0, 13),
	]:
		spawn_points.append([pos + Vector3(0, 0.1, 0), atan2(pos.x, pos.z)])
		waypoints.append(pos)

	_pickup("weapon", Vector3(-24, 0, 19), Weapons.SHOTGUN)
	_pickup("weapon", Vector3(24, 0, -19), Weapons.ROCKET)
	_pickup("weapon", Vector3(-17, TOP, -18), Weapons.RAIL)
	_pickup("armor", Vector3(0, MID, 11))
	_pickup("mega", Vector3(0, MID, 0))
	for pos in [Vector3(-23, 0, -3), Vector3(23, 0, 3),
			Vector3(-3, 0, -23), Vector3(3, 0, 23)]:
		_pickup("health", pos)
	for pos in [Vector3(-19, 0, 13), Vector3(19, 0, -13),
			Vector3(1, 0, -25), Vector3(-1, 0, 25)]:
		_pickup("ammo", pos, Weapons.MG)
