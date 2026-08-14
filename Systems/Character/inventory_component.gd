class_name InventoryComponent extends Node

signal changed

var _slots: Array[InventorySlot] = []
var equipment: Dictionary = {
	"kopf": null, "rumpf": null, "primaer_hand": null,
	"nebenhand": null, "beine": null, "fuesse": null,
}


func add_item(item: Item, count: int = 1) -> void:
	for slot in _slots:
		if slot.item.item_id == item.item_id:
			slot.count = mini(slot.count + count, item.max_stapel)
			changed.emit()
			return
	var new_slot := InventorySlot.new()
	new_slot.item = item
	new_slot.count = count
	_slots.append(new_slot)
	changed.emit()


func remove_item(item: Item, count: int = 1) -> bool:
	for i in _slots.size():
		if _slots[i].item.item_id == item.item_id:
			_slots[i].count -= count
			if _slots[i].count <= 0:
				_slots.remove_at(i)
			changed.emit()
			return true
	return false


func has_item(item_id: String) -> bool:
	for slot in _slots:
		if slot.item.item_id == item_id:
			return true
	return false


func get_slots() -> Array[InventorySlot]:
	return _slots


func equip(slot_key: String, item: Item) -> void:
	if not equipment.has(slot_key):
		push_warning("InventoryComponent: Unbekannter Slot '%s'" % slot_key)
		return
	equipment[slot_key] = item
	changed.emit()


func unequip(slot_key: String) -> Item:
	if not equipment.has(slot_key):
		push_warning("InventoryComponent: Unbekannter Slot '%s'" % slot_key)
		return null
	var item: Item = equipment[slot_key]
	equipment[slot_key] = null
	changed.emit()
	return item
