extends Control
## Main menu: host a game (with bots), find/join LAN games, and settings.

const TIME_OPTIONS := [300, 600, 900, 1200]
const FPS_OPTIONS := [30, 60, 120, 0]
const ACCENT := Color(1.0, 0.33, 0.24)      # logo red
const ACCENT2 := Color(0.82, 0.86, 0.88)    # logo metal
const LOGO := preload("res://assets/branding/hardspawn_logo.png")

var udp := PacketPeerUDP.new()
var found := {}  # ip -> {info, t}
var game_list: ItemList
var ip_edit: LineEdit
var status: Label
var _refresh_t := 0.0
var _listening := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Futura", "Avenir Next", "Helvetica Neue"])
	font.font_weight = 700
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 20
	theme = th

	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.063, 0.086, 0.114))
	grad.set_color(1, Color(0.11, 0.035, 0.04))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	center.add_child(vb)

	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(1124, 270)
	vb.add_child(logo)
	var sub := _label(vb, "LAN ARENA DEATHMATCH", 22, Color(0.7, 0.74, 0.78))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	vb.add_child(row)
	_build_host(_panel(row, "HOST GAME", ACCENT))
	_build_join(_panel(row, "JOIN GAME", ACCENT2))
	_build_settings(_panel(row, "SETTINGS", Color(1.0, 0.75, 0.2)))

	status = _label(vb, Game.menu_message, 22, Color(1.0, 0.6, 0.4))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Game.menu_message = ""
	Game.menu_status.connect(func(t: String): status.text = t)

	_listening = udp.bind(Game.DISCOVERY_PORT) == OK


func _exit_tree() -> void:
	udp.close()


func _label(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _panel(parent: Control, title: String, col: Color) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.065, 0.085, 0.92)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(22)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(360, 420)
	parent.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	_label(vb, title, 30, col)
	return vb


func _button(parent: Control, text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(0, 54)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.55 if state == "normal" else (0.3 if state == "hover" else 0.1))
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state, sb)
	parent.add_child(b)
	return b


func _option(parent: Control, caption: String, items: Array, selected: int, on_pick: Callable) -> void:
	_label(parent, caption, 17, Color(0.7, 0.75, 0.85))
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(str(it))
	ob.select(selected)
	ob.item_selected.connect(on_pick)
	parent.add_child(ob)


func _slider(parent: Control, caption: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> void:
	var l := _label(parent, "", 17, Color(0.7, 0.75, 0.85))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	l.text = caption % value
	s.value_changed.connect(func(v: float):
		l.text = caption % v
		on_change.call(v))
	parent.add_child(s)


func _build_host(vb: VBoxContainer) -> void:
	_option(vb, "Bots", range(0, Game.MAX_TOTAL), clampi(int(Game.match_cfg.bots), 0, Game.MAX_TOTAL - 1),
		func(i: int): Game.match_cfg.bots = i)
	_option(vb, "Bot skill", ["Easy", "Normal", "Hard"], clampi(int(Game.match_cfg.difficulty), 0, 2),
		func(i: int): Game.match_cfg.difficulty = i)
	var time_names := []
	for t in TIME_OPTIONS:
		time_names.append("%d minutes" % (t / 60))
	_option(vb, "Time limit", time_names, maxi(TIME_OPTIONS.find(int(Game.match_cfg.time_limit)), 0),
		func(i: int): Game.match_cfg.time_limit = TIME_OPTIONS[i])
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	_button(vb, "HOST", ACCENT).pressed.connect(_on_host)


func _build_join(vb: VBoxContainer) -> void:
	_label(vb, "Games on your network", 17, Color(0.7, 0.75, 0.85))
	game_list = ItemList.new()
	game_list.custom_minimum_size = Vector2(0, 150)
	game_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_list.item_activated.connect(func(_i: int): _on_join())
	game_list.item_selected.connect(func(i: int): ip_edit.text = str(game_list.get_item_metadata(i)))
	vb.add_child(game_list)
	_label(vb, "...or type the host's IP", 17, Color(0.7, 0.75, 0.85))
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.1.23"
	vb.add_child(ip_edit)
	_button(vb, "JOIN", ACCENT2).pressed.connect(_on_join)


func _build_settings(vb: VBoxContainer) -> void:
	_label(vb, "Player name", 17, Color(0.7, 0.75, 0.85))
	var name_edit := LineEdit.new()
	name_edit.text = str(Game.settings.name)
	name_edit.max_length = 16
	name_edit.text_changed.connect(func(t: String):
		Game.settings.name = t
		Game.save_settings())
	vb.add_child(name_edit)
	_slider(vb, "Mouse sensitivity  %.3f", 0.02, 0.4, 0.005, float(Game.settings.sensitivity),
		func(v: float):
			Game.settings.sensitivity = v
			Game.save_settings())
	_slider(vb, "Field of view  %d", 80, 120, 1, float(Game.settings.fov),
		func(v: float):
			Game.settings.fov = v
			Game.save_settings())
	_slider(vb, "Volume  %.2f", 0.0, 1.0, 0.05, float(Game.settings.volume),
		func(v: float):
			Game.settings.volume = v
			Game.apply_settings()
			Game.save_settings())
	var fps_names := ["30", "60", "120", "Unlimited"]
	_option(vb, "Max FPS", fps_names, maxi(FPS_OPTIONS.find(int(Game.settings.fps_cap)), 0),
		func(i: int):
			Game.settings.fps_cap = FPS_OPTIONS[i]
			Game.apply_settings()
			Game.save_settings())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	_button(vb, "QUIT", Color(0.6, 0.6, 0.7)).pressed.connect(func(): get_tree().quit())


func _on_host() -> void:
	Game.save_settings()
	if Game.host_game() != OK:
		status.text = "Could not host. Is another game already running on this Mac?"


func _on_join() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip == "":
		status.text = "Pick a game in the list or type an IP."
		return
	Game.save_settings()
	if Game.join_game(ip) != OK:
		status.text = "Could not connect to %s." % ip
	else:
		status.text = "Connecting to %s..." % ip


func _process(delta: float) -> void:
	if not _listening:
		return
	var now := Time.get_ticks_msec() / 1000.0
	while udp.get_available_packet_count() > 0:
		var pkt := udp.get_packet()
		var ip := udp.get_packet_ip()
		var data = JSON.parse_string(pkt.get_string_from_utf8())
		if data is Dictionary and data.get("game") == "HARDSPAWN":
			found[ip] = {"info": data, "t": now}
	_refresh_t -= delta
	if _refresh_t > 0.0:
		return
	_refresh_t = 1.0
	for ip in found.keys():
		if now - float(found[ip].t) > 3.5:
			found.erase(ip)
	var selected_ip := ip_edit.text
	game_list.clear()
	for ip in found:
		var info: Dictionary = found[ip].info
		var i := game_list.add_item("%s's game   %d/%d   (%s)" % [info.host, int(info.total), int(info.max), ip])
		game_list.set_item_metadata(i, ip)
		if ip == selected_ip:
			game_list.select(i)
