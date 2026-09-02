class_name Inventory
extends Resource

## Besitz eines Charakters: Slots plus Ausrüstung.
## ItemData → InventorySlot → Inventory

signal contents_changed

const EQUIPMENT_SLOTS: Array[String] = [
	"kopf", "rumpf", "primaer_hand", "nebenhand", "beine", "fuesse", "waffe",
]

@export var slots: Array[InventorySlot] = []
@export var equipment: Dictionary = {}


func ensure_equipment_slots() -> void:
	for slot in EQUIPMENT_SLOTS:
		if not equipment.has(slot):
			equipment[slot] = null


func is_empty() -> bool:
	return slots.is_empty()


func add_item(item: ItemData, count: int = 1) -> void:
	if item == null or count <= 0:
		return
	ensure_equipment_slots()
	for slot in slots:
		if slot.item and slot.item.item_id == item.item_id:
			slot.count = mini(slot.count + count, item.max_stack)
			contents_changed.emit()
			return
	var new_slot := InventorySlot.new()
	new_slot.item = item
	new_slot.count = count
	slots.append(new_slot)
	contents_changed.emit()


func remove_item(item: ItemData, count: int = 1) -> bool:
	if item == null or count <= 0:
		return false
	for i in slots.size():
		if slots[i].item and slots[i].item.item_id == item.item_id:
			slots[i].count -= count
			if slots[i].count <= 0:
				slots.remove_at(i)
			contents_changed.emit()
			return true
	return false


func has_item(item_id: String) -> bool:
	for slot in slots:
		if slot.item and slot.item.item_id == item_id:
			return true
	return false


func equip(slot_key: String, item: ItemData) -> void:
	ensure_equipment_slots()
	if not equipment.has(slot_key):
		push_warning("Inventory: Unbekannter Slot '%s'" % slot_key)
		return
	equipment[slot_key] = item
	contents_changed.emit()


func unequip(slot_key: String) -> ItemData:
	ensure_equipment_slots()
	if not equipment.has(slot_key):
		push_warning("Inventory: Unbekannter Slot '%s'" % slot_key)
		return null
	var item: ItemData = equipment[slot_key]
	equipment[slot_key] = null
	contents_changed.emit()
	return item
