extends RefCounted

## Sitzungsbezogene IDs, keine Nodes/Resources und kein Wiederabspielen beim Laden.
const SCHEMAS := {
	"npc_defeated": ["character_id"],
	"quest_completed": ["character_id", "quest_id"],
	"item_transferred": ["character_id", "target_id", "count"],
	"item_stolen": ["character_id", "target_id", "count"],
	"item_removed": ["character_id", "count"],
	"item_bought": ["character_id", "shop_id", "count"],
	"item_sold": ["character_id", "shop_id", "count"],
}
var _entries: Array = []


static func valid_payload(type: Variant, data: Variant) -> bool:
	if not type is String or not SCHEMAS.has(type) or not data is Dictionary:
		return false
	var keys: Array = SCHEMAS[type].duplicate()
	if type.begins_with("item_"):
		if data.has("item_id") == data.has("world_object_id"):
			return false
		keys.append("item_id" if data.has("item_id") else "world_object_id")
	if data.size() != keys.size():
		return false
	for key in keys:
		var value: Variant = data.get(key)
		if key == "count":
			if not (value is int or value is float) or not is_finite(value) or value != floor(value) or value < 1 or value > 10000:
				return false
		elif not value is String or value.is_empty() or value != value.strip_edges():
			return false
	if data.has("world_object_id") and data.count != 1:
		return false
	return true


static func valid_batch(batch: Array) -> bool:
	for entry in batch:
		if not entry is Dictionary or entry.size() != 2 or not valid_payload(entry.get("type"), entry.get("data")):
			return false
	return true


func append_batch(batch: Array) -> bool:
	if not valid_batch(batch):
		return false
	for event in batch:
		var sequence := _entries.size() + 1
		var data: Dictionary = {}
		# GDScript-Punktzugriff erzeugt teils StringName-Schlüssel; JSON verlangt String.
		for key in event.data:
			data[str(key)] = event.data[key]
		if data.has("count"):
			data.count = int(data.count)
		_entries.append({"id": "event_%d" % sequence, "sequence": sequence, "type": event.type, "data": data})
	return true


func snapshot() -> Array:
	return _entries.duplicate(true)


func restore(entries: Array) -> bool:
	var copy: Array = []
	for entry in entries:
		var expected := copy.size() + 1
		if not entry is Dictionary or entry.size() != 4 or entry.get("id") != "event_%d" % expected or entry.get("sequence") != expected:
			return false
		if not valid_payload(entry.get("type"), entry.get("data")):
			return false
		var restored: Dictionary = entry.duplicate(true)
		restored.sequence = expected
		if restored.data.has("count"):
			restored.data.count = int(restored.data.count)
		copy.append(restored)
	_entries = copy
	return true


func has_event(type: String, filters: Dictionary) -> bool:
	if not SCHEMAS.has(type):
		return false
	var allowed: Array = SCHEMAS[type].duplicate()
	if type.begins_with("item_"):
		allowed.append_array(["item_id", "world_object_id"])
	for key in filters:
		if not allowed.has(key):
			return false
	for entry in _entries:
		if entry.type != type:
			continue
		var matches := true
		for key in filters:
			if not entry.data.has(key) or entry.data[key] != filters[key]:
				matches = false
		if matches:
			return true
	return false


func clear() -> void:
	_entries.clear()
