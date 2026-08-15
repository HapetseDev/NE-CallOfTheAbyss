class_name Inventory extends Node

signal changed

@export var capacity: int = 20

var _slots: Array[InventorySlot] = []


func _ready() -> void:
	for i in capacity:
		_slots.append(InventorySlot.new())


## Fügt ein Item hinzu. Gibt die Anzahl zurück, die nicht reingepasst hat (0 = alles drin).
func add_item(item: Item, amount: int = 1) -> int:
	if item == null or amount <= 0:
		return amount
	var remaining := amount
	# Schritt 1: in bestehende Stacks auffüllen
	for slot in _slots:
		if remaining <= 0:
			break
		if slot.is_empty() or not slot.can_stack_with(item):
			continue
		var to_add := mini(slot.space_remaining(), remaining)
		slot.count += to_add
		remaining -= to_add
	# Schritt 2: neue leere Slots belegen
	for slot in _slots:
		if remaining <= 0:
			break
		if not slot.is_empty():
			continue
		var to_add := mini(item.max_stapel, remaining)
		slot.item = item
		slot.count = to_add
		remaining -= to_add
	if remaining < amount:
		changed.emit()
	return remaining


## Entfernt eine Menge eines Items anhand der ID. Gibt true zurück wenn erfolgreich.
func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	var remaining := amount
	for slot in _slots:
		if remaining <= 0:
			break
		if slot.is_empty() or slot.item.item_id != item_id:
			continue
		var to_remove := mini(slot.count, remaining)
		slot.count -= to_remove
		remaining -= to_remove
		if slot.count <= 0:
			slot.clear()
	changed.emit()
	return true


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount


func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in _slots:
		if not slot.is_empty() and slot.item.item_id == item_id:
			total += slot.count
	return total


func get_slots() -> Array[InventorySlot]:
	return _slots


func get_slot(index: int) -> InventorySlot:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


func is_full() -> bool:
	for slot in _slots:
		if slot.is_empty():
			return false
	return true


## Für späteres Save/Load: gibt eine kompakte Liste aller belegten Slots zurück.
func serialize() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in _slots.size():
		var slot := _slots[i]
		if not slot.is_empty():
			result.append({
				"id": slot.item.item_id,
				"count": slot.count,
				"slot": i,
			})
	return result
