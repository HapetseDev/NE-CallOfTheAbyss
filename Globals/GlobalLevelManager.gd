extends Node

var current_tilemap_bounds : Array[Vector3]
signal tilemap_bounds_changed(bounds : Array[Vector3])

func change_tilemap_bounds (bounds : Array[Vector3]) -> void:
	current_tilemap_bounds = bounds
	tilemap_bounds_changed.emit(bounds)
