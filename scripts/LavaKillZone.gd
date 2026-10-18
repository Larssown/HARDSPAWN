class_name LavaKillZone
extends Area3D
## Server-authoritative lava death. Game.server_damage handles frags, effects,
## spectator camera and the normal respawn timer on every multiplayer peer.


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player CharacterBody3D nodes only.
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	var player := body as Player
	if player == null or player.dead:
		return
	Game.server_damage(player.peer_id, player.peer_id, 10000.0, -1)
