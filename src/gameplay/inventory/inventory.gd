class_name Inventory
extends Resource

## Besitz eines Charakters: Slots plus Ausrüstung.
## ItemData → InventorySlot → Inventory

signal contents_changed

const QUICK_EQUIPMENT_SLOTS: Array[String] = [
	"guertel_1", "guertel_2", "guertel_3", "guertel_4", "guertel_5",
	"guertel_6", "guertel_7", "guertel_8", "guertel_9",
]

const EQUIPMENT_SLOTS: Array[String] = [
	"kopf", "rumpf", "primaer_hand", "nebenhand", "beine", "fuesse",
	"schmuck",
] + QUICK_EQUIPMENT_SLOTS

## Slots, deren Inhalt im Kampf als "Gegenstand verwenden" wählbar ist –
## was in der Hand gehalten oder in der Schnellausrüstung getragen wird, nicht das ganze Inventar.
const COMBAT_USABLE_SLOTS: Array[String] = [
	"primaer_hand", "nebenhand",
] + QUICK_EQUIPMENT_SLOTS

@export var slots: Array[InventorySlot] = []
@export var equipment: Dictionary = {}


static func can_place_item(item: ItemData, key: String) -> bool:
	if item == null or not EQUIPMENT_SLOTS.has(key):
		return false
	if key in ["primaer_hand", "nebenhand"] or QUICK_EQUIPMENT_SLOTS.has(key):
		return true
	return not item.consumable and item.equipment_slot == key


func ensure_equipment_slots() -> void:
	for slot in EQUIPMENT_SLOTS:
		if not equipment.has(slot):
			equipment[slot] = null
	# Legacy-Saves: der frühere Waffenplatz ist die rechte Hand.
	# Bei einer bereits belegten Hand bleibt das zusätzliche Exemplar im Rucksack.
	if equipment.has("waffe") and (equipment["waffe"] == null or equipment["waffe"] is ItemData):
		var legacy: Variant = equipment["waffe"]
		equipment.erase("waffe")
		if legacy is ItemData:
			if equipment.primaer_hand == null:
				equipment.primaer_hand = legacy
			else:
				add_item(legacy)


func is_empty() -> bool:
	return slots.is_empty()


func add_item(item: ItemData, count: int = 1) -> void:
	if item == null or count <= 0:
		return
	ensure_equipment_slots()
	if not item.world_object_id.is_empty():
		# Ein Weltobjekt kann innerhalb eines Inventars nur einmal existieren.
		for slot in slots:
			if _same_item(slot.item, item):
				return
		for equipped: Variant in equipment.values():
			if equipped is ItemData and _same_item(equipped, item):
				return
		count = 1
	var remaining := count
	var capacity := maxi(1, item.max_stack)
	for slot in slots:
		if _same_item(slot.item, item) and slot.count < capacity:
			var added := mini(remaining, capacity - slot.count)
			slot.count += added
			remaining -= added
	while remaining > 0:
		var slot := InventorySlot.new()
		slot.item = item
		slot.count = mini(remaining, capacity)
		slots.append(slot)
		remaining -= slot.count
	contents_changed.emit()


func remove_item(item: ItemData, count: int = 1) -> bool:
	if item == null or count <= 0:
		return false
	var available := 0
	for slot in slots:
		if _same_item(slot.item, item):
			available += slot.count
	if available < count:
		return false
	var remaining := count
	for i in range(slots.size() - 1, -1, -1):
		if _same_item(slots[i].item, item):
			var removed := mini(remaining, slots[i].count)
			slots[i].count -= removed
			remaining -= removed
			if slots[i].count == 0:
				slots.remove_at(i)
	contents_changed.emit()
	return true


func _same_item(a: ItemData, b: ItemData) -> bool:
	if a == null or b == null:
		return false
	if not a.world_object_id.is_empty() or not b.world_object_id.is_empty():
		return not a.world_object_id.is_empty() and a.world_object_id == b.world_object_id
	return a.item_id == b.item_id


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


## Gegenstände, die in der Hand oder in der Schnellausrüstung getragen werden – die im
## Kampf tatsächlich einsetzbare Teilmenge des Besitzes (nicht der Rucksack).
func get_combat_usable_items() -> Array[ItemData]:
	ensure_equipment_slots()
	var result: Array[ItemData] = []
	for slot_key in COMBAT_USABLE_SLOTS:
		var item: ItemData = equipment.get(slot_key)
		if item and not result.has(item):
			result.append(item)
	return result


## Verbraucht genau das ausgewählte Exemplar aus Hand/Schnellausrüstung.
## Der Rucksack wird dabei nicht berührt, selbst wenn dort dieselbe Vorlage liegt.
func consume_combat_item(item: ItemData) -> bool:
	if item == null:
		return false
	ensure_equipment_slots()
	for key in COMBAT_USABLE_SLOTS:
		if equipment.get(key) == item:
			equipment[key] = null
			contents_changed.emit()
			return true
	return false
