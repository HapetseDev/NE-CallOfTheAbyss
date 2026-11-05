class_name WorldValueCodec extends RefCounted

## JSON-Werte und eine feste Liste von Datenresources. Keine Nodes/Skripte
## oder frei wählbaren Resourcepfade aus einem Spielstand instanziieren.
const TYPES := {
	"ShopData": "res://src/resources/items/shop/shop_data.gd",
	"ShopEntry": "res://src/resources/items/shop/shop_entry.gd",
	"CharacterResource": "res://src/resources/characters/character_sheet.gd",
	"Inventory": "res://src/gameplay/inventory/inventory.gd",
	"InventorySlot": "res://src/gameplay/inventory/InventorySlot.gd",
	"ItemData": "res://src/resources/items/item_data.gd",
	"ItemUsageMode": "res://src/resources/items/item_usage_mode.gd",
	"LearnedSkill": "res://src/resources/characters/learned_skill.gd",
	"RelationshipEntry": "res://src/resources/characters/relationship_entry.gd",
	"CompanionEntry": "res://src/resources/characters/companion_entry.gd",
}
var failed: bool = false
var migrate_legacy_voice: bool = false
var migrate_legacy_character_state: bool = false
var migrate_legacy_combat_items: bool = false
var migrate_legacy_armor_items: bool = false
var migrate_legacy_weapon_ranges: bool = false
var migrate_legacy_anatomy: bool = false


func encode(value: Variant) -> Variant:
	if value == null or value is bool or value is String or value is int:
		return value
	if value is float:
		if not is_finite(value):
			failed = true
		return value
	if value is Vector3:
		return {"kind": "Vector3", "value": [value.x, value.y, value.z]}
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(encode(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			if not key is String:
				failed = true
				return null
			result[key] = encode(value[key])
		return {"kind": "Dictionary", "value": result}
	if value is Texture2D and not value.resource_path.is_empty():
		return {"kind": "Texture2D", "value": value.resource_path}
	if value is Resource and value.get_script():
		for type: String in TYPES:
			if value.get_script().resource_path == TYPES[type]:
				var fields: Dictionary = {}
				for property in value.get_property_list():
					if _stored(property):
						fields[property.name] = encode(value.get(property.name))
				return {"kind": type, "value": fields}
	failed = true
	return null


func decode(value: Variant, depth: int = 0) -> Variant:
	if depth > 40:
		failed = true
		return null
	if value == null or value is bool or value is String or value is int or value is float:
		return value
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(decode(entry, depth + 1))
		return result
	if not value is Dictionary or value.size() != 2 or not value.has("kind") or not value.has("value"):
		failed = true
		return null
	var kind: Variant = value.kind
	var data: Variant = value.value
	if kind == "Dictionary" and data is Dictionary:
		var result: Dictionary = {}
		for key in data:
			result[key] = decode(data[key], depth + 1)
		return result
	if kind == "Vector3" and data is Array and data.size() == 3:
		for number in data:
			if not (number is float or number is int) or not is_finite(number):
				failed = true
				return null
		return Vector3(data[0], data[1], data[2])
	if kind == "Texture2D" and data is String and data.begins_with("res://assets/") and not ".." in data and data.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "svg"]:
		var texture := load(data) as Texture2D if ResourceLoader.exists(data) else null
		failed = failed or texture == null
		return texture
	if not kind is String or not TYPES.has(kind) or not data is Dictionary:
		failed = true
		return null
	if migrate_legacy_anatomy:
		data = data.duplicate()
		if kind == "CharacterResource" and not data.has("body_profile_id"):
			data.body_profile_id = "human"
		if kind == "ItemUsageMode" and not data.has("damage_type"):
			data.damage_type = "blunt"
		if kind == "ItemData":
			if not data.has("armor_zones"):
				data.armor_zones = []
			if not data.has("armor_protection"):
				data.armor_protection = {"kind": "Dictionary", "value": {}}
	if kind == "CharacterResource" and (not data.get("body_profile_id") is String or not CombatAnatomy.PROFILE_PATHS.has(data.body_profile_id)):
		failed = true
		return null
	if kind == "ItemUsageMode" and data.get("damage_type") not in CombatAnatomy.DAMAGE_TYPES:
		failed = true
		return null
	if migrate_legacy_character_state and kind == "CharacterResource" and not data.has("is_defeated"):
		data = data.duplicate()
		data.is_defeated = false
	if migrate_legacy_armor_items and kind == "ItemData" and not data.has("is_armor"):
		data = data.duplicate()
		data.is_armor = false
	if migrate_legacy_combat_items and kind == "ItemData":
		data = data.duplicate()
		if not data.has("combat_value"):
			data.combat_value = 6 if data.get("item_id") == "Messer" else (4 if data.get("item_id") == "Stein" else 1)
		if not data.has("break_chance"):
			data.break_chance = 0.0
		if not data.has("combat_skill_id"):
			data.combat_skill_id = "kurze_klingen" if data.get("item_id") == "Messer" else ""
	if kind == "CharacterResource":
		if migrate_legacy_voice and not data.has("voice"):
			data = data.duplicate()
			data.voice = 1.0
		var voice: Variant = data.get("voice")
		if not (voice is float or voice is int) or not is_finite(voice) or voice < 0.25 or voice > 4.0:
			failed = true
			return null
	var resource: Resource = load(TYPES[kind]).new()
	if kind == "ItemUsageMode":
		if migrate_legacy_weapon_ranges:
			data = data.duplicate()
			if not data.has("range_meters"):
				data.range_meters = 10.0 if data.get("range_type") == ItemUsageMode.RangeType.THROWN else 1.5
			if not data.has("ammunition_item_id"):
				data.ammunition_item_id = ""
		var reach: Variant = data.get("range_meters")
		if not (reach is float or reach is int) or not is_finite(reach) or reach <= 0.0 or reach > 1000.0 or not data.get("ammunition_item_id") is String:
			failed = true
			return null
	var properties: Dictionary = {}
	for property in resource.get_property_list():
		if _stored(property):
			properties[property.name] = property
	if kind == "ItemData":
		if not data.get("is_armor") is bool:
			failed = true
			return null
		if not data.get("combat_value") is float and not data.get("combat_value") is int:
			failed = true
			return null
		if not is_finite(data.combat_value) or data.combat_value < 1 or data.combat_value != floor(data.combat_value) or not data.get("combat_skill_id") is String:
			failed = true
			return null
	if kind == "ItemData" and (not (data.get("break_chance") is float or data.get("break_chance") is int) or not is_finite(data.break_chance) or data.break_chance < 0.0 or data.break_chance > 1.0):
		failed = true
		return null
	if data.size() != properties.size():
		failed = true
		return null
	for key in data:
		if not properties.has(key):
			failed = true
			return null
		var decoded: Variant = decode(data[key], depth + 1)
		var type: int = properties[key].type
		if type == TYPE_INT and (decoded is float or decoded is int) and is_finite(decoded) and decoded == floor(decoded):
			decoded = int(decoded)
		elif type == TYPE_FLOAT and (decoded is float or decoded is int):
			decoded = float(decoded)
		elif type == TYPE_OBJECT:
			if decoded != null and not decoded is Resource:
				failed = true
			elif decoded != null and not is_instance_of(decoded, load(TYPES.get(properties[key].hint_string, TYPES[kind]))):
				# Texture2D is a native class rather than a script.
				if properties[key].hint_string != "Texture2D" or not decoded is Texture2D:
					failed = true
		elif typeof(decoded) != type:
			failed = true
		if failed:
			return null
		if type == TYPE_ARRAY:
			var target: Array = resource.get(key)
			if target.is_typed():
				for entry in decoded:
					if target.get_typed_builtin() == TYPE_OBJECT:
						if entry == null or not is_instance_of(entry, target.get_typed_script()):
							failed = true
					elif target.get_typed_builtin() == TYPE_INT and (entry is float or entry is int) and entry == floor(entry):
						pass
					elif typeof(entry) != target.get_typed_builtin():
						failed = true
			if failed:
				return null
			target.assign(decoded)
		else:
			resource.set(key, decoded)
	if kind == "ItemData" and not _valid_armor(resource as ItemData):
		failed = true
		return null
	return resource


func _valid_armor(item: ItemData) -> bool:
	for type in item.armor_protection:
		var amount: Variant = item.armor_protection[type]
		if type not in CombatAnatomy.DAMAGE_TYPES or not (amount is int or amount is float) or not is_finite(amount) or amount < 0 or amount > 1000:
			return false
	var seen: Array[String] = []
	for id in item.armor_zones:
		if id in seen:
			return false
		seen.append(id)
		var known := false
		for profile_id in CombatAnatomy.PROFILE_PATHS:
			if CombatAnatomy.profile_for_id(profile_id).get_zone(id) != null:
				known = true
		if not known:
			return false
	return true


func _stored(property: Dictionary) -> bool:
	return (property.usage & PROPERTY_USAGE_STORAGE) != 0 and (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
