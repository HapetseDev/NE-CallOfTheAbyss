extends Node

const LAIR := "res://src/world/levels/regions/MonsterLair-Level1/MonsterLair-Level1.tscn"
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame
	var shell := game.game_windows
	for cycle in range(5):
		game._on_top_bar_map_pressed()
		for frame in range(5): await get_tree().process_frame
		check(shell.visible and shell._panel.size.x > 400, "Fenster stabil und sichtbar")
		check(GameState.is_player_input_locked(), "Karte sperrt Spielereingabe")
		shell.close()
		await get_tree().process_frame
		check(not shell.visible and not GameState.is_player_input_locked(), "Schließen gibt Eingabe frei")
	shell.open_page(3)
	var ui := shell._embedded_views[0] as MapUI
	shell._release_lock() # Domain checks below previously ran with the map closed.
	var canvas := ui._map
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = canvas.size * 0.5
	canvas._gui_input(wheel)
	check(canvas.zoom > 1.0, "Mausrad vergrößert Karte")
	canvas.reset_view()
	check(canvas.zoom == 1.0 and canvas.pan == Vector2.ZERO, "Übersicht setzt Navigation zurück")
	var map := ui.cartography
	check(not map.segments.is_empty(), "Umrisse aus realem Level extrahiert")
	check(map.is_explored(map.player_position), "Startposition entdeckt")
	check(not map.is_explored(Vector2(10000, 10000)), "Unbekannte Bereiche verborgen")
	var original: Dictionary = map.state().duplicate(true)
	var npc := game.level_manager.current_level.find_children("*", "NPC", true, false)[0] as NPC
	game.party.leader.global_position = npc.global_position
	map.update(game)
	check(map.state().markers.has(npc.character.character_id), "NPC wird mit Namen entdeckt")
	var known_position: Vector3 = map.state().markers[npc.character.character_id].position
	npc.global_position += Vector3(100, 0, 100)
	map.update(game)
	check(map.state().markers[npc.character.character_id].position == known_position, "Unbeobachteter NPC verrät keine neue Position")
	var item := game.level_manager.current_level.find_children("*", "BasicItem", true, false)[0] as BasicItem
	game.party.leader.global_position = item.global_position
	map.update(game)
	check(map.state().markers.has(item.world_object_id), "Weltobjekt entdeckt")
	GameState.world_state.remove_object(item.world_object_id)
	map.update(game)
	check(not map.state().markers.has(item.world_object_id), "Entferntes Objekt verschwindet")
	check(map.state().cells.size() >= original.cells.size(), "Erkundung bleibt erhalten")
	check(game.level_manager.save_world("/tmp/necota-map-save.json") == OK, "Erkundung speicherbar")
	var store := WorldSaveStore.new()
	var saved := store.read("/tmp/necota-map-save.json")
	check(saved != null and saved.map_exploration == GameState.world_state.map_exploration, "Karte überlebt Speicherrundlauf")
	var codec := WorldValueCodec.new()
	var file := FileAccess.open("/tmp/necota-map-save.json", FileAccess.READ)
	var payload: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var data: Dictionary = codec.decode(payload.world)
	data.erase("map_exploration")
	payload.version = 7
	payload.world = codec.encode(data)
	file = FileAccess.open("/tmp/necota-map-legacy.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var legacy := store.read("/tmp/necota-map-legacy.json")
	check(legacy != null and legacy.map_exploration.is_empty(), "Version 7 startet mit leerer Karte")
	payload.version = 8
	file = FileAccess.open("/tmp/necota-map-invalid.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	check(store.read("/tmp/necota-map-invalid.json") == null, "Version 8 ohne Kartendaten abgelehnt")
	var previous: Dictionary = map.state().duplicate(true)
	check(game.level_manager._load_level(LAIR), "Höhle lädt")
	map.update(game)
	check(map.location == LAIR and not map.segments.is_empty(), "Höhle besitzt eigene Umrisse")
	check(GameState.world_state.map_exploration[MainGame.DEFAULT_LEVEL] == previous, "Levelwechsel erhält Karte")
	check(game.level_manager._load_level(MainGame.DEFAULT_LEVEL), "Rückkehr lädt")
	map.update(game)
	check(map.state().cells.size() >= previous.cells.size(), "Rückkehr erhält Entdeckungen")
	game.free()
	check(GameState.world_state.map_exploration.is_empty(), "Neustart entfernt Kartenerkundung")
	print("map_ui: %d Prüfungen, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
