class_name Hud
extends CanvasLayer
## In-game overlay: crosshair, health/armor, weapon, timer, frags, kill feed,
## scoreboard (hold Tab), pause menu (Esc) and the end-of-match screen.

class Crosshair extends Control:
	var hit_t := 0.0

	func _process(delta: float) -> void:
		hit_t = maxf(hit_t - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1, 1, 1, 0.9)
		draw_circle(c, 2.0, col)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * 7.0, c + d * 14.0, col, 2.0)
		if hit_t > 0.0:
			var hc := Color(1.0, 0.35, 0.3, clampf(hit_t / 0.15, 0.0, 1.0))
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 7.0, c + d * 15.0, hc, 3.0)


var player: Player = null
var root: Control
var crosshair: Crosshair
var vignette: ColorRect
var lbl_health: Label
var lbl_armor: Label
var lbl_weapon: Label
var weapon_slots: Array[Label] = []
var lbl_timer: Label
var lbl_frags: Label
var lbl_rank: Label
var lbl_speed: Label
var lbl_center: Label
var lbl_sub: Label
var killfeed: VBoxContainer
var scoreboard: PanelContainer
var score_title: Label
var score_grid: GridContainer
var score_footer: Label
var pause_panel: PanelContainer
var _center_t := 0.0
var _vignette_a := 0.0
var _prev_time := 9999.0
var _killer_name := ""


func _ready() -> void:
	layer = 10
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Futura", "Avenir Next", "Helvetica Neue"])
	font.font_weight = 700
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 22
	root.theme = th
	add_child(root)

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(1, 0, 0, 0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	crosshair = Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	# Bottom left: health & armor
	var vitals := VBoxContainer.new()
	_anchor(vitals, 0.0, 1.0, Vector2(36, -30), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	root.add_child(vitals)
	lbl_health = _label(vitals, "100", 64, Color.WHITE)
	lbl_armor = _label(vitals, "ARMOR 0", 24, Color(1.0, 0.8, 0.2))

	# Bottom right: weapon
	var wbox := VBoxContainer.new()
	wbox.alignment = BoxContainer.ALIGNMENT_END
	_anchor(wbox, 1.0, 1.0, Vector2(-36, -30), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	root.add_child(wbox)
	lbl_weapon = _label(wbox, "", 30, Color.WHITE)
	lbl_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_END
	slots.add_theme_constant_override("separation", 14)
	wbox.add_child(slots)
	for i in Weapons.LIST.size():
		weapon_slots.append(_label(slots, "%d %s" % [i + 1, Weapons.LIST[i].short], 20, Color.WHITE))

	# Top: timer, frags, rank
	lbl_timer = _label(root, "10:00", 40, Color.WHITE)
	lbl_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(lbl_timer, 0.5, 0.0, Vector2(0, 14), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	var fbox := VBoxContainer.new()
	_anchor(fbox, 1.0, 0.0, Vector2(-36, 18), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	root.add_child(fbox)
	lbl_frags = _label(fbox, "FRAGS 0", 34, Color.WHITE)
	lbl_frags.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_rank = _label(fbox, "", 20, Color(0.7, 0.8, 1.0))
	lbl_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	killfeed = VBoxContainer.new()
	_anchor(killfeed, 0.0, 0.0, Vector2(30, 20), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	root.add_child(killfeed)

	lbl_speed = _label(root, "", 16, Color(1, 1, 1, 0.55))
	lbl_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(lbl_speed, 0.5, 1.0, Vector2(0, -22), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)

	lbl_center = _label(root, "", 34, Color.WHITE)
	lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(lbl_center, 0.5, 0.5, Vector2(0, -150), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	lbl_sub = _label(root, "", 26, Color(1, 0.5, 0.45))
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(lbl_sub, 0.5, 0.5, Vector2(0, 70), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)

	_build_scoreboard()
	_build_pause()

	Game.kill_event.connect(_on_kill)
	Game.hit_confirmed.connect(_on_hit)
	Game.players_changed.connect(_refresh_scoreboard)
	Game.match_ended.connect(_on_match_ended)
	Game.match_restarted.connect(_on_match_restarted)


func bind_player(p: Player) -> void:
	player = p


func _anchor(c: Control, ax: float, ay: float, offset: Vector2, gh: Control.GrowDirection, gv: Control.GrowDirection) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = offset.x
	c.offset_right = offset.x
	c.offset_top = offset.y
	c.offset_bottom = offset.y
	c.grow_horizontal = gh
	c.grow_vertical = gv
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _label(parent: Control, text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _panel_style(border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.07, 0.85)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(24)
	return sb


func _build_scoreboard() -> void:
	scoreboard = PanelContainer.new()
	scoreboard.add_theme_stylebox_override("panel", _panel_style(Color(0.2, 0.8, 1.0)))
	_anchor(scoreboard, 0.5, 0.5, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	scoreboard.custom_minimum_size = Vector2(560, 0)
	scoreboard.visible = false
	root.add_child(scoreboard)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	scoreboard.add_child(vb)
	score_title = _label(vb, "SCOREBOARD", 34, Color(0.2, 0.8, 1.0))
	score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_grid = GridContainer.new()
	score_grid.columns = 4
	score_grid.add_theme_constant_override("h_separation", 30)
	score_grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(score_grid)
	score_footer = _label(vb, "", 20, Color(0.8, 0.8, 0.8))
	score_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _refresh_scoreboard() -> void:
	for c in score_grid.get_children():
		c.queue_free()
	for h in ["#", "NAME", "FRAGS", "DEATHS"]:
		_label(score_grid, h, 18, Color(0.6, 0.65, 0.75))
	var rank := 0
	for s in Game.sorted_scores():
		rank += 1
		var me: bool = player != null and s.id == player.peer_id
		var col: Color = s.color
		_label(score_grid, str(rank), 22, Color.WHITE)
		_label(score_grid, ("> " if me else "") + str(s.name), 22, col)
		_label(score_grid, str(s.kills), 22, Color.WHITE)
		_label(score_grid, str(s.deaths), 22, Color(0.8, 0.8, 0.8))


func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.3, 0.6)))
	_anchor(pause_panel, 0.5, 0.5, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.custom_minimum_size = Vector2(420, 0)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	pause_panel.add_child(vb)
	var t := _label(vb, "PAUSED", 36, Color(1.0, 0.3, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if multiplayer.is_server():
		var ip := _label(vb, "Friends join this IP:  %s" % Game.get_lan_ip(), 20, Color(0.7, 0.9, 1.0))
		ip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sens_lbl := _label(vb, "", 18, Color.WHITE)
	var sens := HSlider.new()
	sens.min_value = 0.02
	sens.max_value = 0.4
	sens.step = 0.005
	sens.value = float(Game.settings.sensitivity)
	sens_lbl.text = "Mouse sensitivity  %.3f" % sens.value
	sens.value_changed.connect(func(v: float):
		Game.settings.sensitivity = v
		sens_lbl.text = "Mouse sensitivity  %.3f" % v
		Game.save_settings())
	vb.add_child(sens)
	var resume := Button.new()
	resume.text = "RESUME"
	resume.add_theme_font_size_override("font_size", 24)
	resume.pressed.connect(_set_paused.bind(false))
	vb.add_child(resume)
	var leave := Button.new()
	leave.text = "LEAVE GAME"
	leave.add_theme_font_size_override("font_size", 24)
	leave.pressed.connect(func(): Game.leave_game())
	vb.add_child(leave)


func _set_paused(v: bool) -> void:
	pause_panel.visible = v
	if v:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Game.capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not pause_panel.visible)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not pause_panel.visible \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Game.capture_mouse()
		get_viewport().set_input_as_handled()


func flash_damage() -> void:
	_vignette_a = 0.35


func _show_center(text: String, col: Color, time := 2.0) -> void:
	lbl_center.text = text
	lbl_center.add_theme_color_override("font_color", col)
	_center_t = time


func _on_hit(dmg: float) -> void:
	crosshair.hit_t = 0.15
	Sfx.play_2d("hit", -4.0, clampf(1.4 - dmg / 120.0, 0.7, 1.4))


func _on_kill(victim_id: int, killer_id: int, weapon: int) -> void:
	var vname: String = Game.players[victim_id].name if Game.players.has(victim_id) else "?"
	var kname: String = Game.players[killer_id].name if Game.players.has(killer_id) else vname
	var w: String = Weapons.LIST[weapon].short
	var entry := _label(killfeed, "", 20, Color.WHITE)
	if killer_id == victim_id:
		entry.text = "%s blew up" % vname
	else:
		entry.text = "%s  [%s]  %s" % [kname, w, vname]
	get_tree().create_timer(5.0).timeout.connect(entry.queue_free)
	while killfeed.get_child_count() > 5:
		killfeed.get_child(0).free()
	if player == null:
		return
	if killer_id == player.peer_id and victim_id != player.peer_id:
		Sfx.play_2d("kill", -2.0)
		_show_center("YOU FRAGGED %s" % vname.to_upper(), Color(1.0, 0.85, 0.3))
	if victim_id == player.peer_id:
		_killer_name = "YOU BLEW YOURSELF UP" if killer_id == victim_id else "FRAGGED BY %s" % kname.to_upper()


func _on_match_ended() -> void:
	var scores := Game.sorted_scores()
	if scores.size() > 0:
		var winner: Dictionary = scores[0]
		score_title.text = "%s WINS!" % str(winner.name).to_upper()
		score_title.add_theme_color_override("font_color", winner.color)
	Sfx.play_2d("match_end", -2.0)


func _on_match_restarted() -> void:
	score_title.text = "SCOREBOARD"
	score_title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	_prev_time = 9999.0
	_show_center("FIGHT!", Color(1.0, 0.3, 0.3))


func _process(delta: float) -> void:
	_vignette_a = maxf(_vignette_a - delta * 1.2, 0.0)
	vignette.color = Color(0.9, 0.0, 0.0, _vignette_a)

	var t := int(ceil(Game.time_left))
	lbl_timer.text = "%d:%02d" % [t / 60, t % 60]
	lbl_timer.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if t <= 30 else Color.WHITE)
	if Game.time_left < 60.0 and _prev_time >= 60.0 and not Game.match_over:
		_show_center("1 MINUTE REMAINING", Color(1, 0.6, 0.2))
		Sfx.play_2d("minute")
	_prev_time = Game.time_left

	if _center_t > 0.0:
		_center_t -= delta
		lbl_center.modulate.a = clampf(_center_t / 0.5, 0.0, 1.0)

	scoreboard.visible = Game.match_over or (Input.is_action_pressed("scoreboard") and not pause_panel.visible)
	if Game.match_over:
		score_footer.text = "Next match starting soon..."
	else:
		score_footer.text = ""

	if player == null:
		return
	var hp := int(ceil(player.health))
	lbl_health.text = str(maxi(hp, 0))
	var hcol := Color.WHITE
	if hp > 100:
		hcol = Color(0.4, 0.7, 1.0)
	elif hp <= 25:
		hcol = Color(1.0, 0.25, 0.2)
	elif hp <= 50:
		hcol = Color(1.0, 0.65, 0.2)
	lbl_health.add_theme_color_override("font_color", hcol)
	lbl_armor.text = "ARMOR %d" % int(ceil(player.armor))
	lbl_armor.visible = player.armor > 0.0
	var w: Dictionary = Weapons.LIST[player.weapon]
	lbl_weapon.text = w.name
	lbl_weapon.add_theme_color_override("font_color", w.color)
	for i in weapon_slots.size():
		weapon_slots[i].modulate = Color(1, 1, 1, 1) if i == player.weapon else Color(1, 1, 1, 0.35)

	var ups := Vector2(player.velocity.x, player.velocity.z).length() * 39.37
	lbl_speed.text = "%d ups" % int(ups)

	if Game.players.has(player.peer_id):
		lbl_frags.text = "FRAGS %d" % int(Game.players[player.peer_id].kills)
		var scores := Game.sorted_scores()
		for i in scores.size():
			if scores[i].id == player.peer_id:
				lbl_rank.text = "%s of %d" % [_ordinal(i + 1), scores.size()]
				break

	crosshair.visible = not player.dead
	lbl_sub.text = (_killer_name + "\nRespawning...") if player.dead else ""


func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n
