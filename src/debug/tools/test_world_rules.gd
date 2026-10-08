extends Node

const Rules = preload("res://src/core/world/world_rules.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	GameState.reset_session()
	var world := GameState.world_state
	for id in ["dannerman", "shalka", "quest_giver_01"]:
		world.characters.register_character(id, load("res://src/resources/characters/sheets/%s.tres" % id))
	var define := {"type": "define_fact", "fact_id": "test", "subject": "bandit_01", "predicate": "located_in", "object": "west"}
	var learn := {"type": "learn_fact", "character_id": "dannerman", "fact_id": "test"}
	var condition := {"type": "knows_fact", "character_id": "dannerman", "fact_id": "test"}
	check(not Rules.meets(world, condition), "Unbekanntes Wissen ist falsch")
	check(not Rules.apply(world, [define, {"type": "unknown"}]) and world.get_fact("test").is_empty(), "Fehler rollt gesamte Folge zurück")
	check(Rules.apply(world, [define, learn]) and Rules.meets(world, condition), "Definition und Lernen gemeinsam")
	check(Rules.apply(world, [define, learn]), "Wiederholung ist idempotent")
	var before := world.knowledge_snapshot()
	check(not Rules.apply(world, [{"type": "forget_fact", "character_id": "dannerman", "fact_id": "test"}, 42]) and before == world.knowledge_snapshot(), "Später Fehler erhält vorheriges Wissen")
	check(not Rules.apply(world, [{"type": "learn_fact", "character_id": "missing", "fact_id": "test"}]), "Unbekannter Charakter abgelehnt")
	check(not Rules.meets(world, {"type": "unknown"}) and not Rules.meets(world, {"type": "knows_fact", "character_id": 42, "fact_id": "test"}), "Ungültige Conditions geschlossen abgelehnt")
	var forget := {"type": "forget_fact", "character_id": "dannerman", "fact_id": "test"}
	check(Rules.apply(world, [forget, forget]) and not Rules.meets(world, condition), "Vergessen ist idempotent")
	_test_inventory_rules()
	_test_relationships()
	_test_rewards(world)
	await _test_dialogue()
	GameState.reset_session()
	check(not GameState.knows_fact("dannerman", "bandit_location_west"), "Neustart entfernt Dialogwissen")
	print("world_rules: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_dialogue() -> void:
	var source := FileAccess.get_file_as_string("res://src/resources/dialogue/quest_giver.dialogue")
	var compiled := DMCompiler.compile_string(source, "")
	check(compiled.errors.is_empty(), "Produktionsdialog kompiliert")
	if not compiled.errors.is_empty():
		for error in compiled.errors:
			printerr("Dialogfehler Zeile %s: %s" % [error.line_number, error.error])
		return
	var resource := load("res://src/resources/dialogue/quest_giver.dialogue") as DialogueResource
	var player := {"character": GameState.character_registry.get_character("dannerman")}
	var context: Array = [{"player": player}]
	var line := await DialogueManager.get_next_dialogue_line(resource, "start", context)
	check(line.text.begins_with("Endlich"), "Erstgespräch ohne Erinnerungszeile")
	while line != null and line.responses.is_empty():
		line = await DialogueManager.get_next_dialogue_line(resource, line.next_id, context)
	check(line != null and line.responses.size() == 2, "Vorhandene Antworten bleiben verfügbar")
	if line != null:
		var response_id: String = line.responses[1].next_id
		var declined := await DialogueManager.get_next_dialogue_line(resource, response_id, context)
		while declined != null:
			declined = await DialogueManager.get_next_dialogue_line(resource, declined.next_id, context)
		check(not GameState.knows_fact("dannerman", "bandit_location_west"), "Ablehnung erzeugt kein Hinweiswissen")
		line = await DialogueManager.get_next_dialogue_line(resource, line.responses[0].next_id, context)
		while line != null:
			line = await DialogueManager.get_next_dialogue_line(resource, line.next_id, context)
	check(GameState.knows_fact("dannerman", "bandit_location_west"), "Echter Dialog führt Wissenseffekt aus")
	check(GameState.get_flag("quest_bandit_started"), "Bisheriger Queststart bleibt erhalten")
	line = await DialogueManager.get_next_dialogue_line(resource, "start", context)
	check(line.text.begins_with("Du erinnerst dich"), "Wissen steuert Wiederholungsgespräch")
	player.character = GameState.character_registry.get_character("shalka")
	line = await DialogueManager.get_next_dialogue_line(resource, "start", context)
	check(line.text.begins_with("Endlich"), "Andere Figur erbt kein Gesprächswissen")
	player.character = GameState.character_registry.get_character("dannerman")
	var initial_gold: int = player.character.gold
	line = await DialogueManager.get_next_dialogue_line(resource, "quest_done", context)
	check(player.character.gold == initial_gold and not GameState.get_flag("quest_bandit_done"), "Direkter Abschluss ohne Sieg zahlt nichts")
	GameState.set_flag("defeated_bandit", true)
	line = await DialogueManager.get_next_dialogue_line(resource, "quest_done", context)
	check(player.character.gold == initial_gold + 20 and GameState.get_flag("quest_bandit_done"), "Produktionsdialog vergibt Gold und Abschluss gemeinsam")
	line = await DialogueManager.get_next_dialogue_line(resource, "quest_done", context)
	check(player.character.gold == initial_gold + 20, "Wiederholter Abschluss zahlt nicht erneut")
	check(line.text.begins_with("Für deine Hilfe habe ich dich bereits belohnt"), "Echter Dialog reagiert auf Questereignis")
	var elara := GameState.character_registry.get_character("quest_giver_01")
	check(RelationshipService.get_disposition(elara, player.character) == 1, "Quest erhöht Sympathie genau einmal")
	check(RelationshipService.get_disposition(player.character, elara) == 0, "Gegenrichtung bleibt unverändert")
	var store := WorldSaveStore.new()
	check(store.write(GameState.world_state, "/tmp/necota-rules-test.json") == OK, "Dialogwissen speicherbar")
	var restored := store.read("/tmp/necota-rules-test.json")
	check(restored != null and GameState.install_world(restored), "Dialogwelt wird geladen")
	player.character = GameState.character_registry.get_character("dannerman")
	line = await DialogueManager.get_next_dialogue_line(resource, "start", context)
	check(line.text.begins_with("Für deine Hilfe habe ich dich bereits belohnt"), "Abgeschlossene Quest wird nach Laden nicht erneut angeboten")
	line = await DialogueManager.get_next_dialogue_line(resource, "quest_done", context)
	check(player.character.gold == initial_gold + 20 and GameState.get_flag("quest_bandit_done"), "Laden erlaubt keine doppelte Belohnung")
	check(RelationshipService.get_disposition(GameState.character_registry.get_character("quest_giver_01"), player.character) == 1, "Laden und Wiederholung erhöhen Sympathie nicht erneut")
	# Das Addon referenziert die Resource in den eigenen Zeilendaten.
	context.clear()
	for entry in resource.lines.values():
		entry.erase("resource")

func _test_rewards(world: WorldState) -> void:
	var character := world.characters.get_character("dannerman")
	var original: int = character.gold
	var reward := {"type": "change_gold", "character_id": "dannerman", "amount": 20}
	var flag := {"type": "set_flag", "key": "test_reward", "value": true}
	check(Rules.meets(world, {"type": "flag_equals", "key": "test_reward", "value": false}), "Fehlendes Flag gilt als false")
	check(not Rules.apply(world, [reward, flag, {"type": "unknown"}]) and character.gold == original and not world.flags.has("test_reward"), "Ungültige Folge verändert weder Gold noch Flags")
	check(not Rules.apply_if(world, [{"type": "flag_equals", "key": "missing", "value": true}], [reward]) and character.gold == original, "Nicht erfüllte Bedingung verhindert Effekte")
	check(not Rules.apply(world, [{"type": "change_gold", "character_id": "dannerman", "amount": -2147483647}]) and character.gold == original, "Unterdeckung ohne Mutation abgelehnt")
	check(not Rules.apply(world, [{"type": "change_gold", "character_id": "dannerman", "amount": 1.5}]), "Gebrochene Goldwerte abgelehnt")
	var guard := {"type": "flag_equals", "key": "test_reward", "value": false}
	check(Rules.apply_if(world, [guard], [reward, flag]) and character.gold == original + 20, "Geschützte Belohnung erfolgreich")
	check(not Rules.apply_if(world, [guard], [reward, flag]) and character.gold == original + 20, "Abschlussflag schützt gegen Wiederholung")
	character.gold = original
	world.flags.erase("test_reward")

func _test_relationships() -> void:
	var world := WorldState.new()
	var a := world.characters.register_character("dannerman", load("res://src/resources/characters/sheets/dannerman.tres"))
	var b := world.characters.register_character("shalka", load("res://src/resources/characters/sheets/shalka.tres"))
	a.beziehungen.clear()
	b.beziehungen.clear()
	b.faction_ids = ["test_faction"]
	var faction := RelationshipEntry.new()
	faction.target_type = RelationshipEntry.TargetType.FACTION
	faction.target_id = "test_faction"
	faction.wertung = -3
	a.beziehungen.append(faction)
	var effect := {"type": "change_relationship", "character_id": "dannerman", "target_id": "shalka", "amount": 2}
	check(Rules.apply(world, [effect]) and RelationshipService.get_disposition(a, b) == -1, "Änderung verwendet Fraktionsfallback als Ausgangswert")
	check(faction.wertung == -3 and a.beziehungen[0].wertung == -3, "Fraktionseintrag bleibt unverändert")
	check(RelationshipService.get_disposition(b, a) == 0, "Beziehung ist gerichtet")
	var entry: RelationshipEntry = a.beziehungen[1]
	entry.details = "keep"
	var initial_gold := a.gold
	check(not Rules.apply(world, [effect, {"type": "change_gold", "character_id": "dannerman", "amount": 10}, {"type": "unknown"}]) and a.gold == initial_gold and entry.wertung == -1 and a.beziehungen[1] == entry, "Später Fehler erhält Beziehungen, Ressourcen und Gold")
	check(Rules.apply(world, [effect, effect]) and RelationshipService.get_disposition(a, b) == 3 and a.beziehungen.size() == 2 and a.beziehungen[1].details == "keep", "Effekte akkumulieren ohne Duplikate und erhalten Details")
	check(Rules.meets(world, {"type": "relationship_at_least", "character_id": "dannerman", "target_id": "shalka", "minimum": 3}), "Grenzwert ist einschließlich")
	check(not Rules.meets(world, {"type": "relationship_at_least", "character_id": "dannerman", "target_id": "missing", "minimum": -10}), "Unbekanntes Ziel ist nicht neutral erfolgreich")
	effect.amount = 100
	check(Rules.apply(world, [effect]) and RelationshipService.get_disposition(a, b) == 10, "Obergrenze wird eingehalten")
	effect.amount = -100
	check(Rules.apply(world, [effect]) and RelationshipService.get_disposition(a, b) == -10, "Untergrenze wird eingehalten")
	effect.amount = 0.5
	check(not Rules.apply(world, [effect]), "Gebrochene Änderung wird abgelehnt")
	effect.amount = 1
	effect.target_id = "dannerman"
	check(not Rules.apply(world, [effect]), "Selbstbeziehung ist nicht veränderbar")

func _test_inventory_rules() -> void:
	var world := WorldState.new()
	var a := world.characters.register_character("dannerman", load("res://src/resources/characters/sheets/dannerman.tres"))
	var b := world.characters.register_character("shalka", load("res://src/resources/characters/sheets/shalka.tres"))
	a.inventory.slots.clear()
	b.inventory.slots.clear()
	var item := ItemData.new()
	item.item_id = "test_stack"
	item.max_stack = 3
	item.weight = 0.1
	a.inventory.add_item(item, 7)
	var inv := a.inventory
	var slot := inv.slots[0]
	var transfer := {"type": "transfer_item", "character_id": "dannerman", "target_id": "shalka", "item_id": "test_stack", "count": 5}
	var condition := {"type": "has_item", "character_id": "dannerman", "item_id": "test_stack", "count": 7}
	check(Rules.meets(world, condition), "Besitzbedingung zählt über Stapel")
	check(not Rules.apply(world, [transfer, {"type": "unknown"}]) and Rules.meets(world, condition) and b.inventory.slots.is_empty() and inv.slots[0] == slot, "Fehler erhält Slots, Mengen und Empfänger")
	var observed: Array = []
	var on_change := func(): observed.append(b.inventory.slots.size())
	inv.contents_changed.connect(on_change)
	check(Rules.apply(world, [transfer]) and a.inventory == inv and b.inventory.slots.size() == 2, "Transfer verteilt Stapel und erhält Inventaridentität")
	check(observed == [2], "Inventarsignal sieht bereits vollständigen Empfängerzustand")
	inv.contents_changed.disconnect(on_change)
	condition.character_id = "shalka"
	condition.count = 5
	check(Rules.meets(world, condition), "Empfänger erhält exakte Menge")
	check(not Rules.apply(world, [transfer]), "Unterbestand wird abgelehnt")
	var remove := {"type": "remove_item", "character_id": "shalka", "item_id": "test_stack", "count": 5}
	check(Rules.apply(world, [remove]) and b.inventory.slots.is_empty(), "Entzug über mehrere Stapel")
	transfer.count = 1
	item.weight = 100000
	check(not Rules.apply(world, [transfer]) and a.inventory.slots[0].count == 2 and b.inventory.slots.is_empty(), "Traglastfehler verliert keinen Gegenstand")
	item.weight = 0.1
	b.inventory.equipment.waffe = item
	condition.count = 1
	check(not Rules.meets(world, condition), "Ausrüstung ist kein Rucksackbestand")
	b.inventory.equipment.waffe = null
	var unique := ItemData.new()
	unique.item_id = "test_stack"
	unique.world_object_id = "unique_test"
	unique.max_stack = 1
	a.inventory.add_item(unique)
	world.objects.unique_test = {"kind": "item", "removed": true, "item": unique}
	var unique_transfer := {"type": "transfer_item", "character_id": "dannerman", "target_id": "shalka", "world_object_id": "unique_test", "count": 1}
	check(Rules.apply(world, [unique_transfer]) and world.get_object_owner("unique_test") == "shalka", "Eindeutige Instanz wechselt Besitzer")
	check(not Rules.apply(world, [unique_transfer]), "Wiederholter Transfer dupliziert nichts")
	check(not Rules.meets(world, condition), "Typauswahl erfasst keine eindeutigen Weltobjekte")
	unique_transfer.character_id = "shalka"
	unique_transfer.target_id = "dannerman"
	check(Rules.apply(world, [unique_transfer]), "Eindeutige Instanz kann zurückgegeben werden")
	unique_transfer.character_id = "dannerman"
	unique_transfer.target_id = "shalka"
	b.inventory.add_item(unique)
	check(not Rules.apply(world, [unique_transfer]), "Widersprüchlicher Besitz wird abgelehnt")
	b.inventory.slots.clear()
	check(Rules.apply(world, [{"type": "remove_item", "character_id": "dannerman", "world_object_id": "unique_test", "count": 1}]) and world.get_object_owner("unique_test").is_empty() and world.objects.unique_test.removed, "Entzug eindeutiger Instanz erhält Welt-Tombstone")

	var chained := transfer.duplicate()
	chained.count = 1
	var back := chained.duplicate()
	back.character_id = "shalka"
	back.target_id = "dannerman"
	check(Rules.apply(world, [chained, back]) and a.inventory.slots[0].count == 2 and b.inventory.slots.is_empty(), "Mehrere Transfers derselben Folge sehen vorbereitete Mengen")
	chained.count = 0
	check(not Rules.apply(world, [chained]), "Nullmenge wird abgelehnt")
	chained.count = 1
	chained.world_object_id = "unique_test"
	check(not Rules.apply(world, [chained]), "Mehrdeutige Auswahl wird abgelehnt")
