extends Node
## Plays one-shot sound effects, either flat (your own sounds) or positioned in the world.

const NAMES := ["mg", "shotgun", "rocket_fire", "explosion", "rail", "jump", "land", "jumppad",
	"hit", "hit_heavy", "shotgun_pump", "kill", "pickup_health", "pickup_armor", "pickup_mega", "hurt", "death", "switch",
	"respawn", "match_end", "minute"]

var streams := {}
const ANNOUNCER_NAMES := ["321", "terminated", "first_blood", "1minute", "30seconds",
	"dualelimination", "tripple", "overkill", "insanity", "monsterkill"]
var _announcer: AudioStreamPlayer
var _announcer_queue: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for n in ANNOUNCER_NAMES:
		var path := "res://assets/sfx/announcer/%s.ogg" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	_announcer = AudioStreamPlayer.new()
	_announcer.name = "Announcer"
	add_child(_announcer)
	_announcer.finished.connect(_play_next_announcement)


func start_announcer(sound: String, from_position := 0.0) -> void:
	_announcer_queue.clear()
	_announcer.stop()
	if streams.has(sound):
		_announcer.stream = streams[sound]
		_announcer.play(from_position)


func queue_announcer(sound: String) -> void:
	if not streams.has(sound):
		return
	_announcer_queue.append(sound)
	if not _announcer.playing:
		_play_next_announcement()


func _play_next_announcement() -> void:
	if _announcer_queue.is_empty():
		return
	_announcer.stream = streams[_announcer_queue.pop_front()]
	_announcer.play()


func play_2d(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_3d(sound: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(sound) or Game.world == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.unit_size = 7.0
	p.max_distance = 90.0
	Game.world.fx_root.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()



func play_2d_delayed(sound: String, delay: float, vol_db := 0.0, pitch := 1.0) -> void:
	get_tree().create_timer(delay).timeout.connect(play_2d.bind(sound, vol_db, pitch))


func play_3d_delayed(sound: String, delay: float, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	get_tree().create_timer(delay).timeout.connect(play_3d.bind(sound, pos, vol_db, pitch))
