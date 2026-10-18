class_name Arena
extends Node3D
## The Crucible: a compact three-level duel arena around a lava pit.
## Layout by ChatGPT (approved by Patrik). Look matches Patrik's concept image
## (docs/concept_target.jpg): black void, black grid floor, grey blocks with thin
## glowing edge lines, golden jump pads and a blazing lava pit.

const EDGE := 30.0
const LOWER := 0.0
const MID := 5.0
const TOP := 10.0
const BLOCK_SHADER := preload("res://shaders/block.gdshader")
const GOLD := Color(1.0, 0.72, 0.32)
const LAYER_SOLID := 1 | 4  # 1 = gameplay collision, 4 = navmesh source for bots

var spawn_points: Array = []
var pickup_defs: Array = []
var jump_pads: Array[JumpPad] = []
var waypoints: Array[Vector3] = []
var nav_region: NavigationRegion3D
var lava_pit: LavaPit

var _floor: ShaderMaterial
var _block: ShaderMaterial
var _bridge: ShaderMaterial
var _dark: ShaderMaterial
var _pit_wall: ShaderMaterial
var _lamp: StandardMaterial3D
var _gold: StandardMaterial3D


func build() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	add_child(nav_region)
	_make_materials()
	_environment()
	_geometry()
	_navigation_links()
	_details()
	_backdrop()
	_lighting()
	_hazards()
	_gameplay_points()


func bake_navigation() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 4
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 40.0
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	nav_region.navigation_mesh = mesh
	nav_region.bake_navigation_mesh(false)


# --- Materials & environment ----------------------------------------------------------

func _block_material(base: Color, edge_emission := 1.6, grid := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BLOCK_SHADER
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("edge_emission", edge_emission)
	m.set_shader_parameter("grid_top", grid)
	return m


func _make_materials() -> void:
	_floor = _block_material(Color(0.2, 0.205, 0.215), 0.8, true)
	_block = _block_material(Color(0.33, 0.335, 0.345), 1.0)
	_bridge = _block_material(Color(0.25, 0.255, 0.265), 1.0)
	_dark = _block_material(Color(0.16, 0.165, 0.175), 0.8)
	_pit_wall = _block_material(Color(0.42, 0.4, 0.38), 1.0)
	_pit_wall.set_shader_parameter("edge_color", Color(1.0, 0.62, 0.35))
	_pit_wall.set_shader_parameter("seam_size", 1.5)
	_pit_wall.set_shader_parameter("seam_strength", 0.1)
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color(0.95, 0.95, 0.92)
	_lamp.emission_enabled = true
	_lamp.emission = Color(1.0, 0.97, 0.9)
	_lamp.emission_energy_multiplier = 2.5
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(0.25, 0.18, 0.08)
	_gold.metallic = 0.6
	_gold.roughness = 0.35
	_gold.emission_enabled = true
	_gold.emission = GOLD
	_gold.emission_energy_multiplier = 3.2


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.0, 0.0, 0.0)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


# --- Building blocks ---------------------------------------------------------------

## Box mesh with the concept edge shader. `solid` adds gameplay + navmesh collision.
func _box(at: Vector3, size: Vector3, material: ShaderMaterial, solid := true, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.set_instance_shader_parameter("box_size", size)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_SOLID
		body.collision_mask = 0
		body.transform = Transform3D(basis, at)
		nav_region.add_child(body)
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		body.add_child(mesh)
	else:
		mesh.transform = Transform3D(basis, at)
		add_child(mesh)
	return mesh


## Invisible collision box (used under stair visuals so movement stays smooth).
func _collider(at: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_SOLID
	body.collision_mask = 0
	body.transform = Transform3D(basis, at)
	nav_region.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)


func _mesh(mesh: Mesh, at: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	parent.add_child(mi)
	return mi


## A staircase between two points: a smooth invisible ramp for movement,
## with outlined step blocks drawn on top (as in the concept image).
func _stairs(low: Vector3, high: Vector3, width: float) -> void:
	var flat := Vector3(high.x - low.x, 0, high.z - low.z)
	var run := flat.length()
	var rise := high.y - low.y
	var yaw_basis := Basis.looking_at(flat.normalized(), Vector3.UP)
	var ramp_dir := (high - low).normalized()
	var ramp_basis := Basis.looking_at(ramp_dir, Vector3.UP)
	var thickness := 0.55
	_collider((low + high) * 0.5 - ramp_basis.y * thickness * 0.5,
		Vector3(width, thickness, low.distance_to(high) + 0.8), ramp_basis)
	var steps := maxi(int(ceil(rise / 0.33)), 2)
	var depth := run / steps
	var step_h := rise / steps
	for i in steps:
		var top := low.y + step_h * (i + 1)
		var along := low + flat.normalized() * depth * (i + 0.5)
		var slab := 0.5
		_box(Vector3(along.x, top - slab * 0.5, along.z), Vector3(width, slab, depth + 0.01), _bridge, false, yaw_basis)
	# Side stringers along both edges
	for side in [-1.0, 1.0]:
		var offset: Vector3 = yaw_basis.x * side * (width * 0.5 + 0.12)
		_box((low + high) * 0.5 + offset - ramp_basis.y * 0.35 + Vector3(0, step_h * 0.5, 0),
			Vector3(0.24, 0.7, low.distance_to(high) + 0.3), _dark, false, ramp_basis)


## Rectangular portal frame (two posts and a lintel), solid.
func _gate(center: Vector3, width: float, height: float, thickness: float, along_x: bool) -> void:
	var post := Vector3(thickness, height, thickness)
	for side in [-1.0, 1.0]:
		var off: Vector3 = Vector3(side * (width * 0.5 - thickness * 0.5), 0, 0) if along_x \
			else Vector3(0, 0, side * (width * 0.5 - thickness * 0.5))
		_box(center + off + Vector3(0, height * 0.5, 0), post, _block)
	var lintel := Vector3(width, thickness, thickness) if along_x else Vector3(thickness, thickness, width)
	_box(center + Vector3(0, height - thickness * 0.5, 0), lintel, _block)


# --- Layout (positions unchanged from ChatGPT's Crucible) -----------------------------

func _geometry() -> void:
	# Cruciform floor around the pit, with short wings on each side.
	_box(Vector3(0, -1.0, -18.5), Vector3(46, 2.0, 23), _floor)
	_box(Vector3(0, -1.0, 18.5), Vector3(46, 2.0, 23), _floor)
	_box(Vector3(-18.5, -1.0, 0), Vector3(23, 2.0, 44), _floor)
	_box(Vector3(18.5, -1.0, 0), Vector3(23, 2.0, 44), _floor)
	_box(Vector3(0, -1.0, -32.0), Vector3(14, 2.0, 5), _floor)
	_box(Vector3(0, -1.0, 32.0), Vector3(14, 2.0, 5), _floor)
	_box(Vector3(-32.0, -1.0, 0), Vector3(5, 2.0, 14), _floor)
	_box(Vector3(32.0, -1.0, 0), Vector3(5, 2.0, 14), _floor)

	# Level two: four-sided gallery and the exposed bridge across the pit.
	_box(Vector3(0, 4.65, -11), Vector3(28, 0.7, 4.2), _bridge)
	_box(Vector3(0, 4.65, 11), Vector3(28, 0.7, 4.2), _bridge)
	_box(Vector3(-11, 4.65, 0), Vector3(4.2, 0.7, 22), _bridge)
	_box(Vector3(11, 4.65, 0), Vector3(4.2, 0.7, 22), _bridge)
	_box(Vector3(0, 4.65, 0), Vector3(22, 0.7, 2.8), _bridge)
	_stairs(Vector3(-11.5, 0, -25), Vector3(-11.5, MID, -11), 3.5)
	_stairs(Vector3(11.5, 0, 25), Vector3(11.5, MID, 11), 3.5)

	# Level three: two crowns on top of square towers.
	_box(Vector3(-17, 9.65, -18), Vector3(10.5, 0.7, 8.5), _block)
	_box(Vector3(17, 9.65, 18), Vector3(10.5, 0.7, 8.5), _block)
	_stairs(Vector3(-11.5, MID, -11), Vector3(-17, TOP, -18), 3.2)
	_stairs(Vector3(11.5, MID, 11), Vector3(17, TOP, 18), 3.2)
	_box(Vector3(-21, 4.6, -21), Vector3(4.2, 9.2, 4.2), _block)
	_box(Vector3(21, 4.6, 21), Vector3(4.2, 9.2, 4.2), _block)

	# Square pillars around the perimeter.
	for x in [-27.0, 27.0]:
		for z in [-18.5, 18.5]:
			_box(Vector3(x, 4.5, z), Vector3(2.1, 9.0, 2.1), _block)
	for z in [-27.0, 27.0]:
		for x in [-18.5, 18.5]:
			_box(Vector3(x, 3.2, z), Vector3(1.7, 6.4, 1.7), _block)

	# Low cover blocks.
	for at in [Vector3(-23, 1.0, 10), Vector3(23, 1.0, -10),
			Vector3(-4, 1.0, -23), Vector3(4, 1.0, 23),
			Vector3(-23, 1.0, -15), Vector3(23, 1.0, 15)]:
		_box(at, Vector3(2.7, 2.0, 2.7), _block)


func _details() -> void:
	# Girders under the gallery.
	for z in [-11.0, 0.0, 11.0]:
		_box(Vector3(0, 4.15, z), Vector3(24, 0.3, 0.4), _dark, false)
	for x in [-11.0, 11.0]:
		_box(Vector3(x, 4.15, 0), Vector3(0.4, 0.3, 20), _dark, false)
	# Gallery arches over the centre crossing.
	for x in [-11.0, 11.0]:
		_gate(Vector3(x, MID, 0), 5.9, 4.4, 0.6, false)
	# Portal frames on the tower crowns (rail perch) and at the four wing ends.
	_gate(Vector3(-17, TOP, -21.6), 7.0, 5.2, 0.9, true)
	_gate(Vector3(17, TOP, 21.6), 7.0, 5.2, 0.9, true)
	_gate(Vector3(0, LOWER, -33.6), 11.0, 7.5, 1.1, true)
	_gate(Vector3(0, LOWER, 33.6), 11.0, 7.5, 1.1, true)
	_gate(Vector3(-33.6, LOWER, 0), 11.0, 7.5, 1.1, false)
	_gate(Vector3(33.6, LOWER, 0), 11.0, 7.5, 1.1, false)
	# Tower crowns rising above the third level.
	for t in [Vector3(-21, 0, -21), Vector3(21, 0, 21)]:
		_box(t + Vector3(0, 12.6, 0), Vector3(2.4, 5.0, 2.4), _block, false)
		_box(t + Vector3(0, 15.4, 0), Vector3(3.0, 0.6, 3.0), _dark, false)
		_box(t + Vector3(0, 17.2, 0), Vector3(0.8, 3.0, 0.8), _block, false)
	# Lamp strips under the gallery.
	for x in [-8.0, 0.0, 8.0]:
		for z in [-11.0, 11.0]:
			_mesh(_boxmesh(Vector3(2.4, 0.05, 0.24)), Vector3(x, 4.27, z), _lamp)


func _boxmesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Large silhouettes standing in the black void around the arena.
func _backdrop() -> void:
	for spec in [
		[Vector3(0, 6, -44), Vector3(4, 34, 4)], [Vector3(-9, 2, -42), Vector3(6, 22, 6)],
		[Vector3(10, 0, -45), Vector3(5, 16, 7)], [Vector3(44, 4, 6), Vector3(5, 28, 5)],
		[Vector3(-44, 3, -8), Vector3(6, 24, 6)], [Vector3(-8, 1, 45), Vector3(7, 18, 5)],
		[Vector3(9, 5, 43), Vector3(4, 30, 4)], [Vector3(38, -2, -36), Vector3(8, 14, 8)],
		[Vector3(-38, -2, 36), Vector3(8, 14, 8)],
	]:
		_box(spec[0], spec[1], _block, false)


func _navigation_links() -> void:
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
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color(0.92, 0.94, 1.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 150, 0)
	fill.light_color = Color(0.7, 0.75, 0.85)
	fill.light_energy = 0.18
	add_child(fill)
	for at in [Vector3(-11, 4.0, -11), Vector3(11, 4.0, 11), Vector3(-11, 4.0, 11), Vector3(11, 4.0, -11)]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = Color(0.95, 0.95, 1.0)
		light.light_energy = 0.7
		light.omni_range = 9.0
		add_child(light)


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
	lava_pit = LavaPit.new()
	lava_pit.name = "LavaPit"
	add_child(lava_pit)
	lava_pit.build()
	# Brighter, more orange lava like the concept image.
	var lava := lava_pit.get_node("Surface") as MeshInstance3D
	var lava_mat := lava.material_override as ShaderMaterial
	lava_mat.set_shader_parameter("crust_color", Color(0.55, 0.07, 0.01))
	lava_mat.set_shader_parameter("hot_color", Color(1.0, 0.33, 0.05))
	lava_mat.set_shader_parameter("core_color", Color(1.0, 0.72, 0.32))
	lava_mat.set_shader_parameter("emission_strength", 4.5)
	# Pit walls catch the lava's light, like the concept image.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 7.25, -2.15, 0), Vector3(0.6, 4.3, 15.1), _pit_wall, false)
		_box(Vector3(0, -2.15, side * 7.25), Vector3(13.9, 4.3, 0.6), _pit_wall, false)
	# Warm light spilling out of the pit onto the surrounding blocks.
	var spill := OmniLight3D.new()
	spill.position = Vector3(0, 1.0, 0)
	spill.light_color = Color(1.0, 0.42, 0.12)
	spill.light_energy = 2.6
	spill.omni_range = 18.0
	spill.omni_attenuation = 1.4
	add_child(spill)
	var pit_fill := OmniLight3D.new()
	pit_fill.position = Vector3(0, -2.2, 0)
	pit_fill.light_color = Color(1.0, 0.45, 0.15)
	pit_fill.light_energy = 3.0
	pit_fill.omni_range = 10.0
	add_child(pit_fill)
	# A lower fallback catches falls outside the platform perimeter.
	_zone(Vector3(0, -13.0, 0), Vector3(160, 17, 160))


# --- Jump pads, spawns, items -------------------------------------------------------

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
	jump_pads.append(pad)
	_pad_visual(pos)


## Golden concentric-ring pad with a hovering ring, rising sparks and a soft glow.
func _pad_visual(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var base := CylinderMesh.new()
	base.top_radius = 1.35
	base.bottom_radius = 1.45
	base.height = 0.16
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.12, 0.12, 0.13)
	base_mat.metallic = 0.5
	base_mat.roughness = 0.4
	_mesh(base, Vector3(0, 0.08, 0), base_mat, root)
	for r in [1.15, 0.82, 0.5]:
		var ring := TorusMesh.new()
		ring.inner_radius = r - 0.05
		ring.outer_radius = r
		ring.rings = 32
		ring.ring_segments = 6
		_mesh(ring, Vector3(0, 0.17, 0), _gold, root)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.28
	disc.height = 0.03
	_mesh(disc, Vector3(0, 0.17, 0), _gold, root)
	# Hovering, spinning ring
	var hover := TorusMesh.new()
	hover.inner_radius = 0.62
	hover.outer_radius = 0.67
	hover.rings = 32
	hover.ring_segments = 6
	var spinner := _mesh(hover, Vector3(0, 1.1, 0), _gold, root)
	spinner.rotation.x = 0.25
	var tw := spinner.create_tween().set_loops()
	tw.tween_property(spinner, "rotation:y", TAU, 3.0).from(0.0)
	var bob := spinner.create_tween().set_loops()
	bob.tween_property(spinner, "position:y", 1.35, 1.2).set_trans(Tween.TRANS_SINE)
	bob.tween_property(spinner, "position:y", 1.05, 1.2).set_trans(Tween.TRANS_SINE)
	# Faint light column
	var beam := CylinderMesh.new()
	beam.top_radius = 0.05
	beam.bottom_radius = 0.18
	beam.height = 2.6
	beam.cap_top = false
	beam.cap_bottom = false
	var beam_mi := _mesh(beam, Vector3(0, 1.4, 0), Fx.glow_material(GOLD, 0.1), root)
	beam_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rising sparks
	var sparks := CPUParticles3D.new()
	sparks.amount = 18
	sparks.lifetime = 1.6
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparks.emission_ring_axis = Vector3.UP
	sparks.emission_ring_radius = 0.9
	sparks.emission_ring_inner_radius = 0.3
	sparks.emission_ring_height = 0.0
	sparks.direction = Vector3.UP
	sparks.spread = 8.0
	sparks.gravity = Vector3.ZERO
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 1.8
	var spark := SphereMesh.new()
	spark.radius = 0.025
	spark.height = 0.05
	spark.radial_segments = 4
	spark.rings = 2
	sparks.mesh = spark
	sparks.material_override = Fx.glow_material(GOLD, 4.0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	sparks.color_ramp = fade
	sparks.position.y = 0.2
	root.add_child(sparks)
	var light := OmniLight3D.new()
	light.light_color = GOLD
	light.light_energy = 1.4
	light.omni_range = 4.5
	light.position.y = 0.8
	root.add_child(light)


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
