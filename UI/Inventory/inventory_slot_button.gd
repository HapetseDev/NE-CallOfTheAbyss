extends Button

var slot_index: int = -1
var inventory_ui: InventoryUI


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory_ui == null or inventory_ui.playable == null:
		return null
	if slot_index < 0 or slot_index >= inventory_ui.playable.inventory.size():
		return null
	var slot = inventory_ui.playable.inventory[slot_index]
	if not (slot is Dictionary and slot.get("item") is Item):
		return null
	var item: Item = slot["item"]
	var preview := Label.new()
	preview.text = item.item_name
	if slot["count"] > 1:
		preview.text += " x%d" % slot["count"]
	set_drag_preview(preview)
	return {"type": "inventory_item", "index": slot_index}
