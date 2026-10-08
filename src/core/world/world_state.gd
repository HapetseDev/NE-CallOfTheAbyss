class_name WorldState extends RefCounted

## Autoritativer Sitzungszustand ohne Node-Referenzen.
## Inventarbesitz liegt ausschließlich in CharacterResource.inventory.
var characters := CharacterRegistry.new()
var events := preload("res://src/core/world/world_event_log.gd").new()
var flags: Dictionary = {}
## Leer vor Aufbau der Spielwelt; danach explizite aktive Besetzung.
var party_state: Dictionary = {}
var quest_states: Dictionary = {"bandit": "not_started"}
## ShopData-Laufzeitkopien, vom ShopManager angezeigt.
var shops: Dictionary = {}
var map_exploration: Dictionary = {}
var locations: Dictionary = {}
var objects: Dictionary = {}
var placements: Dictionary = {}
var active_location: String = ""
var next_object_id: int = 1


func allocate_object_id() -> String:
	var id := "drop_%d" % next_object_id
	while objects.has(id):
		next_object_id += 1
		id = "drop_%d" % next_object_id
	next_object_id += 1
	return id


func get_object_owner(object_id: String) -> String:
	if object_id.is_empty():
		return ""
	for id in characters.get_registered_ids():
		var inventory := characters.get_character(id).inventory
		if inventory == null:
			continue
		for slot in inventory.slots:
			if slot.item and slot.item.world_object_id == object_id:
				return id
		for item: Variant in inventory.equipment.values():
			if item is ItemData and item.world_object_id == object_id:
				return id
	return ""


func remove_object(id: String) -> void:
	if objects.has(id):
		objects[id].removed = true


func clear() -> void:
	_facts.clear()
	_knowledge.clear()
	characters.clear()
	events.clear()
	flags.clear()
	party_state.clear()
	quest_states = {"bandit": "not_started"}
	shops.clear()
	map_exploration.clear()
	locations.clear()
	objects.clear()
	placements.clear()
	active_location = ""
	next_object_id = 1


# Fakten beschreiben Aussagen; Wissen ordnet diese Aussagen einzelnen Figuren zu.
# Kein implizites globales Wissen und keine Ableitung aus Quest-Flags.
var _facts: Dictionary = {}
var _knowledge: Dictionary = {}


func define_fact(id: String, subject: String, predicate: String, object: String) -> bool:
	for value in [id, subject, predicate, object]:
		if value.is_empty() or value != value.strip_edges():
			return false
	var statement := {"subject": subject, "predicate": predicate, "object": object}
	if _facts.has(id):
		return _facts[id] == statement
	_facts[id] = statement
	return true


func get_fact(id: String) -> Dictionary:
	return _facts.get(id, {}).duplicate(true)


func learn_fact(character_id: String, fact_id: String) -> bool:
	if characters.get_character(character_id) == null or not _facts.has(fact_id):
		return false
	if not _knowledge.has(character_id):
		_knowledge[character_id] = []
	if not fact_id in _knowledge[character_id]:
		_knowledge[character_id].append(fact_id)
	return true


func knows_fact(character_id: String, fact_id: String) -> bool:
	return fact_id in _knowledge.get(character_id, [])


func forget_fact(character_id: String, fact_id: String) -> bool:
	if not knows_fact(character_id, fact_id):
		return false
	_knowledge[character_id].erase(fact_id)
	if _knowledge[character_id].is_empty():
		_knowledge.erase(character_id)
	return true


func knowledge_snapshot() -> Dictionary:
	return {"facts": _facts.duplicate(true), "knowledge": _knowledge.duplicate(true)}


## Atomar validieren: ungültige Referenzen verändern vorhandenes Wissen nicht.
func restore_knowledge(data: Dictionary) -> bool:
	if data.size() != 2 or not data.get("facts") is Dictionary or not data.get("knowledge") is Dictionary:
		return false
	for id in data.facts:
		var fact: Variant = data.facts[id]
		if not id is String or id.is_empty() or id != id.strip_edges() or not fact is Dictionary or fact.size() != 3:
			return false
		for key in ["subject", "predicate", "object"]:
			var value: Variant = fact.get(key)
			if not value is String or value.is_empty() or value != value.strip_edges():
				return false
	for id in data.knowledge:
		if not id is String or characters.get_character(id) == null or not data.knowledge[id] is Array:
			return false
		var seen: Dictionary = {}
		for fact_id in data.knowledge[id]:
			if not fact_id is String or not data.facts.has(fact_id) or seen.has(fact_id):
				return false
			seen[fact_id] = true
	_facts = data.facts.duplicate(true)
	_knowledge = data.knowledge.duplicate(true)
	return true


func get_quest_state(id: String) -> String:
	return quest_states.get(id, "")


func sync_quest_flags() -> void:
	preload("res://src/core/world/quest_progress.gd").reconcile(quest_states, flags)
