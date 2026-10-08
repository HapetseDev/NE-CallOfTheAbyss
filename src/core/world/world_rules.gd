extends RefCounted

const QuestProgress = preload("res://src/core/world/quest_progress.gd")
const InventoryRules = preload("res://src/core/world/inventory_rules.gd")

## Erster gemeinsamer Conditions/Effects-Vertrag, unabhängig von Nodes/Dialogen.
## Unbekannte Operationen und fehlerhafte Parameter werden geschlossen abgelehnt.
static func meets(world: WorldState, condition: Dictionary) -> bool:
	if condition.get("type") == "quest_state":
		return condition.size() == 3 and condition.get("quest_id") == "bandit" and condition.get("state") in QuestProgress.STATES and world.get_quest_state(condition.quest_id) == condition.state
	if condition.get("type") == "event_occurred":
		return condition.size() == 3 and condition.get("event_type") is String and condition.get("filters") is Dictionary and world.events.has_event(condition.event_type, condition.filters)
	if condition.get("type") == "has_item":
		if condition.size() != 4 or not _id(condition.get("character_id")) or not InventoryRules.valid_selector(condition):
			return false
		var character := world.characters.get_character(condition.character_id)
		return character != null and character.inventory != null and InventoryRules.count_items(character.inventory, condition) >= condition.count
	if condition.get("type") == "relationship_at_least":
		if condition.size() != 4 or not _id(condition.get("character_id")) or not _id(condition.get("target_id")) or not condition.get("minimum") is int:
			return false
		if condition.minimum < CharacterEnums.BEZIEHUNG_MIN or condition.minimum > CharacterEnums.BEZIEHUNG_MAX:
			return false
		var observer := world.characters.get_character(condition.character_id)
		var target := world.characters.get_character(condition.target_id)
		return observer != null and target != null and RelationshipService.get_disposition(observer, target) >= condition.minimum
	if condition.get("type") == "flag_equals":
		return condition.size() == 3 and _id(condition.get("key")) and condition.get("value") is bool and world.flags.get(condition.key, false) == condition.value
	if condition.size() != 3 or condition.get("type") != "knows_fact":
		return false
	if not _id(condition.get("character_id")) or not _id(condition.get("fact_id")):
		return false
	if world.characters.get_character(condition.character_id) == null:
		return false
	return world.knows_fact(condition.character_id, condition.fact_id)


## Wissen, Flags und Gold erst getrennt vorbereiten, dann gemeinsam übernehmen.
## Keine Signale, UI-Aufrufe oder beliebigen Methoden aus Datendefinitionen.
static func apply(world: WorldState, effects: Array) -> bool:
	var candidate := WorldState.new()
	candidate.characters = world.characters
	if not candidate.restore_knowledge(world.knowledge_snapshot()):
		return false
	var flags := world.flags.duplicate(true)
	var quests := world.quest_states.duplicate(true)
	var gold: Dictionary = {}
	var relationships: Dictionary = {}
	var inventories: Dictionary = {}
	var stocks: Dictionary = {}
	var pending_events: Array = []
	for effect in effects:
		if not effect is Dictionary:
			return false
		match effect.get("type"):
			"start_quest":
				if effect.size() != 2 or not effect.get("quest_id") is String or not QuestProgress.start(quests, flags, effect.quest_id):
					return false
			"complete_quest":
				if effect.size() != 4 or not _id(effect.get("quest_id")) or not _id(effect.get("character_id")) or not _id(effect.get("flag")):
					return false
				if world.characters.get_character(effect.character_id) == null or flags.get(effect.flag, false) or world.events.has_event("quest_completed", {"quest_id": effect.quest_id}):
					return false
				for pending in pending_events:
					if pending.type == "quest_completed" and pending.data.quest_id == effect.quest_id:
						return false
				if effect.quest_id == "bandit":
					if effect.flag != "quest_bandit_done" or quests.get("bandit") != "ready":
						return false
					quests["bandit"] = "completed"
				flags[effect.flag] = true
				pending_events.append({"type": "quest_completed", "data": {"quest_id": effect.quest_id, "character_id": effect.character_id}})
			"steal_item":
				var transfer: Dictionary = effect.duplicate()
				transfer.type = "transfer_item"
				if not InventoryRules.apply(world, inventories, transfer):
					return false
				var data: Dictionary = effect.duplicate()
				data.erase("type")
				data.character_id = effect.target_id
				data.target_id = effect.character_id
				pending_events.append({"type": "item_stolen", "data": data})
			"shop_buy", "shop_sell":
				if not preload("res://src/core/world/shop_rules.gd").apply(world, inventories, gold, stocks, effect):
					return false
				var data: Dictionary = effect.duplicate()
				data.erase("type")
				pending_events.append({"type": "item_bought" if effect.type == "shop_buy" else "item_sold", "data": data})
			"transfer_item", "remove_item":
				if not InventoryRules.apply(world, inventories, effect):
					return false
				var data: Dictionary = effect.duplicate()
				data.erase("type")
				pending_events.append({"type": "item_transferred" if effect.type == "transfer_item" else "item_removed", "data": data})
			"change_relationship":
				if effect.size() != 4 or not _id(effect.get("character_id")) or not _id(effect.get("target_id")) or not effect.get("amount") is int:
					return false
				var observer := world.characters.get_character(effect.character_id)
				var target := world.characters.get_character(effect.target_id)
				if observer == null or target == null:
					return false
				if not relationships.has(effect.character_id):
					var copy := observer.duplicate() as CharacterResource
					copy.beziehungen = []
					for entry in observer.beziehungen:
						copy.beziehungen.append(entry.duplicate() if entry else null)
					relationships[effect.character_id] = copy
				if not RelationshipService.change_disposition(relationships[effect.character_id], target, effect.amount):
					return false
			"set_flag":
				if effect.size() != 3 or not _id(effect.get("key")) or not effect.get("value") is bool:
					return false
				flags[effect.key] = effect.value
				QuestProgress.reconcile(quests, flags)
			"change_gold":
				if effect.size() != 3 or not _id(effect.get("character_id")) or not effect.get("amount") is int:
					return false
				var character := world.characters.get_character(effect.character_id)
				if character == null:
					return false
				var current: int = gold.get(effect.character_id, character.gold)
				# Begrenzter Geldbereich verhindert Überlauf bei addierten Effekten.
				if effect.amount < -2147483647 or effect.amount > 2147483647:
					return false
				var total: int = current + effect.amount
				if current < 0 or current > 2147483647 or total < 0 or total > 2147483647:
					return false
				gold[effect.character_id] = total
			"define_fact":
				if effect.size() != 5:
					return false
				for key in ["fact_id", "subject", "predicate", "object"]:
					if not _id(effect.get(key)):
						return false
				if not candidate.define_fact(effect.fact_id, effect.subject, effect.predicate, effect.object):
					return false
			"learn_fact", "forget_fact":
				if effect.size() != 3 or not _id(effect.get("character_id")) or not _id(effect.get("fact_id")):
					return false
				if candidate.characters.get_character(effect.character_id) == null or candidate.get_fact(effect.fact_id).is_empty():
					return false
				if effect.type == "learn_fact":
					candidate.learn_fact(effect.character_id, effect.fact_id)
				else:
					# Bereits fehlendes Wissen ist ein erfolgreicher, idempotenter Effekt.
					candidate.forget_fact(effect.character_id, effect.fact_id)
			_:
				return false
	if not preload("res://src/core/world/world_event_log.gd").valid_batch(pending_events):
		return false
	if not world.restore_knowledge(candidate.knowledge_snapshot()):
		return false
	world.flags = flags
	world.quest_states = quests
	for id in gold:
		world.characters.get_character(id).gold = gold[id]
	for id in relationships:
		world.characters.get_character(id).beziehungen = relationships[id].beziehungen
	for id in inventories:
		world.characters.get_character(id).inventory.slots = inventories[id].slots
	for shop_id in stocks:
		for entry in world.shops[shop_id].entries:
			if stocks[shop_id].has(entry.item.item_id):
				entry.stock = stocks[shop_id][entry.item.item_id]
	world.events.append_batch(pending_events)
	# Benachrichtigungen erst nach Übernahme aller Daten versenden.
	for id in relationships:
		world.characters.get_character(id).sheet_changed.emit()
	for id in inventories:
		world.characters.get_character(id).inventory.contents_changed.emit()
	return true


## Bedingungen und Effekte laufen synchron, ohne Unterbrechung durch Dialogzeilen.
static func apply_if(world: WorldState, conditions: Array, effects: Array) -> bool:
	for condition in conditions:
		if not condition is Dictionary or not meets(world, condition):
			return false
	return apply(world, effects)


static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value == value.strip_edges()
