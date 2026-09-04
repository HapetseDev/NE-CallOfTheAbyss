class_name BasicItem extends RigidBody3D

## Welt-Instanz eines Items (Physik, Aufnehmen, Verwenden per E-Menü).
@export var item_data: ItemData

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
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
	if item_data == null:
		return
	player.add_item(item_data.duplicate_item())
	EventLog.add("%s hat %s aufgenommen." % [player.get_display_name(), item_data.item_name])
	queue_free()


func _consume_in_world(player: Playable) -> void:
	if item_data == null or not item_data.consumable:
		return
	item_data.apply_effects(player)
	queue_free()
