extends RefCounted

## Transaktionshilfe: nur Slot-Kopien ändern; Inventare/Items behalten ihre Identität.
static func valid_selector(data: Dictionary) -> bool:
	if not data.get("count") is int or data.count < 1 or data.count > 10000:
		return false
	var has_world := data.has("world_object_id")
	if has_world == data.has("item_id"):
		return false
	var id: Variant = data.world_object_id if has_world else data.item_id
	return id is String and not id.is_empty() and id == id.strip_edges() and (not has_world or data.count == 1)


static func matches(item: ItemData, data: Dictionary) -> bool:
	if data.has("world_object_id"):
		return item.world_object_id == data.world_object_id
	return item.world_object_id.is_empty() and item.item_id == data.item_id


static func count_items(inventory: Inventory, data: Dictionary) -> int:
	var count := 0
	for slot in inventory.slots:
		if slot and slot.item and matches(slot.item, data):
			count += slot.count
	return count


static func stage(world: WorldState, copies: Dictionary, id: Variant) -> Inventory:
	if not id is String:
		return null
	var character := world.characters.get_character(id)
	if character == null or character.inventory == null:
		return null
	if not copies.has(id):
		var copy := Inventory.new()
		copy.equipment = character.inventory.equipment.duplicate()
		for slot in character.inventory.slots:
			if slot == null or slot.item == null or slot.count < 1:
				return null
			copy.slots.append(slot.duplicate())
		copies[id] = copy
	return copies[id]


static func apply(world: WorldState, copies: Dictionary, effect: Dictionary) -> bool:
	var transfer: bool = effect.type == "transfer_item"
	if effect.size() != (5 if transfer else 4) or not valid_selector(effect):
		return false
	var source := stage(world, copies, effect.get("character_id"))
	if source == null or count_items(source, effect) < effect.count:
		return false
	var dest: Inventory = null
	if transfer:
		if effect.get("target_id") == effect.character_id:
			return false
		dest = stage(world, copies, effect.get("target_id"))
		if dest == null:
			return false
	if effect.has("world_object_id"):
		var entry: Variant = world.objects.get(effect.world_object_id)
		if not entry is Dictionary or entry.get("kind") != "item" or entry.get("removed") != true:
			return false
		# Auch Ausrüstung und bereits vorbereitete Transfers auf doppelte Besitzer prüfen.
		var owners := 0
		for id in world.characters.get_registered_ids():
			var inventory: Inventory = copies.get(id, world.characters.get_character(id).inventory)
			owners += count_items(inventory, effect)
			for item in inventory.equipment.values():
				if item is ItemData and matches(item, effect):
					owners += 1
		if owners != 1:
			return false
	var remaining: int = effect.count
	for i in range(source.slots.size() - 1, -1, -1):
		var slot := source.slots[i]
		if remaining == 0 or not matches(slot.item, effect):
			continue
		var moved := mini(remaining, slot.count)
		if dest:
			dest.add_item(slot.item, moved)
		slot.count -= moved
		remaining -= moved
		if slot.count == 0:
			source.slots.remove_at(i)
	if dest:
		var weight := 0.0
		for slot in dest.slots:
			if not is_finite(slot.item.weight) or slot.item.weight < 0:
				return false
			weight += slot.item.weight * slot.count
		for item in dest.equipment.values():
			if item is ItemData:
				if not is_finite(item.weight) or item.weight < 0:
					return false
				weight += item.weight
		if not is_finite(weight) or weight > world.characters.get_character(effect.target_id).get_max_carry_weight():
			return false
	return true
