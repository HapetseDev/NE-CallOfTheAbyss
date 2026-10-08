extends RefCounted

## Auf die aktuelle Etage begrenzte Kamerastrahl-Suche. Keine Navigation.
static func pick(body: CharacterBody3D, origin: Vector3, ray: Vector3, height_range: float) -> Variant:
	if ray.y >= -0.001:
		return null
	var space := body.get_world_3d().direct_space_state
	var upper := body.global_position.y + height_range
	var lower := body.global_position.y - height_range
	var start_distance := maxf(0.0, (upper - origin.y) / ray.y)
	var end_distance := (lower - origin.y) / ray.y
	if end_distance <= start_distance:
		return null
	var from := origin + ray * start_distance
	var end := origin + ray * end_distance
	# Nicht die ganze GridMap ausschließen: Wand und Boden können denselben RID haben.
	for attempt in range(32):
		var query := PhysicsRayQueryParameters3D.create(from, end, body.collision_mask, [body.get_rid()])
		query.collide_with_areas = false
		query.hit_back_faces = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		if hit.normal.dot(Vector3.UP) >= cos(body.floor_max_angle):
			return hit.position
		from = hit.position + ray * 0.05
		if (end - from).dot(ray) <= 0:
			break
	# Bei vollständig verdecktem Strahl: Maus auf Standhöhenebene projizieren
	# und dort einen echten, begehbaren Boden innerhalb derselben Etage suchen.
	var distance := (body.global_position.y - origin.y) / ray.y
	if distance < 0:
		return null
	var projected := origin + ray * distance
	var query := PhysicsRayQueryParameters3D.create(Vector3(projected.x, upper, projected.z), Vector3(projected.x, lower, projected.z), body.collision_mask, [body.get_rid()])
	query.collide_with_areas = false
	var floor_hit := space.intersect_ray(query)
	if not floor_hit.is_empty() and floor_hit.normal.dot(Vector3.UP) >= cos(body.floor_max_angle):
		return floor_hit.position
	return null
