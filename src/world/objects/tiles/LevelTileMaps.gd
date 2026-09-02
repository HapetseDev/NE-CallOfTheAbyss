class_name LevelGround extends Node3D

@export var ground_size : Vector2 = Vector2(20, 20)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if LevelManager.instance:
		LevelManager.instance.change_tilemap_bounds(get_ground_bounds())
	pass

func get_ground_bounds() -> Array[Vector3]:
	var bounds : Array[Vector3] = []
	var half_size = ground_size / 2
	bounds.append(Vector3(-half_size.x, 0, -half_size.y))
	bounds.append(Vector3(half_size.x, 0, half_size.y))
	return bounds
