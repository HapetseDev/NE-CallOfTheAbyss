class_name InventoryComponent extends Node

## Runtime-Adapter. Besitz liegt auf CharacterResource.inventory.

signal changed

var character: CharacterResource

var equipment: Dictionary:
	get:
		if character:
			character.ensure_equipment_slots()
			return character.inventory.equipment
		return {}


func bind(character_res: CharacterResource) -> void:
	if character and character.inventory_changed.is_connected(_on_character_inventory_changed):
		character.inventory_changed.disconnect(_on_character_inventory_changed)
	character = character_res
	if character:
		character.ensure_equipment_slots()
		if not character.inventory_changed.is_connected(_on_character_inventory_changed):
			character.inventory_changed.connect(_on_character_inventory_changed)
	changed.emit()


func add_item(item: ItemData, count: int = 1) -> void:
	if character:
		character.add_item(item, count)


func remove_item(item: ItemData, count: int = 1) -> bool:
	if character == null:
		return false
	return character.remove_item(item, count)


func has_item(item_id: String) -> bool:
	return character != null and character.has_item(item_id)


func get_slots() -> Array[InventorySlot]:
	if character and character.inventory:
		return character.inventory.slots
	var empty: Array[InventorySlot] = []
	return empty


func is_empty() -> bool:
	return character == null or character.inventory == null or character.inventory.is_empty()


func equip(slot_key: String, item: ItemData) -> void:
	if character:
		character.equip(slot_key, item)


func unequip(slot_key: String) -> ItemData:
	if character == null:
		return null
	return character.unequip(slot_key)


func _on_character_inventory_changed() -> void:
	changed.emit()
