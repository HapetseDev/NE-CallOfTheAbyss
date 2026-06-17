extends ColorRect

var inventory_ui: InventoryUI


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "inventory_item"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory_ui:
		inventory_ui.drop_item_from_slot(data["index"])
