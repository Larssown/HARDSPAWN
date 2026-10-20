class_name MegastructureBackdrop
extends Node3D
## Deterministic, decorative silhouettes outside the playable arena.
## BoxMesh instances have no collision. Their silhouettes cast volumetric shafts.

@export_range(20, 40, 1) var tower_count := 32
@export var inner_radius := 80.0
@export var outer_radius := 350.0
@export var width_range := Vector2(15.0, 50.0)
@export var depth_range := Vector2(15.0, 50.0)
@export var top_range := Vector2(50.0, 300.0)
@export var base_y := -1000.0
@export var layout_seed := 4719
@export var tint := Color(0.78, 0.78, 0.77)


func _ready() -> void:
	generate()


func generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0

	for i in tower_count:
		# One tower per angular sector keeps the silhouette around the whole map.
		var angle := TAU * (float(i) + rng.randf_range(-0.36, 0.36)) / float(tower_count)
		var radius := rng.randf_range(inner_radius, outer_radius)
		var top_y := rng.randf_range(top_range.x, top_range.y)
		var height := top_y - base_y
		var size := Vector3(
			rng.randf_range(width_range.x, width_range.y),
			height,
			rng.randf_range(depth_range.x, depth_range.y)
		)
		var tower := MeshInstance3D.new()
		tower.name = "Monolith%02d" % i
		var box := BoxMesh.new()
		box.size = size
		tower.mesh = box
		tower.material_override = material
		tower.position = Vector3(cos(angle) * radius, (base_y + top_y) * 0.5,
			sin(angle) * radius)
		tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tower.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(tower)
