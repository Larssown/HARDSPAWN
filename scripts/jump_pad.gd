class_name JumpPad
extends Area3D
## A reusable launch pad. Direction is horizontal; height is measured above the pad.

@export var launch_height := 8.0
@export var launch_direction := Vector3.FORWARD
@export var horizontal_speed := 13.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_launch_body)


func _launch_body(body: Node3D) -> void:
	var player := body as Player
	if player == null or player.dead or not player.is_multiplayer_authority():
		return
	if not player.can_use_jump_pad():
		return
	var direction := Vector3(launch_direction.x, 0.0, launch_direction.z).normalized()
	var rise := sqrt(2.0 * Player.GRAVITY * maxf(launch_height, 0.1))
	player.launch(direction * horizontal_speed + Vector3.UP * rise)
