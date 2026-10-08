extends RefCounted

# Lokales Wegenetz aus echter Bodenkollision; benötigt kein gebackenes Navmesh.
const STEP := 0.8
static func find_path(body: Playable, target: Vector3) -> PackedVector3Array:
	var space := body.get_world_3d().direct_space_state
	var shape := body.get_node("CollisionShape3D") as CollisionShape3D
	var excluded: Array[RID] = []
	for actor in body.get_tree().get_nodes_in_group("combat_reactive"):
		if actor is CollisionObject3D:
			excluded.append(actor.get_rid())
	var low := Vector2(minf(body.global_position.x, target.x) - 6, minf(body.global_position.z, target.z) - 6)
	var high := Vector2(maxf(body.global_position.x, target.x) + 6, maxf(body.global_position.z, target.z) + 6)
	var width := ceili((high.x - low.x) / STEP) + 1
	var depth := ceili((high.y - low.y) / STEP) + 1
	if width * depth > 6000:
		return PackedVector3Array()
	var graph := AStar3D.new()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.collision_mask = body.collision_mask
	query.exclude = excluded
	for x in width:
		for z in depth:
			var point := Vector3(low.x + x * STEP, body.global_position.y, low.y + z * STEP)
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.6, point - Vector3.UP * 0.6, body.collision_mask, excluded)
			var floor_hit := space.intersect_ray(ray)
			if floor_hit.is_empty() or floor_hit.normal.dot(Vector3.UP) < cos(body.floor_max_angle):
				continue
			point.y = floor_hit.position.y + 0.05
			var pose := body.global_transform
			pose.origin = point
			query.transform = pose * shape.transform
			if space.intersect_shape(query, 1).is_empty():
				graph.add_point(x * depth + z, point)
	var start_id := width * depth
	graph.add_point(start_id, body.global_position + Vector3.UP * 0.05)
	graph.add_point(start_id + 1, target)
	for id in graph.get_point_ids():
		var candidates: Array[int] = []
		if id >= start_id:
			for other in graph.get_point_ids():
				if other < start_id and graph.get_point_position(id).distance_to(graph.get_point_position(other)) < STEP * 1.8:
					candidates.append(other)
		else:
			candidates = [id + depth, id + 1 if id % depth < depth - 1 else -1]
		for other in candidates:
			if not graph.has_point(other):
				continue
			var pose := body.global_transform
			pose.origin = graph.get_point_position(id)
			query.transform = pose * shape.transform
			query.motion = graph.get_point_position(other) - pose.origin
			if absf(query.motion.y) > 0.3:
				continue
			var sweep := space.cast_motion(query)
			if sweep[0] >= 1.0:
				graph.connect_points(id, other)
	return graph.get_point_path(start_id, start_id + 1)
