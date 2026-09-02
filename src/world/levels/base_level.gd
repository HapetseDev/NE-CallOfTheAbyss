@abstract class_name BaseLevel
extends Node3D

## Gemeinsame Schnittstelle aller austauschbaren Level.
## Der Player liegt nicht im Level, sondern unter MainGame/EntityRoot.


@abstract func get_default_player_spawn() -> Vector3


func on_level_enter() -> void:
	pass


func on_level_exit() -> void:
	pass


## Optionale Kamera-Grenzen. Leere AABB = keine Clamp-Beschränkung.
func get_camera_bounds() -> AABB:
	return AABB()


## Optionale Kamera-Overrides, z. B. follow_distance, camera_height, pitch_angle.
func get_camera_settings() -> Dictionary:
	return {}


func find_spawn_marker(marker_name: String = "PlayerSpawn") -> Node3D:
	var marker := get_node_or_null(marker_name)
	if marker is Node3D:
		return marker
	return null
