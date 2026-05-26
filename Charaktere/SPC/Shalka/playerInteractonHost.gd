class_name PlayerInteractionHost extends Node3D
@onready var player: Playable = $".."


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.direction_changed.connect(update_direction)
	pass

func update_direction ( newDirection : Vector3 ) -> void:
	match newDirection:
		Vector3(0, 0, 1):  # DOWN
			rotation_degrees.y = 0
		Vector3(0, 0, -1):  # UP
			rotation_degrees.y = 180
		Vector3(1, 0, 0):  # RIGHT
			rotation_degrees.y = -90
		Vector3(-1, 0, 0):  # LEFT
			rotation_degrees.y = 90
		_:
			rotation_degrees.y = 0
	pass
