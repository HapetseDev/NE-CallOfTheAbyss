extends Button

var slot_index: int = -1
var inventory_ui: InventoryUI


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory_ui == null or inventory_ui._inventory == null:
		return null
	var slot := inventory_ui._inventory.get_slot(slot_index)
	if slot == null or slot.is_empty():
		return null
	var preview := Label.new()
	preview.text = slot.item.item_name
	if slot.count > 1:
		preview.text += " x%d" % slot.count
	set_drag_preview(preview)
	return {"type": "inventory_item", "index": slot_index}
