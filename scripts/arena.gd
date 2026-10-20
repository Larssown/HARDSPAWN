class_name Arena
extends Node3D
## The Crucible: a compact three-level duel arena around a lava pit.
## Layout by ChatGPT (approved by Patrik). Current look target (2026-10-20):
## docs/concept_white_dust.jpg — white cracked concrete, bright hazy sky, dusty fog.

const EDGE := 30.0
const LOWER := 0.0
const MID := 5.0
const TOP := 10.0
const BLOCK_SHADER := preload("res://shaders/block.gdshader")
const SKY_SHADER := preload("res://shaders/arena_sky.gdshader")
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
## Boxes registered per group; touching sides inside a group are drawn seamless.
var _join_groups := {}
var _gate_count := 0


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
	_compute_joins()
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


func _concrete(base: Color, edge_emission: float, cracks: float, scale: float) -> ShaderMaterial:
	var m := _block_material(base, edge_emission)
	m.set_shader_parameter("edge_color", Color(1.0, 1.0, 1.0))
	m.set_shader_parameter("crack_amount", cracks)
	m.set_shader_parameter("crack_scale", scale)
	m.set_shader_parameter("seam_strength", 0.0)
	m.set_shader_parameter("base_variation", 0.04)
	m.set_shader_parameter("bottom_shade", 0.18)
	m.set_shader_parameter("roughness_value", 0.92)
	return m


func _make_materials() -> void:
	# White cracked concrete everywhere; slightly darker walkways so levels read apart.
	_floor = _concrete(Color(0.8, 0.795, 0.78), 0.5, 1.0, 1.15)
	_block = _concrete(Color(0.72, 0.72, 0.71), 0.9, 0.65, 0.95)
	_bridge = _concrete(Color(0.56, 0.56, 0.55), 0.9, 0.6, 1.0)
	_dark = _concrete(Color(0.5, 0.5, 0.5), 0.3, 0.4, 0.9)
	_pit_wall = _concrete(Color(0.7, 0.66, 0.62), 0.6, 0.8, 0.9)
	_pit_wall.set_shader_parameter("edge_color", Color(1.0, 0.62, 0.35))
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
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Overcast light: most of the illumination comes softly from the whole sky.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.82
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.1
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.4
	# Milky distance haze that swallows the far towers, thicker low down so the
	# void under the arena fills with white mist.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.86, 0.87, 0.88)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.0045
	env.fog_height = -1.0
	env.fog_height_density = 0.06
	env.fog_sky_affect = 0.55
	env.fog_aerial_perspective = 0.25
	# Thin sunlit volumetric haze for soft light shafts and that dusty glow.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0028
	env.volumetric_fog_albedo = Color(0.95, 0.94, 0.92)
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_ambient_inject = 0.15
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 120.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.1
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var dust := DustField.new()
	dust.name = "Dust"
	add_child(dust)


# --- Building blocks ---------------------------------------------------------------

## Box mesh with the concept edge shader. `solid` adds gameplay + navmesh collision.
func _box(at: Vector3, size: Vector3, material: ShaderMaterial, solid := true, basis := Basis.IDENTITY,
		group := "") -> MeshInstance3D:
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
	if group != "":
		if not _join_groups.has(group):
			_join_groups[group] = []
		_join_groups[group].append([mesh, AABB(at - size * 0.5, size)])
	return mesh


## Box given by its min/max corners (axis aligned), for seamless groups.
func _span(from: Vector3, to: Vector3, material: ShaderMaterial, group: String, solid := true) -> void:
	var lo := Vector3(minf(from.x, to.x), minf(from.y, to.y), minf(from.z, to.z))
	var hi := Vector3(maxf(from.x, to.x), maxf(from.y, to.y), maxf(from.z, to.z))
	_box((lo + hi) * 0.5, hi - lo, material, solid, Basis.IDENTITY, group)


## Hides outlines on sides that are completely covered by a block of the same group,
## so floors and walkways built from several boxes read as one piece.
func _compute_joins() -> void:
	for group in _join_groups:
		var list: Array = _join_groups[group]
		for item in list:
			var box: AABB = item[1]
			var jp := Vector3.ZERO
			var jn := Vector3.ZERO
			for axis in 3:
				if _face_covered(box, axis, 1.0, list, item):
					jp[axis] = 1.0
				if _face_covered(box, axis, -1.0, list, item):
					jn[axis] = 1.0
			var mesh: MeshInstance3D = item[0]
			mesh.set_instance_shader_parameter("join_pos", jp)
			mesh.set_instance_shader_parameter("join_neg", jn)


func _face_covered(box: AABB, axis: int, sgn: float, list: Array, self_item: Array) -> bool:
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	for i in 5:
		for k in 5:
			var p := box.get_center()
			p[axis] = (box.end[axis] if sgn > 0.0 else box.position[axis]) + 0.02 * sgn
			p[u] = lerpf(box.position[u] + 0.03, box.end[u] - 0.03, i / 4.0)
			p[v] = lerpf(box.position[v] + 0.03, box.end[v] - 0.03, k / 4.0)
			var inside := false
			for other in list:
				if other != self_item and (other[1] as AABB).grow(0.001).has_point(p):
					inside = true
					break
			if not inside:
				return false
	return true


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
	# Side stringers hide the step ends and read as solid stair walls.
	# They stop half a step short of both ends so nothing pokes up onto the floor.
	var ramp_len := low.distance_to(high)
	var sin_a := rise / ramp_len
	var trim_low := depth * 0.6
	var trim_high := (step_h + 0.06) / sin_a  # top edge ends below the platform surface
	var along := (trim_low + ramp_len - trim_high) * 0.5
	for side in [-1.0, 1.0]:
		var offset: Vector3 = yaw_basis.x * side * (width * 0.5 + 0.13)
		var top_line := low + ramp_dir * along + Vector3(0, step_h, 0)
		_box(top_line + offset - ramp_basis.y * 0.5, Vector3(0.24, 1.0, ramp_len - trim_low - trim_high),
			_dark, false, ramp_basis)


## Rectangular portal frame (two posts and a lintel), solid.
## The lintel sits between the posts (no overlapping faces), drawn as one frame.
func _gate(center: Vector3, width: float, height: float, thickness: float, along_x: bool) -> void:
	_gate_count += 1
	var group := "gate%d" % _gate_count
	var post := Vector3(thickness, height, thickness)
	for side in [-1.0, 1.0]:
		var off: Vector3 = Vector3(side * (width * 0.5 - thickness * 0.5), 0, 0) if along_x \
			else Vector3(0, 0, side * (width * 0.5 - thickness * 0.5))
		_box(center + off + Vector3(0, height * 0.5, 0), post, _block, true, Basis.IDENTITY, group)
	var inner := width - thickness * 2.0
	var lintel := Vector3(inner, thickness, thickness) if along_x else Vector3(thickness, thickness, inner)
	_box(center + Vector3(0, height - thickness * 0.5, 0), lintel, _block, true, Basis.IDENTITY, group)


# --- Layout (positions unchanged from ChatGPT's Crucible) -----------------------------

func _geometry() -> void:
	# Cruciform floor around the pit with short wings, built from pieces that
	# touch but never overlap (overlapping faces flicker and draw stray lines).
	for s in [-1.0, 1.0]:
		_span(Vector3(-7, -2, 7 * s), Vector3(7, 0, 30 * s), _floor, "floor")       # N/S arm
		_span(Vector3(7 * s, -2, -7), Vector3(30 * s, 0, 7), _floor, "floor")       # E/W arm
		_span(Vector3(-7, -2, 30 * s), Vector3(7, 0, 34.5 * s), _floor, "floor")    # N/S wing
		_span(Vector3(30 * s, -2, -7), Vector3(34.5 * s, 0, 7), _floor, "floor")    # E/W wing
		for t in [-1.0, 1.0]:
			_span(Vector3(7 * s, -2, 7 * t), Vector3(23 * s, 0, 22 * t), _floor, "floor")
			_span(Vector3(7 * s, -2, 22 * t), Vector3(23 * s, 0, 30 * t), _floor, "floor")
			_span(Vector3(23 * s, -2, 7 * t), Vector3(30 * s, 0, 22 * t), _floor, "floor")

	# Level two: four-sided gallery and the exposed bridge across the pit,
	# also split into touching pieces so its surface is one clean shape.
	for s in [-1.0, 1.0]:
		_span(Vector3(-8.9, 4.3, 8.9 * s), Vector3(8.9, 5.0, 13.1 * s), _bridge, "gallery")
		_span(Vector3(8.9 * s, 4.3, 1.4), Vector3(13.1 * s, 5.0, 8.9), _bridge, "gallery")
		_span(Vector3(8.9 * s, 4.3, -1.4), Vector3(13.1 * s, 5.0, 1.4), _bridge, "gallery")
		_span(Vector3(8.9 * s, 4.3, -8.9), Vector3(13.1 * s, 5.0, -1.4), _bridge, "gallery")
		for t in [-1.0, 1.0]:
			_span(Vector3(8.9 * s, 4.3, 8.9 * t), Vector3(13.1 * s, 5.0, 13.1 * t), _bridge, "gallery")
	_span(Vector3(-8.9, 4.3, -1.4), Vector3(8.9, 5.0, 1.4), _bridge, "gallery")
	# Lower stairs end exactly at the gallery's outer edge.
	_stairs(Vector3(-11.5, 0, -25), Vector3(-11.5, MID, -13.1), 3.5)
	_stairs(Vector3(11.5, 0, 25), Vector3(11.5, MID, 13.1), 3.5)

	# Level three: two crowns on top of square towers.
	# Upper stairs climb from the gallery edge to a landing beside each crown.
	# (The old diagonal route ran in under the crown and players got stuck.)
	for s in [-1.0, 1.0]:
		_stairs(Vector3(7.2 * s, MID, 13.1 * s), Vector3(7.2 * s, TOP, 23.1 * s), 3.2)
		# Crown + walkway: stair top -> end landing -> side path -> crown. Nothing
		# hangs over the stairs (head room), and every seam is a full shared side.
		var g := "crown%d" % int(s)
		_span(Vector3(11.75 * s, 9.3, 20.0 * s), Vector3(22.25 * s, 10.0, 22.25 * s), _block, g)
		_span(Vector3(11.75 * s, 9.3, 13.75 * s), Vector3(22.25 * s, 10.0, 20.0 * s), _block, g)
		_span(Vector3(9.1 * s, 9.3, 20.0 * s), Vector3(11.75 * s, 10.0, 22.25 * s), _block, g)
		_span(Vector3(9.1 * s, 9.3, 22.25 * s), Vector3(11.75 * s, 10.0, 23.1 * s), _block, g)
		_span(Vector3(9.1 * s, 9.3, 23.1 * s), Vector3(11.75 * s, 10.0, 25.1 * s), _block, g)
		_span(Vector3(5.2 * s, 9.3, 23.1 * s), Vector3(9.1 * s, 10.0, 25.1 * s), _block, g)
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
			Vector3(0, 1.0, -20), Vector3(0, 1.0, 20),  # moved: health and a spawn sat inside them
			Vector3(-23, 1.0, -15), Vector3(23, 1.0, 15)]:
		_box(at, Vector3(2.7, 2.0, 2.7), _block)


func _details() -> void:
	# Girders under the gallery.
	for z in [-11.0, 0.0, 11.0]:
		_box(Vector3(0, 4.15, z), Vector3(24, 0.3, 0.4), _dark, false)
	for x in [-11.0, 11.0]:
		_box(Vector3(x, 4.16, 0), Vector3(0.38, 0.28, 20), _dark, false)
	# Gallery arches over the centre crossing.
	for x in [-11.0, 11.0]:
		_gate(Vector3(x, MID, 0), 5.9, 4.4, 0.6, false)
	# Portal frames on the tower crowns (rail perch) and at the four wing ends.
	_gate(Vector3(-16.5, TOP, -21.6), 6.0, 5.2, 0.9, true)
	_gate(Vector3(16.5, TOP, 21.6), 6.0, 5.2, 0.9, true)
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
	for x in [-6.0, 0.0, 6.0]:
		for z in [-12.3, -9.7, 9.7, 12.3]:
			_mesh(_boxmesh(Vector3(2.4, 0.05, 0.24)), Vector3(x, 4.27, z), _lamp)


func _boxmesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## No-collision towers beyond the playable arena; built by a reusable generator.
func _backdrop() -> void:
	var backdrop := MegastructureBackdrop.new()
	backdrop.name = "MegastructureBackdrop"
	add_child(backdrop)


func _navigation_links() -> void:
	_link(Vector3(-11.5, LOWER, -25.5), Vector3(-11.5, MID, -12.6))
	_link(Vector3(11.5, LOWER, 25.5), Vector3(11.5, MID, 12.6))
	_link(Vector3(-7.2, MID, -12.6), Vector3(-7.2, TOP, -23.1))
	_link(Vector3(7.2, MID, 12.6), Vector3(7.2, TOP, 23.1))


func _link(from: Vector3, to: Vector3) -> void:
	var link := NavigationLink3D.new()
	link.start_position = from + Vector3(0, 0.35, 0)
	link.end_position = to + Vector3(0, 0.35, 0)
	link.bidirectional = true
	add_child(link)


func _lighting() -> void:
	# High, slightly warm sun behind the haze: soft shadows and gentle light shafts.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.97, 0.91)
	sun.light_energy = 2.2
	sun.light_angular_distance = 2.5
	sun.light_volumetric_fog_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_blur = 2.2
	sun.shadow_opacity = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	# Cool bounce from the opposite side keeps the shadowed faces soft and readable.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(-30, 140, 0)
	fill.light_color = Color(0.82, 0.86, 0.93)
	fill.light_energy = 0.32
	fill.light_volumetric_fog_energy = 0.0
	add_child(fill)
	for at in [Vector3(-11, 4.0, -11), Vector3(11, 4.0, 11), Vector3(-11, 4.0, 11), Vector3(11, 4.0, -11)]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = Color(1.0, 0.98, 0.95)
		light.light_energy = 0.5
		light.light_volumetric_fog_energy = 0.0
		light.omni_range = 8.0
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
	# A thin tiled skin just in front of the floor's edge, full height, so the
	# whole wall glows evenly (2 cm gap: no overlapping faces, no flicker).
	for side in [-1.0, 1.0]:
		_span(Vector3(6.98 * side, -4.4, -6.98), Vector3(7.0 * side, -0.01, 6.98), _pit_wall, "pit", false)
		_span(Vector3(-6.98, -4.4, 6.98 * side), Vector3(6.98, -0.01, 7.0 * side), _pit_wall, "pit", false)
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
	# No ammo boxes: the machinegun has infinite ammo, other weapons refill when picked up.
