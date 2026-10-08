extends Node

const SAVE := "/tmp/necota-loader-test.json"
const BROKEN_LEVEL := "res://src/world/levels/tests/load_failure.tscn"
var checks := 0
var failures := 0
var loaded_count := 0
var pending_result := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _background_load() -> void:
	pending_result = await GameState.load_game(SAVE)

func _run() -> void:
	var tree := get_tree()
	# Testknoten bleibt neben den echten aktuellen Spielszenen bestehen.
	tree.current_scene = null
	tree.change_scene_to_file("res://src/core/main_game/main_game.tscn")
	await tree.scene_changed
	var game := tree.current_scene as MainGame
	GameState.game_loaded.connect(func() -> void: loaded_count += 1)
	game.party.leader.gold = 173
	game.party.leader.health = 0
	game.party.leader.mana = 0
	game.party.leader.global_position = Vector3(3, 2, 4)
	GameState.world_state.events.append_batch([{"type": "npc_defeated", "data": {"character_id": "bandit_01"}}])
	var saved_events: Array = GameState.world_state.events.snapshot()
	check(game.level_manager.save_world(SAVE) == OK, "Referenzwelt gespeichert")
	game.party.leader.gold = 999
	var old_world := GameState.world_state
	var file := FileAccess.open(SAVE + ".bad", FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var unsupported: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	unsupported["version"] = 999
	file = FileAccess.open(SAVE + ".future", FileAccess.WRITE)
	file.store_string(JSON.stringify(unsupported))
	file.close()
	for path in [SAVE + ".missing", SAVE + ".bad", SAVE + ".future"]:
		check(await GameState.load_game(path) != OK, "Ungültige Datei abgelehnt")
		check(tree.current_scene == game and GameState.world_state == old_world and game.party.leader.gold == 999, "Fehler erhält laufende Sitzung")
		check(not GameState.last_load_error.is_empty(), "Fehler verständlich abrufbar")
	var store := WorldSaveStore.new()
	check(store.write(WorldState.new(), SAVE + ".empty") == OK, "Isolierter Snapshot gespeichert")
	check(await GameState.load_game(SAVE + ".empty") == ERR_INVALID_DATA, "Snapshot ohne aktive Welt abgelehnt")
	GameState.acquire_input_lock()
	check(await GameState.load_game(SAVE) == ERR_BUSY, "Interaktionssperre respektiert")
	check(GameState.is_player_input_locked(), "Fremde Sperre bleibt erhalten")
	GameState.release_input_lock()
	tree.paused = true
	check(await GameState.load_game(SAVE) == ERR_BUSY, "Pause blockiert Laden")
	tree.paused = false
	var session := CombatSession.new()
	CombatManager.instance.active_session = session
	check(await GameState.load_game(SAVE) == ERR_BUSY, "Kampf blockiert Laden")
	CombatManager.instance.active_session = null
	session.free()
	# Erkennbarer Aufbaufehler nach erfolgreicher Dateiprüfung.
	var candidate := store.read(SAVE)
	candidate.active_location = BROKEN_LEVEL
	candidate.locations[BROKEN_LEVEL] = true
	check(store.write(candidate, SAVE + ".bootstrap") == OK, "Aufbaufehler-Fixture gespeichert")
	check(await GameState.load_game(SAVE + ".bootstrap") == ERR_CANT_CREATE, "Aufbaufehler erkannt")
	check(tree.current_scene == game and GameState.world_state == old_world and game.party.leader.gold == 999, "Rollback stellt dieselben Nodes und Daten wieder her")
	check(MainGame.instance == game and LevelManager.instance == game.level_manager and CameraSystem.instance == game.camera_system, "Rollback stellt Systeme wieder her")
	check(game.camera_system.camera.is_current() and not GameState.is_player_input_locked(), "Rollback stellt Kamera und freie Eingabe wieder her")
	check(loaded_count == 0, "Fehler senden kein Erfolgssignal")
	# Erste Anfrage wartet am Frame-Rand, zweite darf sie nicht überholen.
	_background_load()
	check(await GameState.load_game(SAVE) == ERR_BUSY, "Paralleles Laden abgelehnt")
	while pending_result == -1:
		await tree.process_frame
	check(pending_result == OK, "Laden nach Rollback erfolgreich")
	check(not is_instance_valid(game), "Alte Szene erst nach Erfolg freigegeben")
	game = tree.current_scene as MainGame
	check(game != null and MainGame.instance == game and GameState.world_state != old_world, "Neue Sitzung aktiv")
	check(game.party.leader.gold == 173 and game.party.leader.health == 0 and game.party.leader.mana == 0, "Gespeicherte Werte ohne Heilung wiederhergestellt")
	check(game.party.leader.global_position.is_equal_approx(Vector3(3, 2, 4)), "Gespeicherte Position wiederhergestellt")
	check(GameState.world_state.events.snapshot() == saved_events, "Ereignisse bleiben ohne Wiederholung erhalten")
	check(game.party.followers[0].leader == game.party.leader and game.camera_system.target == game.party.leader and game.party.get_party_hud()._entries.size() == 2, "Party, Kamera und HUD verbunden")
	check(loaded_count == 1 and GameState.last_load_error.is_empty(), "Ein Erfolgssignal und kein alter Fehler")
	# Eine neue Sperre im Vorbereitungsfenster verhindert den Szenentausch.
	pending_result = -1
	_background_load()
	GameState.acquire_input_lock()
	while pending_result == -1:
		await tree.process_frame
	check(pending_result == ERR_BUSY and tree.current_scene == game, "Sperre während Vorbereitung erhält Szene")
	GameState.release_input_lock()
	pending_result = -1
	_background_load()
	tree.change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	await tree.scene_changed
	while pending_result == -1:
		await tree.process_frame
	check(pending_result == ERR_BUSY and tree.current_scene is MainMenu, "Szenenwechsel während Vorbereitung wird nicht überschrieben")
	check(MainGame.instance == null and GameState.world_state.party_state.is_empty(), "Normaler Menüwechsel setzt Sitzung zurück")
	check(await GameState.load_game(SAVE) == OK, "Derselbe Ladeeinstieg funktioniert aus Hauptmenü")
	check(MainGame.instance.party.leader.gold == 173 and loaded_count == 2, "Menüladen stellt gespeicherte Party her")
	tree.current_scene.free()
	check(MainGame.instance == null and GameState.world_state.party_state.is_empty(), "Sitzungsende nach Laden setzt weiterhin zurück")
	print("world_loader: %d Checks, %d Fehler" % [checks, failures])
	tree.quit(1 if failures else 0)
