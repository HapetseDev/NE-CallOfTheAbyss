extends Button

var slot_index: int = -1
var inventory_ui: InventoryUI


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory_ui == null or inventory_ui.playable == null:
		return null
	if slot_index < 0 or slot_index >= inventory_ui.playable.inventory.size():
		return null
	var slot := inventory_ui.playable.inventory[slot_index]
	if slot == null or not (slot.item is ItemData):
		return null
	var item: ItemData = slot.item
	var preview := Label.new()
	preview.text = item.item_name
	if slot.count > 1:
		preview.text += " x%d" % slot.count
	set_drag_preview(preview)
	return {"type": "inventory_item", "index": slot_index, "source": inventory_ui, "item": item}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not is_instance_valid(data.get("source")):
		return false
	return (data.get("type") == "equipped_item" and data.source == inventory_ui) or inventory_ui.accepts_transfer(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory_ui:
		if inventory_ui.accepts_transfer(data):
			data.source.transfer_to(data.index, inventory_ui.playable)
		else:
			inventory_ui.unequip_to_backpack(data["slot_key"])
