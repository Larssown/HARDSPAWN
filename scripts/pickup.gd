class_name PickupNode
extends Node3D
## A floating, spinning item: health (+25), mega health (+100) or armor (+50).

const COLORS := {"health": Color(0.3, 1.0, 0.4), "mega": Color(0.3, 0.6, 1.0), "armor": Color(1.0, 0.8, 0.2)}

var kind := "health"
var available := true
var timer := 0.0
var _item: Node3D
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_t = randf() * TAU
	var col: Color = COLORS[kind]
	var mat := Fx.neon_material(col, 3.0)
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.6
	bc.bottom_radius = 0.65
	bc.height = 0.05
	base.mesh = bc
	base.material_override = Fx.neon_material(col, 0.8)
	base.position.y = 0.03
	add_child(base)
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
			_mesh(_box(Vector3(0.9, 0.1, 0.1)), Fx.neon_material(Color.WHITE, 2.0))
		"armor":
			_mesh(_box(Vector3(0.55, 0.6, 0.14)), mat)
			_mesh(_box(Vector3(0.62, 0.12, 0.18)), Fx.neon_material(Color.WHITE, 1.5))
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 1.0
	_light.omni_range = 3.5
	_light.position.y = 1.0
	add_child(_light)


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


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
