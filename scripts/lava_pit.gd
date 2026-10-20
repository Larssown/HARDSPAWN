class_name LavaPit
extends Node3D
## Self-contained visual and gameplay node for The Crucible's central shaft.

const SURFACE_SIZE := 13.55
const SURFACE_Y := -3.85

var kill_zone: LavaKillZone


func build() -> void:
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(SURFACE_SIZE, SURFACE_SIZE)
	surface.mesh = plane
	surface.position.y = SURFACE_Y
	var lava_material := ShaderMaterial.new()
	lava_material.shader = preload("res://assets/shaders/lava_shader.gdshader")
	surface.material_override = lava_material
	add_child(surface)
	var rim_material := StandardMaterial3D.new()
	rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_material.albedo_color = Color(1.0, 0.45, 0.08)
	rim_material.emission_enabled = true
	rim_material.emission = Color(1.0, 0.15, 0.01)
	rim_material.emission_energy_multiplier = 3.4
	for side in [-1.0, 1.0]:
		_add_rim(Vector3(side * 7.15, 0.025, 0), Vector3(0.12, 0.05, 13.9), rim_material)
		_add_rim(Vector3(0, 0.025, side * 7.15), Vector3(13.9, 0.05, 0.12), rim_material)

	var embers := GPUParticles3D.new()
	embers.name = "Embers"
	embers.position.y = SURFACE_Y + 0.08
	embers.amount = 42
	embers.lifetime = 1.4
	embers.fixed_fps = 30
	embers.visibility_aabb = AABB(Vector3(-7, -1, -7), Vector3(14, 6, 14))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(6.1, 0.02, 6.1)
	process.direction = Vector3.UP
	process.spread = 24.0
	process.gravity = Vector3(0, -1.6, 0)
	process.initial_velocity_min = 1.3
	process.initial_velocity_max = 3.3
	embers.process_material = process
	var spark := SphereMesh.new()
	spark.radius = 0.045
	spark.height = 0.09
	spark.radial_segments = 6
	spark.rings = 3
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1.0, 0.38, 0.04)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.26, 0.02)
	spark_material.emission_energy_multiplier = 3.0
	spark.material = spark_material
	embers.draw_pass_1 = spark
	add_child(embers)

	var light := OmniLight3D.new()
	light.name = "LavaLight"
	light.position.y = SURFACE_Y + 1.6
	light.light_color = Color(1.0, 0.27, 0.055)
	light.light_energy = 4.0
	light.omni_range = 15.0
	light.shadow_enabled = false
	add_child(light)

	kill_zone = LavaKillZone.new()
	kill_zone.name = "KillZone"
	kill_zone.position.y = SURFACE_Y - 0.45
	var shape := BoxShape3D.new()
	shape.size = Vector3(SURFACE_SIZE - 0.15, 1.0, SURFACE_SIZE - 0.15)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	kill_zone.add_child(collider)
	add_child(kill_zone)


func _add_rim(at: Vector3, size: Vector3, material: Material) -> void:
	var rim := MeshInstance3D.new()
	rim.name = "HotRim"
	rim.position = at
	var box := BoxMesh.new()
	box.size = size
	rim.mesh = box
	rim.material_override = material
	add_child(rim)
