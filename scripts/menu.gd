extends Control
## Image-led main menu. The artwork includes the logo; controls live below it.

const BACKGROUND := preload("res://image/IMG_1617.JPG")
const TIME_OPTIONS := [300, 600, 900, 1200]
const FPS_OPTIONS := [30, 60, 120, 0]
const EMBER := Color(1.0, 0.37, 0.25)
const GOLD := Color(1.0, 0.69, 0.43)
const TEXT := Color(0.94, 0.94, 0.93)
const MUTED := Color(0.65, 0.68, 0.71)
const METAL := Color(0.45, 0.49, 0.53)

var udp := PacketPeerUDP.new()
var found := {}  # ip -> {info, t}
var game_list: ItemList
var ip_edit: LineEdit
var status: Label
var _dock: VBoxContainer
var _panels := {}
var _tabs := {}
var _refresh_t := 0.0
var _listening := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial"])
	font.font_weight = 600
	var menu_theme := Theme.new()
	menu_theme.default_font = font
	menu_theme.default_font_size = 18
	theme = menu_theme
	_build_background()
	_build_dock()
	_select_tab("host")
	_on_menu_status(Game.menu_message)
	Game.menu_message = ""
	Game.menu_status.connect(_on_menu_status)
	_listening = udp.bind(Game.DISCOVERY_PORT) == OK


func _exit_tree() -> void:
	udp.close()


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.name = "MenuArtwork"
	bg.texture = BACKGROUND
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.anchor_left = 0.0
	bg.anchor_right = 1.0
	bg.anchor_top = 0.0
	bg.anchor_bottom = 1.0

	var fade := Gradient.new()
	fade.set_color(0, Color(0.005, 0.008, 0.014, 0.0))
	fade.set_color(1, Color(0.005, 0.008, 0.014, 0.88))
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = fade
	fade_texture.fill_from = Vector2(0.5, 0.0)
	fade_texture.fill_to = Vector2(0.5, 1.0)
	var shade := TextureRect.new()
	shade.name = "LowerFade"
	shade.texture = fade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 0.44
	shade.anchor_bottom = 1.0


func _build_dock() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "MenuDock"
	_dock.anchor_left = 0.16
	_dock.anchor_right = 0.84
	_dock.anchor_top = 0.59
	_dock.anchor_bottom = 0.98
	_dock.add_theme_constant_override("separation", 10)
	add_child(_dock)

	var nav := HBoxContainer.new()
	nav.custom_minimum_size.y = 60.0
	nav.add_theme_constant_override("separation", 8)
	_dock.add_child(nav)
	_nav_button(nav, "01  HOST MATCH", "host")
	_nav_button(nav, "02  JOIN LAN", "join")
	_nav_button(nav, "03  SETTINGS", "settings")
	var quit := _nav_button(nav, "04  QUIT", "quit")
	quit.pressed.connect(func(): get_tree().quit())

	_build_host(_new_panel("host"))
	_build_join(_new_panel("join"))
	_build_settings(_new_panel("settings"))

	status = _label(_dock, "", 15, MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.custom_minimum_size.y = 20.0


func _nav_button(parent: HBoxContainer, caption: String, id: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 60.0
	button.add_theme_font_size_override("font_size", 18)
	parent.add_child(button)
	_tabs[id] = button
	if id != "quit":
		button.pressed.connect(_select_tab.bind(id))
	return button


func _select_tab(id: String) -> void:
	for key in _panels:
		_panels[key].visible = key == id
	for key in _tabs:
		_style_tab(_tabs[key], key == id)


func _style_tab(button: Button, active: bool) -> void:
	var base := Color(0.17, 0.075, 0.07, 0.94) if active else Color(0.014, 0.019, 0.027, 0.83)
	button.add_theme_stylebox_override("normal", _box(base, EMBER if active else METAL.darkened(0.35), 2 if active else 1))
	button.add_theme_stylebox_override("hover", _box(Color(0.22, 0.095, 0.07, 0.96), EMBER, 2))
	button.add_theme_stylebox_override("pressed", _box(Color(0.28, 0.10, 0.07, 0.98), GOLD, 2))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, GOLD, 1))
	button.add_theme_color_override("font_color", TEXT if active else MUTED)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)


func _new_panel(id: String) -> VBoxContainer:
	var shell := PanelContainer.new()
	shell.name = id.capitalize() + "Panel"
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", _box(Color(0.012, 0.017, 0.025, 0.91), Color(0.31, 0.35, 0.38, 0.72)))
	_dock.add_child(shell)
	_panels[id] = shell
	var padding := MarginContainer.new()
	for side in ["left", "right"]:
		padding.add_theme_constant_override("margin_" + side, 27)
	for side in ["top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 12)
	shell.add_child(padding)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	padding.add_child(body)
	return body


func _box(fill: Color, border: Color, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(9)
	return style


func _label(parent: Node, caption: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _header(parent: VBoxContainer, title: String, detail: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, title, 26, TEXT)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_label(row, detail, 14, MUTED)
	var line := ColorRect.new()
	line.color = Color(1.0, 0.37, 0.25, 0.65)
	line.custom_minimum_size.y = 2.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _field(parent: Node, caption: String) -> VBoxContainer:
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 6)
	parent.add_child(field)
	_label(field, caption.to_upper(), 15, MUTED)
	return field


func _style_input(control: Control) -> void:
	control.custom_minimum_size.y = 42.0
	control.add_theme_stylebox_override("normal", _box(Color(0.055, 0.069, 0.081, 0.93), METAL.darkened(0.2)))
	control.add_theme_stylebox_override("hover", _box(Color(0.075, 0.083, 0.094, 0.96), GOLD))
	control.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, EMBER, 2))
	control.add_theme_color_override("font_color", TEXT)
	control.add_theme_color_override("font_hover_color", TEXT)


func _option(parent: Node, caption: String, choices: Array, selected: int, callback: Callable) -> OptionButton:
	var field := _field(parent, caption)
	var option := OptionButton.new()
	for choice in choices:
		option.add_item(str(choice))
	option.select(selected)
	option.item_selected.connect(callback)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(option)
	field.add_child(option)
	return option


func _action_button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(210.0, 48.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_stylebox_override("normal", _box(Color(0.73, 0.23, 0.16, 0.97), EMBER))
	button.add_theme_stylebox_override("hover", _box(Color(0.95, 0.35, 0.22, 1.0), GOLD))
	button.add_theme_stylebox_override("pressed", _box(Color(0.60, 0.17, 0.12, 1.0), GOLD))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, GOLD, 1))
	button.add_theme_color_override("font_color", Color(0.98, 0.97, 0.95))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _build_host(body: VBoxContainer) -> void:
	_header(body, "HOST A MATCH", "PRIVATE LAN  /  UP TO 8 PLAYERS")
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 16)
	body.add_child(options)
	var bot_choices := []
	for amount in range(Game.MAX_TOTAL):
		bot_choices.append(str(amount))
	_option(options, "Bots", bot_choices, clampi(int(Game.match_cfg.bots), 0, Game.MAX_TOTAL - 1),
		func(index: int): Game.match_cfg.bots = index)
	_option(options, "Bot skill", ["Easy", "Normal", "Hard"], clampi(int(Game.match_cfg.difficulty), 0, 2),
		func(index: int): Game.match_cfg.difficulty = index)
	var time_names := []
	for seconds in TIME_OPTIONS:
		time_names.append("%d minutes" % (seconds / 60))
	_option(options, "Time limit", time_names, maxi(TIME_OPTIONS.find(int(Game.match_cfg.time_limit)), 0),
		func(index: int): Game.match_cfg.time_limit = TIME_OPTIONS[index])
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 20)
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(bottom)
	var note := _label(bottom, "Fast rounds. Friends join on the same network.", 16, MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button(bottom, "START MATCH  ›", _on_host)


func _build_join(body: VBoxContainer) -> void:
	_header(body, "JOIN A MATCH", "DISCOVERED ON YOUR NETWORK")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 17)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var discovered := _field(row, "Available games")
	discovered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_list = ItemList.new()
	game_list.custom_minimum_size.y = 112.0
	game_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_list.add_theme_stylebox_override("panel", _box(Color(0.05, 0.063, 0.077, 0.96), METAL.darkened(0.2)))
	game_list.add_theme_color_override("font_color", TEXT)
	game_list.item_activated.connect(func(_index: int): _on_join())
	game_list.item_selected.connect(func(index: int): ip_edit.text = str(game_list.get_item_metadata(index)))
	discovered.add_child(game_list)
	var direct := _field(row, "Direct IP address")
	direct.custom_minimum_size.x = 282.0
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.1.23"
	ip_edit.text_submitted.connect(func(_value: String): _on_join())
	_style_input(ip_edit)
	direct.add_child(ip_edit)
	_action_button(direct, "JOIN GAME  ›", _on_join)
	_refresh_game_list()


func _build_settings(body: VBoxContainer) -> void:
	_header(body, "SETTINGS", "CHANGES SAVE AUTOMATICALLY")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var name_field := _field(grid, "Player name")
	var name_edit := LineEdit.new()
	name_edit.text = str(Game.settings.name)
	name_edit.max_length = 16
	name_edit.text_changed.connect(func(value: String):
		Game.settings.name = value
		Game.save_settings())
	_style_input(name_edit)
	name_field.add_child(name_edit)
	var fps_names := ["30 FPS", "60 FPS", "120 FPS", "UNLIMITED"]
	_option(grid, "Frame limit", fps_names, maxi(FPS_OPTIONS.find(int(Game.settings.fps_cap)), 0),
		func(index: int):
			Game.settings.fps_cap = FPS_OPTIONS[index]
			Game.apply_settings()
			Game.save_settings())
	_slider(grid, "Field of view", 80.0, 120.0, 1.0, float(Game.settings.fov), "%.0f",
		func(value: float):
			Game.settings.fov = value
			Game.save_settings())
	_slider(grid, "Mouse sensitivity", 0.02, 0.4, 0.005, float(Game.settings.sensitivity), "%.3f",
		func(value: float):
			Game.settings.sensitivity = value
			Game.save_settings())
	_slider(grid, "Volume", 0.0, 1.0, 0.05, float(Game.settings.volume), "%.2f",
		func(value: float):
			Game.settings.volume = value
			Game.apply_settings()
			Game.save_settings())
	var hint := _field(grid, "Controls")
	_label(hint, "WASD  MOVE   •   SPACE  JUMP\nMOUSE  AIM   •   CLICK  FIRE", 14, MUTED)


func _slider(parent: Node, caption: String, lo: float, hi: float, step: float,
		value: float, format: String, callback: Callable) -> void:
	var field := _field(parent, caption)
	var readout := _label(field, format % value, 18, TEXT)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.modulate = GOLD
	slider.custom_minimum_size.y = 20.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(new_value: float):
		readout.text = format % new_value
		callback.call(new_value))
	field.add_child(slider)


func _on_menu_status(message: String) -> void:
	status.text = message if message != "" else "LOCAL NETWORK  •  NO ACCOUNT REQUIRED"
	status.add_theme_color_override("font_color", GOLD if message != "" else MUTED)


func _on_host() -> void:
	Game.save_settings()
	if Game.host_game() != OK:
		_on_menu_status("Could not host. Is another game already running on this Mac?")


func _on_join() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip == "":
		_on_menu_status("Choose a discovered game or enter its IP address.")
		return
	Game.save_settings()
	if Game.join_game(ip) != OK:
		_on_menu_status("Could not connect to %s." % ip)
	else:
		_on_menu_status("Connecting to %s..." % ip)


func _process(delta: float) -> void:
	if not _listening:
		return
	var now := Time.get_ticks_msec() / 1000.0
	while udp.get_available_packet_count() > 0:
		var packet := udp.get_packet()
		var ip := udp.get_packet_ip()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if data is Dictionary and data.get("game") == "HARDSPAWN":
			found[ip] = {"info": data, "t": now}
	_refresh_t -= delta
	if _refresh_t > 0.0:
		return
	_refresh_t = 1.0
	for ip in found.keys():
		if now - float(found[ip].t) > 3.5:
			found.erase(ip)
	_refresh_game_list()


func _refresh_game_list() -> void:
	if game_list == null:
		return
	var selected_ip := ip_edit.text if ip_edit else ""
	game_list.clear()
	if found.is_empty():
		var index := game_list.add_item("SEARCHING FOR LAN GAMES...")
		game_list.set_item_disabled(index, true)
		return
	for ip in found:
		var info: Dictionary = found[ip].info
		var index := game_list.add_item("%s   •   %d/%d PLAYERS   •   %s" %
			[info.host, int(info.total), int(info.max), ip])
		game_list.set_item_metadata(index, ip)
		if ip == selected_ip:
			game_list.select(index)
