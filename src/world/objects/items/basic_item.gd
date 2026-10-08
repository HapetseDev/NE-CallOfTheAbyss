class_name BasicItem extends RigidBody3D

## Welt-Instanz eines Items (Physik, Aufnehmen, Verwenden per E-Menü).
@export var world_object_id: String = ""
var _taken: bool = false

@export var item_data: ItemData

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	if LevelManager.instance and not LevelManager.instance.current_level_path.is_empty():
		var world := GameState.world_state
		if world_object_id.is_empty():
			world_object_id = world.allocate_object_id()
		if world.objects.has(world_object_id):
			var entry: Dictionary = world.objects[world_object_id]
			if entry.removed or entry.location != LevelManager.instance.current_level_path:
				_taken = true
				queue_free()
				return
			item_data = entry.item
			global_position = entry.position
		elif item_data:
			item_data = item_data.duplicate_item()
			item_data.world_object_id = world_object_id
			item_data.max_stack = 1
			world.objects[world_object_id] = {"kind": "item", "location": LevelManager.instance.current_level_path, "position": global_position, "removed": false, "item": item_data}
		add_to_group("persistent_world_object")
	add_to_group("interactable")
	mass = item_data.weight if item_data else 0.3
	_apply_visual()


func _apply_visual() -> void:
	if item_data == null:
		return
	var tex: Texture2D = item_data.world_texture if item_data.world_texture else item_data.icon
	if is_instance_valid(_sprite) and tex:
		_sprite.texture = tex
		_sprite.visible = true
		if is_instance_valid(_mesh):
			_mesh.visible = false
	elif is_instance_valid(_mesh):
		_mesh.visible = true
		if is_instance_valid(_sprite):
			_sprite.visible = false


func get_actions(_player: Playable) -> Array[Dictionary]:
	if item_data == null:
		return []
	var actions: Array[Dictionary] = [
		{"label": "Aufnehmen", "action_id": "pickup"},
	]
	if item_data.consumable:
		actions.append({"label": "Verwenden", "action_id": "consume"})
	return actions


func perform_action(action_id: String, player: Playable) -> void:
	match action_id:
		"pickup":
			_pickup(player)
		"consume":
			_consume_in_world(player)


func _pickup(player: Playable) -> void:
	if _taken or item_data == null:
		return
	if not player.can_carry_additional(item_data.weight):
		EventLog.add("%s kann %s nicht tragen (zu schwer)." % [player.get_display_name(), item_data.item_name])
		return
	_taken = true
	GameState.world_state.remove_object(world_object_id)
	player.add_item(item_data.duplicate_item())
	EventLog.add("%s hat %s aufgenommen." % [player.get_display_name(), item_data.item_name])
	queue_free()


func _consume_in_world(player: Playable) -> void:
	if _taken or item_data == null or not item_data.consumable:
		return
	_taken = true
	GameState.world_state.remove_object(world_object_id)
	item_data.apply_effects(player)
	queue_free()
