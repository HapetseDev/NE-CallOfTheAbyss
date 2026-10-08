class_name WorldSceneState extends RefCounted


static func capture(tree: SceneTree, location: String) -> void:
	if location.is_empty():
		return
	var world := GameState.world_state
	world.locations[location] = true
	for node in tree.get_nodes_in_group("combat_reactive"):
		if node is Playable and not node.is_queued_for_deletion() and node.character and world.characters.get_character(node.character.character_id) == node.character:
			world.placements[node.character.character_id] = {"location": location, "position": node.global_position}
	for node in tree.get_nodes_in_group("persistent_world_object"):
		if not node.is_queued_for_deletion() and world.objects.has(node.world_object_id):
			world.objects[node.world_object_id].position = node.global_position


static func restore(tree: SceneTree, location: String, parent: Node3D) -> void:
	var world := GameState.world_state
	for node in tree.get_nodes_in_group("combat_reactive"):
		if node is Playable and node.character:
			var placement: Dictionary = world.placements.get(node.character.character_id, {})
			if placement.get("location") == location:
				node.global_position = placement.position
	var present: Dictionary = {}
	for node in tree.get_nodes_in_group("persistent_world_object"):
		if not node.is_queued_for_deletion():
			present[node.world_object_id] = true
	for id in world.objects:
		var entry: Dictionary = world.objects[id]
		if entry.kind != "item" or entry.removed or entry.location != location or present.has(id):
			continue
		var item := load("res://src/world/objects/items/basic_item.tscn").instantiate() as BasicItem
		item.world_object_id = id
		item.item_data = entry.item
		parent.add_child(item)
		item.global_position = entry.position
