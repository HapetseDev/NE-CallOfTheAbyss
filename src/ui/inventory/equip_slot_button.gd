extends Button

## Gegenstück zu inventory_slot_button.gd: macht einen Ausrüstungs-Slot-Button
## zur Drag-Quelle (Ziehen aus der Ausrüstung zurück ins Inventar = ablegen)
## und zum Drop-Ziel (ein Item aus dem Rucksack hierher ziehen = ausrüsten).
## slot_key kommt aus metadata/slot_key (siehe InventoryUI._make_equipment_slot).

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
	return {"type": "equipped_item", "slot_key": slot_key, "source": inventory_ui, "item": equipped}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return inventory_ui != null and inventory_ui.can_drop_equipment(data, get_meta(&"slot_key", ""))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory_ui:
		inventory_ui.drop_equipment(data, get_meta(&"slot_key", ""))
