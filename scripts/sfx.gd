extends Node
## Plays one-shot sound effects, either flat (your own sounds) or positioned in the world.

const NAMES := ["mg", "shotgun", "rocket_fire", "explosion", "rail", "jump", "land", "jumppad",
	"hit", "kill", "pickup_health", "pickup_armor", "pickup_mega", "hurt", "death", "switch",
	"respawn", "match_end", "minute"]

var streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)


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
