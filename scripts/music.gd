extends Node
## Background music: the menu loop in the menu, the in-game loop during matches.
## Tracks crossfade softly. Both WAVs are imported with looping on, so they repeat seamlessly.
## Volume follows Game.settings.music on its own "Music" bus.

const TRACKS := {
	"menu": "res://assets/music/menu_loop.wav",
	"ingame": "res://assets/music/ingame_loop.wav",
}
const BUS := "Music"
const SILENT_DB := -60.0

var current := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _tweens: Array[Tween] = [null, null]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)
	apply_volume()


func apply_volume() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(Game.settings.get("music", 0.5)), 0.001)))


## Crossfades to a track ("menu" or "ingame"). Does nothing if it is already playing.
func play(track: String, fade := 1.5) -> void:
	if track == current or not TRACKS.has(track):
		return
	var stream: AudioStream = load(TRACKS[track])
	if stream == null:
		return
	current = track
	_fade(_active, SILENT_DB, fade, true)
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = SILENT_DB
	p.play()
	_fade(_active, 0.0, fade, false)


func stop(fade := 1.0) -> void:
	current = ""
	_fade(_active, SILENT_DB, fade, true)


func _fade(i: int, to_db: float, time: float, stop_after: bool) -> void:
	if _tweens[i]:
		_tweens[i].kill()
	var p := _players[i]
	if not p.playing:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, time).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[i] = tw
