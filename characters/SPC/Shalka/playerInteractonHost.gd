class_name PlayerInteractionHost extends Node3D

@onready var player: Playable = $".."


func _ready() -> void:
	player.direction_changed.connect(update_direction)


func update_direction(_new_direction: Vector3) -> void:
	rotation.y = player.get_facing_yaw()
