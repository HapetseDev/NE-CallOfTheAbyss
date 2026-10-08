extends Node

const Rules = preload("res://src/core/world/world_rules.gd")
const SAVE := "/tmp/necota-events-test.json"
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
	var world := WorldState.new()
	for id in ["dannerman", "shalka"]:
		world.characters.register_character(id, load("res://src/resources/characters/sheets/%s.tres" % id))
	var a := world.characters.get_character("dannerman")
	var b := world.characters.get_character("shalka")
	a.inventory.slots.clear()
	b.inventory.slots.clear()
	var item := load("res://src/resources/items/heiltrank.tres") as ItemData
	a.add_item(item, 3)
	var transfer := {"type": "transfer_item", "character_id": "dannerman", "target_id": "shalka", "item_id": item.item_id, "count": 1}
	check(not Rules.apply(world, [transfer, {"type": "unknown"}]) and world.events.snapshot().is_empty(), "Fehlerhafte Folge erzeugt keine Historie")
	check(Rules.apply(world, [transfer, transfer]), "Zwei echte Übergaben erfolgreich")
	var entries := world.events.snapshot()
	check(entries.size() == 2 and entries[0].id == "event_1" and entries[1].id == "event_2", "Wiederholte echte Handlungen besitzen verschiedene IDs")
	check(entries[0].data.character_id == "dannerman" and entries[0].data.target_id == "shalka" and entries[0].data.count == 1, "Strukturierte Beteiligte und Menge")
	entries[0].data.count = 99
	check(world.events.snapshot()[0].data.count == 1, "Abfragen geben Kopien heraus")
	var query := {"type": "event_occurred", "event_type": "item_transferred", "filters": {"character_id": "dannerman", "target_id": "shalka"}}
	check(Rules.meets(world, query), "Gemeinsame Condition findet passende Historie")
	query.filters.target_id = "missing"
	check(not Rules.meets(world, query), "Filter verwechselt keine Beteiligten")
	var complete := {"type": "complete_quest", "quest_id": "test", "character_id": "dannerman", "flag": "test_done"}
	check(not Rules.apply(world, [complete, {"type": "unknown"}]) and not world.flags.has("test_done") and world.events.snapshot().size() == 2, "Questfehler erzeugt weder Abschluss noch Ereignis")
	check(Rules.apply(world, [complete]) and world.events.snapshot().size() == 3, "Questabschluss wird erfasst")
	check(not Rules.apply(world, [complete]) and world.events.snapshot().size() == 3, "Questwiederholung erzeugt kein Duplikat")
	world.flags.erase("test_done")
	check(not Rules.apply(world, [complete]), "Historie schützt gegen nachträglich entferntes Abschlussflag")
	var store := WorldSaveStore.new()
	check(store.write(world, SAVE) == OK, "Protokoll speicherbar")
	var restored := store.read(SAVE)
	check(restored != null and restored.events.snapshot() == world.events.snapshot(), "Laden erhält IDs und Reihenfolge ohne Wiedergabe")
	check(Rules.apply(restored, [transfer]) and restored.events.snapshot().back().id == "event_4", "Neue ID setzt nach Laden fort")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	for mutation in ["id", "sequence", "type", "payload", "missing"]:
		var bad := original.duplicate(true)
		var event: Dictionary = bad.world.value.events[0].value
		match mutation:
			"id": event.id = "event_2"
			"sequence": event.sequence = 1.5
			"type": event.type = "unknown"
			"payload": event.data.value.count = -1
			"missing": bad.world.value.erase("events")
		var file := FileAccess.open(SAVE + ".bad", FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		check(store.read(SAVE + ".bad") == null, "Ungültiges Protokoll abgelehnt: " + mutation)
	var legacy := original.duplicate(true)
	legacy.version = 4
	legacy.world.value.erase("events")
	var file := FileAccess.open(SAVE + ".old", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated := store.read(SAVE + ".old")
	check(migrated != null and migrated.events.snapshot().is_empty() and migrated.characters.get_character("shalka").inventory.slots[0].count == 2, "Migration erfindet keine Historie und erhält Zustand")
	world.clear()
	check(world.events.snapshot().is_empty(), "Neustart leert Historie")
	check(world.events.append_batch([{"type": "npc_defeated", "data": {"character_id": "test"}}]) and world.events.snapshot()[0].id == "event_1", "Neue Sitzung beginnt eigene ID-Reihenfolge")
	print("world_events: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
