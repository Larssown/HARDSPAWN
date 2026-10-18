class_name KillZone
extends Area3D
## The host applies an unarmorable lethal fall through the normal death flow.


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_kill_body)


func _kill_body(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	var player := body as Player
	if player == null or player.dead:
		return
	Game.server_damage(player.peer_id, player.peer_id, 10000.0, -1)
