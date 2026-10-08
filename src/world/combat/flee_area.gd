extends Area3D

## Zielgebiet einer erfolgreichen Flucht, unabhängig von Angreifer/Verteidiger.
@export_enum("Party", "Gegner") var destination_group: int = 0

func _ready() -> void:
	add_to_group("combat_flee_areas")

static func destinations(playable: Playable) -> Array[Vector3]:
	if not is_instance_valid(playable):
		return []
	var ancestor := playable.get_parent()
	var party_member := false
	while ancestor:
		if ancestor is Party:
			party_member = true
			break
		ancestor = ancestor.get_parent()
	for area in playable.get_tree().get_nodes_in_group("combat_flee_areas"):
		if area.destination_group == (0 if party_member else 1):
			return area.get_destinations(playable)
	# Fehlende oder volle Bereiche liefern kein Fluchtziel.
	return []

func get_destinations(playable: Playable) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var boundary := get_node("CollisionShape3D") as CollisionShape3D
	var box := boundary.shape as BoxShape3D
	var body_shape := playable.get_node("CollisionShape3D") as CollisionShape3D
	var space := get_world_3d().direct_space_state
	# Innenabstand und mehrere Plätze verhindern übereinanderstehende Figuren.
	for x in [0.0, -0.3, 0.3]:
		for z in [0.0, -0.3, 0.3]:
			var point := boundary.to_global(Vector3(x * box.size.x, 0, z * box.size.z))
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * box.size.y * 0.5,
				point - Vector3.UP * box.size.y * 0.5, playable.collision_mask, [playable.get_rid()])
			var floor_hit := space.intersect_ray(ray)
			if floor_hit.is_empty() or floor_hit.normal.dot(Vector3.UP) < cos(playable.floor_max_angle):
				continue
			point.y = floor_hit.position.y + 0.05
			# Physikabfragen sehen Teleports desselben Frames erst verzögert.
			# Aktuelle Positionen verhindern daher auch unmittelbar folgende Doppelbelegung.
			var occupied := false
			for other in get_tree().get_nodes_in_group("combat_reactive"):
				if other == playable or not other is Playable:
					continue
				var reserved: bool = not other.flee_path.is_empty() and other.flee_path[-1].distance_to(point) < 1.0
				if reserved or other.global_position.distance_to(point) < 1.0:
					occupied = true
					break
			if occupied:
				continue
			var destination := playable.global_transform
			destination.origin = point
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = body_shape.shape
			query.transform = destination * body_shape.transform
			query.collision_mask = playable.collision_mask | playable.collision_layer
			query.exclude = [playable.get_rid()]
			if not space.intersect_shape(query, 1).is_empty():
				continue
			result.append(point)
	return result
