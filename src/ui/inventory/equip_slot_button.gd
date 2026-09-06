extends Button

## Gegenstück zu inventory_slot_button.gd: macht einen Ausrüstungs-Slot-Button
## zur Drag-Quelle (Ziehen aus der Ausrüstung zurück ins Inventar = ablegen)
## und zum Drop-Ziel (ein Item aus dem Rucksack hierher ziehen = ausrüsten).
## slot_key kommt aus metadata/slot_key (siehe InventoryUI._wire_equip_buttons).

var inventory_ui: InventoryUI


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory_ui == null or inventory_ui.playable == null:
		return null
	var slot_key: String = get_meta(&"slot_key", "")
	if slot_key.is_empty():
		return null
	var equipped: Variant = inventory_ui.playable.equipment.get(slot_key)
	if not (equipped is ItemData):
		return null
	var preview := Label.new()
	preview.text = (equipped as ItemData).item_name
	set_drag_preview(preview)
	return {"type": "equipped_item", "slot_key": slot_key}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or data.get("type") != "inventory_item":
		return false
	if inventory_ui == null:
		return false
	return inventory_ui.can_equip_from_slot(data["index"], get_meta(&"slot_key", ""))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory_ui:
		inventory_ui.equip_from_slot(data["index"], get_meta(&"slot_key", ""))
