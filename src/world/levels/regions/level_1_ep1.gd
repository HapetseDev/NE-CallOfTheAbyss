class_name Level1Ep1
extends BaseLevel


func get_default_player_spawn() -> Vector3:
	var marker := find_spawn_marker()
	if marker:
		return marker.global_position
	return global_position
