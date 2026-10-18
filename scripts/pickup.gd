class_name PickupNode
extends Node3D
## A fixed-location item. Weapon pickups share the player's imported models.

const COLORS := {"health": Color(0.35, 0.8, 0.42), "mega": Color(0.4, 0.65, 0.9),
	"armor": Color(0.92, 0.68, 0.28), "ammo": Color(1.0, 0.78, 0.32)}

var kind := "health"
var weapon_id := Weapons.SHOTGUN
var available := true
var timer := 0.0
var _item: Node3D
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_t = randf() * TAU
	var col: Color = Weapons.LIST[weapon_id].color if kind == "weapon" else COLORS[kind]
	var mat := _material(col, 0.5)
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.6
	bc.bottom_radius = 0.65
	bc.height = 0.05
	base.mesh = bc
	base.material_override = _material(Color(0.10, 0.12, 0.13), 0.65)
	base.position.y = 0.06
	add_child(base)
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.62
	rc.bottom_radius = 0.62
	rc.height = 0.025
	rim.mesh = rc
	rim.material_override = _material(col.darkened(0.18), 0.35)
	rim.position.y = 0.105
	add_child(rim)
	var center := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.49
	cc.bottom_radius = 0.49
	cc.height = 0.03
	center.mesh = cc
	center.material_override = _material(Color(0.08, 0.10, 0.11), 0.62)
	center.position.y = 0.13
	add_child(center)
	_item = Node3D.new()
	_item.position.y = 0.9
	add_child(_item)
	match kind:
		"health":
			_mesh(_box(Vector3(0.5, 0.16, 0.16)), mat)
			_mesh(_box(Vector3(0.16, 0.5, 0.16)), mat)
		"mega":
			var s := SphereMesh.new()
			s.radius = 0.38
			s.height = 0.76
			_mesh(s, mat)
			_mesh(_box(Vector3(0.9, 0.1, 0.1)), _material(Color(0.9, 0.9, 0.86), 0.55))
		"armor":
			_mesh(_box(Vector3(0.55, 0.6, 0.14)), mat)
			_mesh(_box(Vector3(0.62, 0.12, 0.18)), _material(Color(0.9, 0.9, 0.86), 0.55))
		"ammo":
			_mesh(_box(Vector3(0.65, 0.36, 0.46)), _material(Color(0.15, 0.17, 0.17), 0.65))
			_mesh(_box(Vector3(0.55, 0.07, 0.48)), mat)
			for x in [-0.19, 0.0, 0.19]:
				var round_mesh := CylinderMesh.new()
				round_mesh.top_radius = 0.065
				round_mesh.bottom_radius = 0.065
				round_mesh.height = 0.35
				var round_visual := MeshInstance3D.new()
				round_visual.mesh = round_mesh
				round_visual.material_override = mat
				round_visual.position = Vector3(x, 0.28, 0)
				_item.add_child(round_visual)
		"weapon":
			var visual := WeaponVisual.create(weapon_id)
			visual.scale = Vector3.ONE * 0.55
			_item.add_child(visual)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 0.65
	_light.omni_range = 2.8
	_light.position.y = 1.0
	add_child(_light)


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _material(col: Color, metal: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metal
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = col * 0.25
	return mat


func _mesh(mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	_item.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_item.rotation.y = _t * 2.0
	_item.position.y = 0.9 + sin(_t * 2.5) * 0.12


func set_available(v: bool) -> void:
	available = v
	_item.visible = v
	_light.visible = v
