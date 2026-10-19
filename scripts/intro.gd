extends Control
## Plays the opening movie once, then opens the regular menu.

const INTRO_PATH := "res://movie/intro.ogv"
const MENU_PATH := "res://scenes/menu.tscn"

@onready var video: VideoStreamPlayer = $Aspect/Video

var _opening_menu := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	video.finished.connect(_show_menu)
	video.stream = load(INTRO_PATH) as VideoStream
	if video.stream == null:
		_show_menu.call_deferred()
		return
	video.play()
	# If the decoder cannot finish a damaged movie, the menu remains reachable.
	get_tree().create_timer(20.0).timeout.connect(_show_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_menu()


func _show_menu() -> void:
	if _opening_menu:
		return
	_opening_menu = true
	video.stop()
	get_tree().change_scene_to_file(MENU_PATH)
