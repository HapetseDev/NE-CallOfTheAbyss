extends RefCounted

## Top-down geometry and exploration; never instantiates a second gameplay scene.
const CELL_SIZE := 2.0
const REVEAL_RADIUS := 8.0
var level: Node3D
var location := ""
var segments: Array[PackedVector2Array] = []
var bounds := Rect2()
var player_position := Vector2.ZERO
var _has_bounds := false
var _floor_polygons: Array[PackedVector2Array] = []

func update(game: MainGame) -> void:
	if not game or not game.party or not is_instance_valid(game.party.leader):
		return
	var current := game.level_manager.current_level
	if not is_instance_valid(current):
		return
	if current != level:
		level = current
		location = game.level_manager.current_level_path
		segments.clear()
		_has_bounds = false
		_scan(level)
	player_position = project(game.party.leader.global_position)
	var world := GameState.world_state
	if not world.map_exploration.has(location):
		world.map_exploration[location] = {"cells": {}, "markers": {}}
	var state: Dictionary = world.map_exploration[location]
	var center := Vector2i((player_position / CELL_SIZE).floor())
	for x in range(-4, 5):
		for y in range(-4, 5):
			var cell := center + Vector2i(x, y)
			if (Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5).distance_to(player_position) <= REVEAL_RADIUS:
				state.cells[cell_key(cell)] = true
	# Include dropped items, which live alongside the level under LevelRoot.
	_markers(game.level_root, state)
	for id: String in state.markers.keys():
		if world.objects.has(id) and world.objects[id].removed:
			state.markers.erase(id)

func state() -> Dictionary:
	return GameState.world_state.map_exploration.get(location, {"cells": {}, "markers": {}})

static func project(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func is_explored(point: Vector2) -> bool:
	return state().cells.has(cell_key(Vector2i((point / CELL_SIZE).floor())))

func _markers(node: Node, data: Dictionary) -> void:
	if node is Node3D and node.is_visible_in_tree() and not node.is_queued_for_deletion():
		var label := ""
		var id := ""
		var kind := "object"
		if node is NPC and node.character:
			id = node.character.character_id
			label = node.character.character_name
			kind = "npc"
		elif node is BasicItem and node.item_data:
			id = node.world_object_id
			label = node.item_data.item_name
		elif node is Interactable:
			id = str(level.get_path_to(node))
			label = str(node.name)
			if node is Plant:
				id = node.world_object_id
				label = "Pflanze"
		if not id.is_empty() and project(node.global_position).distance_to(player_position) <= REVEAL_RADIUS:
			data.markers[id] = {"position": node.global_position, "label": label, "kind": kind}
	for child in node.get_children():
		_markers(child, data)

func _scan(node: Node) -> void:
	if node is Playable or node is BasicItem or node is Interactable:
		return
	if node is GridMap and node.mesh_library:
		# Floor tile seams are not geographic features. Cancel shared edges.
		var floor_layer: bool = node.get_meta("map_floor", "boden" in str(node.name).to_lower() or "floor" in str(node.name).to_lower())
		_floor_polygons.clear()
		for cell in node.get_used_cells():
			var item: int = node.get_cell_item(cell)
			var mesh: Mesh = node.mesh_library.get_item_mesh(item)
			if mesh:
				var local := Transform3D(node.get_cell_item_basis(cell), node.map_to_local(cell))
				_outline(mesh, node.global_transform * local * node.mesh_library.get_item_mesh_transform(item), floor_layer)
		for polygon in _floor_polygons:
			for index in polygon.size():
				_segment(polygon[index], polygon[(index + 1) % polygon.size()])
	elif node is MeshInstance3D and node.mesh and node.is_visible_in_tree():
		_outline(node.mesh, node.global_transform)
	for child in node.get_children():
		_scan(child)

func _outline(mesh: Mesh, transform: Transform3D, floor_layer: bool = false) -> void:
	var points := PackedVector2Array()
	for vertex in mesh.get_faces():
		points.append(project(transform * vertex))
	if points.size() < 3:
		return
	var hull := Geometry2D.convex_hull(points)
	if floor_layer:
		# Union handles overlapping tiles and mismatched edge lengths as well.
		hull.resize(hull.size() - 1)
		var index := 0
		while index < _floor_polygons.size():
			var merged := Geometry2D.merge_polygons(hull, _floor_polygons[index])
			if merged.size() == 1:
				hull = merged[0]
				_floor_polygons.remove_at(index)
				index = 0
			else:
				index += 1
		_floor_polygons.append(hull)
	else:
		for i in range(hull.size() - 1):
			_segment(hull[i], hull[i + 1])
	for point in hull:
		if not _has_bounds:
			bounds = Rect2(point, Vector2.ZERO)
			_has_bounds = true
		else:
			bounds = bounds.expand(point)


func _segment(a: Vector2, b: Vector2) -> void:
	# Short segments keep unexplored parts of large meshes hidden.
	var count := maxi(1, ceili(a.distance_to(b) / (CELL_SIZE * 0.25)))
	for part in count:
		segments.append(PackedVector2Array([a.lerp(b, float(part) / count), a.lerp(b, float(part + 1) / count)]))
