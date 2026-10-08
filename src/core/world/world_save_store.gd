class_name WorldSaveStore extends RefCounted

const VERSION := 8
const MAX_BYTES := 8 * 1024 * 1024
var last_error: String = ""


func write(world: WorldState, path: String) -> Error:
	last_error = ""
	var character_data: Dictionary = {}
	for id in world.characters.get_registered_ids():
		var template := world.characters.get_template(id)
		if template.resource_path.is_empty():
			last_error = "Charaktervorlage ohne stabilen Resourcepfad: " + id
			return ERR_INVALID_DATA
		character_data[id] = {"template": template.resource_path, "data": world.characters.get_character(id)}
	var codec := WorldValueCodec.new()
	var payload: Variant = codec.encode({
		"events": world.events.snapshot(), "knowledge_state": world.knowledge_snapshot(), "shops": world.shops,
		"party_state": world.party_state, "quest_states": world.quest_states, "characters": character_data, "flags": world.flags, "locations": world.locations,
		"map_exploration": world.map_exploration, "objects": world.objects, "placements": world.placements,
		"active_location": world.active_location, "next_object_id": world.next_object_id,
	})
	if codec.failed:
		last_error = "Nicht speicherbarer Wert im Weltzustand."
		return ERR_INVALID_DATA
	var text := JSON.stringify({"version": VERSION, "world": payload})
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return ERR_OUT_OF_MEMORY
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Temporäre Speicherdatei nicht schreibbar."
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if read(path + ".tmp") == null:
		return ERR_INVALID_DATA
	# Erst eine vollständig geschriebene und geprüfte Datei ersetzt den bisherigen Stand.
	return DirAccess.rename_absolute(path + ".tmp", path)


## Liefert einen neuen, vollständig geprüften Zustand. Der aktive Zustand
## wird niemals verändert. Installation nur an einer Szenengrenze.
func read(path: String) -> WorldState:
	last_error = ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return _reject("Datei fehlt oder ist zu groß.")
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return _reject("Ungültiges JSON.")
	var root: Variant = json.data
	if not root is Dictionary or (root.get("version") != 1 and root.get("version") != 2 and root.get("version") != 3 and root.get("version") != 4 and root.get("version") != 5 and root.get("version") != 6 and root.get("version") != 7 and root.get("version") != VERSION) or not root.has("world"):
		return _reject("Unbekannte Speicherversion.")
	var codec := WorldValueCodec.new()
	codec.migrate_legacy_character_state = root.version < 3
	var data: Variant = codec.decode(root.world)
	if codec.failed or not data is Dictionary:
		return _reject("Ungültige Weltdaten.")
	if root.version < 5:
		data.events = []
	if not data.get("events") is Array:
		return _reject("Fehlendes Ereignisprotokoll.")
	if root.version < 4:
		data.shops = {}
	if not data.get("shops") is Dictionary:
		return _reject("Fehlende Händlerdaten.")
	for id in data.shops:
		var shop: Variant = data.shops[id]
		if not shop is ShopData or shop.shop_id != id or not preload("res://src/core/world/shop_rules.gd").valid_shop(shop):
			return _reject("Ungültige Händlerdaten.")
	# Version 1 kannte weder Fakten noch individuelles Wissen.
	if root.version == 1:
		if data.has("knowledge_state"):
			return _reject("Wissensdaten sind in Version 1 nicht zulässig.")
		data.knowledge_state = {"facts": {}, "knowledge": {}}
	for key in ["characters", "flags", "locations", "objects", "placements"]:
		if not data.get(key) is Dictionary:
			return _reject("Fehlender Datenbereich: " + key)
	if not data.get("active_location") is String or not (data.get("next_object_id") is float or data.get("next_object_id") is int):
		return _reject("Ungültiger Orts-/Objektzähler.")
	if data.next_object_id < 1 or data.next_object_id > 9007199254740991 or data.next_object_id != floor(data.next_object_id):
		return _reject("Ungültiger Objektzähler.")
	var world := WorldState.new()
	if not world.events.restore(data.events):
		return _reject("Ungültiges Ereignisprotokoll.")
	for id in data.characters:
		var entry: Variant = data.characters[id]
		if not entry is Dictionary or not entry.get("template") is String or not entry.get("data") is CharacterResource:
			return _reject("Ungültiger Charaktereintrag.")
		var template_path: String = entry.template
		if not template_path.begins_with("res://src/resources/characters/sheets/") or ".." in template_path or template_path.get_extension() != "tres" or not ResourceLoader.exists(template_path):
			return _reject("Unbekannte Charaktervorlage.")
		var template := load(template_path) as CharacterResource
		var character: CharacterResource = entry.data
		if character.inventory == null:
			return _reject("Fehlendes Inventar.")
		if template == null or character.character_id != id or not world.characters.restore_character(id, template, character):
			return _reject("Widersprüchliche Charakteridentität: %s / %s / %s" % [id, character.character_id, template.character_id if template else "null"])
		for slot in character.inventory.slots:
			if slot == null or slot.item == null or slot.count < 1 or slot.count > maxi(1, slot.item.max_stack):
				return _reject("Ungültiger Inventarstapel.")
		for slot in character.inventory.equipment:
			if not Inventory.EQUIPMENT_SLOTS.has(slot) or (character.inventory.equipment[slot] != null and not character.inventory.equipment[slot] is ItemData):
				return _reject("Ungültige Ausrüstung.")
	for id in data.locations:
		if not id is String or not id.begins_with("res://src/world/levels/") or ".." in id or not ResourceLoader.exists(id, "PackedScene") or not data.locations[id] is bool:
			return _reject("Unbekannter Ort.")
	if not data.active_location.is_empty() and not data.locations.has(data.active_location):
		return _reject("Aktiver Ort fehlt.")
	for id in data.placements:
		var entry: Variant = data.placements[id]
		if world.characters.get_character(id) == null or not entry is Dictionary or not data.locations.has(entry.get("location")) or not entry.get("position") is Vector3:
			return _reject("Ungültiger Charakteraufenthalt.")
	for id in data.objects:
		var entry: Variant = data.objects[id]
		if id.is_empty() or not entry is Dictionary or not data.locations.has(entry.get("location")) or not entry.get("position") is Vector3 or not entry.get("removed") is bool or not entry.get("kind") in ["plant", "item"]:
			return _reject("Ungültiges Weltobjekt.")
		if entry.kind == "item" and (not entry.get("item") is ItemData or entry.item.world_object_id != id):
			return _reject("Ungültige Gegenstandsidentität.")
	if not data.get("knowledge_state") is Dictionary or not world.restore_knowledge(data.knowledge_state):
		return _reject("Ungültige Fakten oder Wissensreferenzen.")
	if root.version < 8:
		data.map_exploration = {}
	if not _valid_map(data.get("map_exploration"), data.locations):
		return _reject("Ungültiger Kartenerkundungsstand.")
	world.map_exploration = data.map_exploration
	world.shops = data.shops
	if root.version < 6:
		data.quest_states = {"bandit": preload("res://src/core/world/quest_progress.gd").from_flags(data.flags)}
	if not data.get("quest_states") is Dictionary or data.quest_states.size() != 1 or data.quest_states.get("bandit") != preload("res://src/core/world/quest_progress.gd").from_flags(data.flags):
		return _reject("Ungültiger oder widersprüchlicher Questzustand.")
	if root.version < 7:
		data.party_state = preload("res://src/core/world/party_state.gd").migrate(data.active_location)
	if not preload("res://src/core/world/party_state.gd").valid(data.get("party_state"), world.characters, data.active_location.is_empty()):
		return _reject("Ungültige oder nicht unterstützte Partybesetzung.")
	world.party_state = data.party_state
	world.quest_states = data.quest_states
	world.flags = data.flags
	world.locations = data.locations
	world.objects = data.objects
	world.placements = data.placements
	world.active_location = data.active_location
	world.next_object_id = int(data.next_object_id)
	var owners: Dictionary = {}
	for id in world.characters.get_registered_ids():
		var inventory := world.characters.get_character(id).inventory
		var items: Array = inventory.equipment.values()
		for slot in inventory.slots:
			if not slot.item.world_object_id.is_empty() and slot.count != 1:
				return _reject("Eindeutiges Objekt mehrfach gestapelt.")
			items.append(slot.item)
		for item in items:
			if item == null or item.world_object_id.is_empty():
				continue
			if owners.has(item.world_object_id) or not world.objects.has(item.world_object_id) or not world.objects[item.world_object_id].removed or world.objects[item.world_object_id].kind != "item":
				return _reject("Widersprüchlicher Gegenstandsbesitz.")
			owners[item.world_object_id] = id
	return world


func _reject(message: String) -> WorldState:
	last_error = message
	return null


func _valid_map(value: Variant, locations: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	for location in value:
		var entry: Variant = value[location]
		if not locations.has(location) or not entry is Dictionary or entry.size() != 2 or not entry.get("cells") is Dictionary or not entry.get("markers") is Dictionary:
			return false
		for key in entry.cells:
			var parts: PackedStringArray = key.split(",")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not entry.cells[key] is bool or not entry.cells[key]:
				return false
		for id in entry.markers:
			var marker: Variant = entry.markers[id]
			if id.is_empty() or not marker is Dictionary or marker.size() != 3 or not marker.get("position") is Vector3 or not marker.get("label") is String or not marker.get("kind") in ["npc", "object"]:
				return false
	return true
