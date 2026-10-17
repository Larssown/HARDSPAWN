class_name WeaponVisual
extends RefCounted
## Low-poly Quaternius models. The supplied guns point toward local +X.

const SCENES := [
	"res://assets/models/weapons/AR_4.gltf",
	"res://assets/models/weapons/Grenade_3.gltf",
	"res://assets/models/weapons/Grenade_2.gltf",
	"res://assets/models/weapons/Sniper_1.gltf",
]


static func create(weapon_id: int) -> Node3D:
	var scene := load(SCENES[weapon_id]) as PackedScene
	var model := scene.instantiate() as Node3D
	_style(model, weapon_id)
	return model


static func _style(node: Node, weapon_id: int) -> void:
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in visual.mesh.get_surface_count():
			var original := visual.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := StandardMaterial3D.new()
			var material_name := original.resource_name.to_lower()
			if material_name == "black":
				material.albedo_color = Color(0.055, 0.065, 0.07)
			elif material_name == "grey":
				material.albedo_color = Color(0.17, 0.18, 0.19)
			elif material_name == "white":
				material.albedo_color = Color(0.34, 0.35, 0.35)
			else:
				material.albedo_color = Weapons.LIST[weapon_id].color.darkened(0.38)
				material.emission_enabled = true
				material.emission = material.albedo_color * 0.2
			material.metallic = 0.48
			material.roughness = 0.57
			visual.set_surface_override_material(surface, material)
	for child in node.get_children():
		_style(child, weapon_id)
