class_name BotBrain
extends RefCounted
## Bot AI (runs on the host). Fills the same inputs a human would: move, jump, fire, aim.
## Finds the nearest visible enemy, strafes and shoots with human-like aim lag;
## otherwise roams the navmesh, chases the last seen enemy or grabs health.

const DIFFICULTY := [
	{"turn": 4.0, "error": 0.09, "react": 0.6, "cone": 0.12},    # Easy
	{"turn": 7.0, "error": 0.05, "react": 0.35, "cone": 0.08},   # Normal
	{"turn": 12.0, "error": 0.025, "react": 0.18, "cone": 0.05}, # Hard
]
const PREFERRED_RANGE := {Weapons.MG: 14.0, Weapons.SHOTGUN: 5.0, Weapons.ROCKET: 11.0, Weapons.RAIL: 25.0}

var p: Player
var cfg: Dictionary
var target: Player = null
var _see_t := 0.0
var _lost_t := 99.0
var _last_seen := Vector3.ZERO
var _chase := false
var _path := PackedVector3Array()
var _path_i := 0
var _goal := Vector3.ZERO
var _goal_valid := false
var _repath_t := 0.0
var _scan_t := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _stuck_t := 0.0
var _weapon_t := 0.0
var _aim_offset := Vector3.ZERO
var _aim_offset_t := 0.0
var _aim_err := 1.0


func _init(player: Player) -> void:
	p = player
	cfg = DIFFICULTY[clampi(int(Game.match_cfg.difficulty), 0, DIFFICULTY.size() - 1)]
	_strafe = 1.0 if randf() < 0.5 else -1.0


func think(delta: float) -> void:
	p.in_jump = false
	p.in_fire = false
	if Game.match_over:
		p.in_move = Vector2.ZERO
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.2
		_pick_target()
	if target and target.dead:
		target = null

	var move := Vector3.ZERO
	if target:
		_lost_t = 0.0
		var dist := p.global_position.distance_to(target.global_position)
		_choose_weapon(dist, delta)
		_aim_at(_aim_point(dist), delta)
		_see_t += delta
		var cone: float = cfg.cone * (0.5 if p.weapon == Weapons.RAIL else 1.0)
		if _see_t > float(cfg.react) and _aim_err < cone:
			p.in_fire = true
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe_t = randf_range(0.4, 1.4)
			_strafe = -_strafe if randf() < 0.7 else _strafe
		var to_t := target.global_position - p.global_position
		to_t.y = 0.0
		to_t = to_t.normalized()
		var side := to_t.cross(Vector3.UP)
		var pref: float = PREFERRED_RANGE.get(p.weapon, 12.0)
		var fwd := 0.0
		if dist > pref + 4.0:
			fwd = 1.0
		elif dist < pref - 3.0:
			fwd = -1.0
		move = _avoid_wall((side * _strafe + to_t * fwd).normalized())
		if randf() < delta * 0.8:
			p.in_jump = true
	else:
		_see_t = 0.0
		_lost_t += delta
		move = _follow_path(delta)
		if move != Vector3.ZERO:
			_turn_toward(move, delta)

	var local := Basis(Vector3.UP, p.yaw).inverse() * move
	p.in_move = Vector2(local.x, local.z).limit_length(1.0)
	_check_stuck(delta, move)


func _pick_target() -> void:
	var best: Player = null
	var best_d := 1e9
	for c in Game.world.players_root.get_children():
		var o := c as Player
		if o == null or o == p or o.dead:
			continue
		var d := p.global_position.distance_to(o.global_position)
		if o == target:
			d *= 0.7
		if d < best_d and d < 90.0 and _can_see(o):
			best = o
			best_d = d
	if best != target:
		_see_t = 0.0
		if best == null and target:
			_chase = true
			_goal_valid = false
	target = best
	if target:
		_last_seen = target.global_position


func _can_see(o: Player) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p.head.global_position, o.global_position + Vector3(0, 1.2, 0), 1)
	return p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _aim_point(dist: float) -> Vector3:
	if p.weapon == Weapons.ROCKET:
		var lead := target.velocity * (dist / Rocket.SPEED)
		lead.y = 0.0
		var feet := target.global_position + Vector3(0, 0.2, 0)
		return feet + lead
	return target.global_position + Vector3(0, 1.1, 0)


func _aim_at(point: Vector3, delta: float) -> void:
	_aim_offset_t -= delta
	if _aim_offset_t <= 0.0:
		_aim_offset_t = randf_range(0.25, 0.6)
		_aim_offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * float(cfg.error)
	var dir := (point - p.head.global_position).normalized()
	dir = (dir + _aim_offset).normalized()
	var want_yaw := atan2(-dir.x, -dir.z)
	var want_pitch := asin(clampf(dir.y, -1.0, 1.0))
	var step := float(cfg.turn) * delta
	p.yaw = wrapf(p.yaw + clampf(angle_difference(p.yaw, want_yaw), -step, step), -PI, PI)
	p.pitch += clampf(want_pitch - p.pitch, -step, step)
	_aim_err = absf(angle_difference(p.yaw, want_yaw)) + absf(want_pitch - p.pitch)


func _turn_toward(dir: Vector3, delta: float) -> void:
	var want_yaw := atan2(-dir.x, -dir.z)
	var step := float(cfg.turn) * 0.6 * delta
	p.yaw = wrapf(p.yaw + clampf(angle_difference(p.yaw, want_yaw), -step, step), -PI, PI)
	p.pitch = lerpf(p.pitch, 0.0, minf(delta * 3.0, 1.0))


func _choose_weapon(dist: float, delta: float) -> void:
	_weapon_t -= delta
	if _weapon_t > 0.0:
		return
	_weapon_t = 0.7
	var best := Weapons.MG
	if dist < 7.0 and p.has_weapon(Weapons.SHOTGUN):
		best = Weapons.SHOTGUN
	elif dist >= 18.0 and p.has_weapon(Weapons.RAIL):
		best = Weapons.RAIL
	elif dist >= 5.0 and p.has_weapon(Weapons.ROCKET):
		best = Weapons.ROCKET
	elif dist < 12.0 and p.has_weapon(Weapons.SHOTGUN):
		best = Weapons.SHOTGUN
	elif p.has_weapon(Weapons.RAIL):
		best = Weapons.RAIL
	p.select_weapon(best)


func _clear_ahead(dir: Vector3) -> bool:
	var from := p.global_position + Vector3(0, 0.9, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2.2, 1)
	return p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _avoid_wall(wanted: Vector3) -> Vector3:
	if wanted == Vector3.ZERO or _clear_ahead(wanted):
		return wanted
	var side := wanted.rotated(Vector3.UP, _strafe * PI * 0.5)
	if _clear_ahead(side):
		return side
	side = -side
	if _clear_ahead(side):
		return side
	return -wanted


func _pick_goal() -> Vector3:
	if _chase and _lost_t < 5.0:
		_chase = false
		return _last_seen
	_chase = false
	if p.health < 70.0:
		var best := Vector3.ZERO
		var best_d := 1e9
		for pk in Game.world.pickups:
			if pk.available and pk.kind == "health":
				var d := _route_cost(pk.position)
				if d < best_d:
					best_d = d
					best = pk.position
		if best_d < 1e9:
			return best
	var nearest := Vector3.ZERO
	var nearest_d := 1e9
	for pk in Game.world.pickups:
		if pk.available and pk.kind == "weapon" and not p.has_weapon(pk.weapon_id):
			var d := _route_cost(pk.position)
			if d < nearest_d:
				nearest_d = d
				nearest = pk.position
	if nearest_d < 1e9:
		return nearest
	return Game.world.arena.waypoints.pick_random()


func _route_cost(destination: Vector3) -> float:
	var route := NavigationServer3D.map_get_path(
		p.get_world_3d().navigation_map, p.global_position, destination, true)
	if route.size() < 2:
		return p.global_position.distance_to(destination) + absf(
			p.global_position.y - destination.y) * 6.0
	var length := 0.0
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])
	return length


func _follow_path(delta: float) -> Vector3:
	_repath_t -= delta
	if not _goal_valid or p.global_position.distance_to(_goal) < 2.0:
		_goal = _pick_goal()
		_goal_valid = true
		_repath_t = 0.0
	if _repath_t <= 0.0:
		_path = NavigationServer3D.map_get_path(p.get_world_3d().navigation_map, p.global_position, _goal, true)
		_path_i = 0
		_repath_t = 2.0
	while _path_i < _path.size():
		var d := _path[_path_i] - p.global_position
		d.y = 0.0
		if d.length() < 0.8:
			_path_i += 1
		else:
			return d.normalized()
	if _path.is_empty():
		# Navmesh not ready yet: walk straight at the goal.
		var straight := _goal - p.global_position
		straight.y = 0.0
		return straight.normalized() if straight.length() > 1.0 else Vector3.ZERO
	_goal_valid = false
	return Vector3.ZERO


func _check_stuck(delta: float, wanted: Vector3) -> void:
	var hspeed := Vector2(p.velocity.x, p.velocity.z).length()
	if wanted.length() > 0.5 and hspeed < 1.5:
		_stuck_t += delta
	else:
		_stuck_t = maxf(_stuck_t - delta, 0.0)
	if _stuck_t > 0.7:
		p.in_jump = true
	if _stuck_t > 1.6:
		_stuck_t = 0.0
		_strafe = -_strafe
		_goal_valid = false
		_repath_t = 0.0
