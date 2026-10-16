class_name Rocket
extends Node3D
## A rocket. The shooter's machine owns the "real" one and reports the explosion to the
## host; everyone else flies a visual copy that the host's explosion message removes.

const SPEED := 30.0

var owner_id := 0
var dir := Vector3.FORWARD
var real := false
var _life := 6.0
var _done := false
var _exclude: Array[RID] = []
var _trail: CPUParticles3D


func setup(o: int, d: Vector3, is_real: bool) -> void:
	owner_id = o
	dir = d.normalized()
	real = is_real


func _ready() -> void:
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	basis = Basis.looking_at(dir, up)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.2, 0.22)
	metal.metallic = 0.8
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.07
	cm.height = 0.5
	body.mesh = cm
	body.material_override = metal
	body.rotation.x = PI * 0.5
	add_child(body)
	var glow := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	glow.mesh = sm
	glow.material_override = Fx.glow_material(Color(1.0, 0.55, 0.2), 4.0)
	glow.position = Vector3(0, 0, 0.28)
	add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position = Vector3(0, 0, 0.3)
	add_child(light)

	_trail = CPUParticles3D.new()
	_trail.local_coords = false
	_trail.amount = 50
	_trail.lifetime = 0.55
	_trail.direction = Vector3(0, 0, 1)
	_trail.spread = 25.0
	_trail.initial_velocity_min = 0.5
	_trail.initial_velocity_max = 1.5
	_trail.gravity = Vector3(0, 0.5, 0)
	_trail.scale_amount_min = 0.7
	_trail.scale_amount_max = 1.5
	var tm := SphereMesh.new()
	tm.radius = 0.09
	tm.height = 0.18
	tm.radial_segments = 6
	tm.rings = 3
	_trail.mesh = tm
	_trail.material_override = Fx.glow_material(Color(1.0, 0.5, 0.2), 1.6)
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.9, 0.6, 1))
	g.set_color(1, Color(0.3, 0.3, 0.35, 0))
	_trail.color_ramp = g
	_trail.position = Vector3(0, 0, 0.3)
	add_child(_trail)
	_trail.emitting = true

	var owner_player := Game.world.get_player(owner_id)
	if owner_player:
		_exclude = [owner_player.get_rid()]


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life -= delta
	var from := global_position
	var to := from + dir * SPEED * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 3, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hit_pos: Vector3 = hit.position
		var hit_normal: Vector3 = hit.normal
		var victim := hit.collider as Player
		_detonate(hit_pos + hit_normal * 0.15, victim.peer_id if victim else 0)
	elif _life <= 0.0:
		_detonate(from, 0)
	else:
		global_position = to


func _detonate(pos: Vector3, direct_id: int) -> void:
	_done = true
	global_position = pos
	_trail.emitting = false
	_trail.reparent(get_parent())
	Fx.free_after(_trail, 0.7)
	visible = false
	Fx.free_after(self, 2.0)
	if real:
		Game.report_explosion(owner_id, pos, direct_id, name)
