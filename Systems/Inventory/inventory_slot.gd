class_name InventorySlot extends Resource

var item: Item = null
var count: int = 0


func is_empty() -> bool:
	return item == null or count <= 0


func space_remaining() -> int:
	if item == null:
		return 0
	return item.max_stapel - count


func can_stack_with(other: Item) -> bool:
	if item == null or other == null:
		return false
	return item.item_id == other.item_id and item.max_stapel > 1


func clear() -> void:
	item = null
	count = 0
