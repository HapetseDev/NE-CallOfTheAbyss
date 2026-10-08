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
	world.characters.register_character("dannerman", load("res://src/resources/characters/sheets/dannerman.tres"))
	var start := {"type": "start_quest", "quest_id": "bandit"}
	var complete := {"type": "complete_quest", "quest_id": "bandit", "character_id": "dannerman", "flag": "quest_bandit_done"}
	check(world.get_quest_state("bandit") == "not_started", "Initialzustand")
	check(not Rules.apply(world, [complete]), "Abschluss ohne erfülltes Ziel abgelehnt")
	check(not Rules.apply(world, [start, {"type": "unknown"}]) and world.get_quest_state("bandit") == "not_started" and not world.flags.has("quest_bandit_started"), "Fehlerhafte Annahme verändert nichts")
	check(Rules.apply(world, [start, start]) and world.get_quest_state("bandit") == "active", "Annahme idempotent")
	GameState.set_flag("defeated_bandit", true)
	check(world.get_quest_state("bandit") == "ready", "Sieg aktiviert Abgabe")
	GameState.set_flag("defeated_bandit", false)
	check(world.get_quest_state("bandit") == "ready" and GameState.get_flag("defeated_bandit"), "Legacy-Schreiber setzt Fortschritt nicht zurück")
	check(not Rules.apply(world, [complete, {"type": "unknown"}]) and world.get_quest_state("bandit") == "ready", "Fehlerhafter Abschluss bleibt bereit")
	check(Rules.apply(world, [complete]) and world.get_quest_state("bandit") == "completed", "Abschluss übernimmt Zustand und Flag")
	check(not Rules.apply(world, [start]) and not Rules.apply(world, [complete]), "Abgeschlossene Quest nicht erneut startbar oder belohnbar")
	var store := WorldSaveStore.new()
	const PATH := "/tmp/necota-quest-progress.json"
	check(store.write(world, PATH) == OK, "Questzustand speicherbar")
	var restored := store.read(PATH)
	check(restored != null and restored.get_quest_state("bandit") == "completed", "Questzustand wird geladen")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	data.world.value.quest_states.value.bandit = "active"
	var file := FileAccess.open(PATH + ".bad", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(store.read(PATH + ".bad") == null, "Widerspruch zu kompatiblen Flags abgelehnt")
	data.version = 5
	data.world.value.erase("quest_states")
	file = FileAccess.open(PATH + ".old", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	restored = store.read(PATH + ".old")
	check(restored != null and restored.get_quest_state("bandit") == "completed", "Alter Abschluss migriert ohne Belohnung")
	GameState.reset_session()
	GameState.set_flag("defeated_bandit", true)
	check(GameState.world_state.get_quest_state("bandit") == "ready", "Sieg vor Annahme bleibt abgabefähig")
	check(Rules.apply(GameState.world_state, [start]) and GameState.world_state.get_quest_state("bandit") == "ready", "Späte Annahme setzt Zielerfüllung nicht zurück")
	GameState.reset_session()
	check(GameState.world_state.get_quest_state("bandit") == "not_started", "Neustart bereinigt Fortschritt")
	print("quest_progress: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
