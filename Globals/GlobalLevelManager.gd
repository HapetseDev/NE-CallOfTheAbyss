extends Node

var current_tilemap_bounds : Array[Vector3]
signal TileMapBoundsChanged(bounds : Array[Vector3])

func ChangeTileMapBounds (bounds : Array[Vector3]) -> void:
	current_tilemap_bounds = bounds
	TileMapBoundsChanged.emit(bounds)
