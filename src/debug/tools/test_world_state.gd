extends Node

var failed := 0
var checks := 0
const SAVE_PATH := "/tmp/necota-world-test.json"

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed += 1
		printerr("FAIL: " + message)

func _run() -> void:
	GameState.reset_session()
	var packed := load("res://src/core/main_game/main_game.tscn") as PackedScene
	var game := packed.instantiate() as MainGame
	add_child(game)
	var world := GameState.world_state
	_test_knowledge(world)
	check(world.characters == GameState.character_registry, "Einziger Besitzer der Charakterdaten")
	for id in world.characters.get_registered_ids():
		check(world.characters.get_template(id).character_id == id, "Vorlagen-ID wird von Godot geladen: " + id)
	check(world.locations.has(MainGame.DEFAULT_LEVEL), "Level registriert seinen Ort")
	var leader := game.party.leader
	var follower := game.party.followers[0]
	var plant := game.level_root.find_child("Plant", true, false) as Plant
	plant.perform_action("schneiden", leader)
	var potion := game.level_root.find_child("Heiltrank", true, false) as BasicItem
	potion.perform_action("pickup", leader)
	potion.perform_action("pickup", leader)
	check(world.get_object_owner("level1_potion_1") == "dannerman", "Besitz wird aus Inventar abgeleitet")
	check(leader.inventory.size() == 2, "Doppelter Pickup erzeugt kein Duplikat")
	var item: ItemData = leader.inventory.back().item
	var trade := PartyTradeUI.new()
	add_child(trade)
	trade.open(leader, follower)
	trade._on_left_item_selected(leader.inventory.size() - 1)
	check(leader.inventory.size() == 1, "Reales Tauschfenster entfernt Quelle über Rules")
	trade.free()
	check(world.get_object_owner("level1_potion_1") == "shalka", "Besitz folgt Übergabe ohne zweite Buchhaltung")
	leader.global_position = Vector3(3, 0.8, 4)
	var npc := game.level_root.find_child("MerchantNPC", true, false) as NPC
	npc.global_position = Vector3(-3, 0.8, 3)
	var expected_position := leader.global_position
	GameState.set_flag("investigation_started", true)
	LevelManager.load_level(MainGame.DEFAULT_LEVEL)
	await get_tree().process_frame
	check(world.objects["level1_plant_1"].removed, "Geschnittene Pflanze bleibt entfernt")
	check(game.level_root.find_child("Plant", true, false) == null, "Pflanze erscheint nach Levelwechsel nicht erneut")
	check(game.level_root.find_child("Heiltrank", true, false) == null, "Aufgenommener Trank erscheint nicht erneut")
	check(leader.global_position.distance_to(expected_position) < 0.1, "Partyposition wird wiederhergestellt")
	npc = game.level_root.find_child("MerchantNPC", true, false) as NPC
	check(npc.global_position.distance_to(Vector3(-3, 0.8, 3)) < 0.1, "NPC-Position wird wiederhergestellt")
	leader.character.gold = 137
	leader.character.learned_skills[0].xp = 23
	leader.health = 0
	leader.mana = 0
	check(game.level_manager.save_world(SAVE_PATH) == OK, "Speichern gelingt")
	var store := WorldSaveStore.new()
	var loaded := store.read(SAVE_PATH)
	check(loaded != null, "Snapshot lädt: " + store.last_error)
	if loaded == null:
		game.free()
		_finish()
		return
	check(loaded.knows_fact("dannerman", "theft") and not loaded.knows_fact("shalka", "theft"), "Individuelles Wissen übersteht Speicherung")
	check(loaded.get_fact("theft").object == "key_01", "Strukturierte Aussage übersteht Speicherung")
	check(loaded.characters.get_character("dannerman").staerkepunkte == 0, "Gespeicherte Nullpunkte bleiben erhalten")
	check(loaded.characters.get_character("dannerman").gold == 137 and loaded.characters.get_character("dannerman").learned_skills[0].xp == 23, "Gold und verschachtelte Skilldaten überstehen JSON")
	_test_invalid_saves(store)
	check(loaded.get_object_owner("level1_potion_1") == "shalka", "Besitz übersteht JSON-Rundlauf")
	check(not GameState.install_world(loaded), "Laden ersetzt keine laufende Welt")
	var before := GameState.world_state
	var invalid := FileAccess.open(SAVE_PATH + ".bad", FileAccess.WRITE)
	invalid.store_string('{"version":999,"world":{}}')
	invalid.close()
	check(store.read(SAVE_PATH + ".bad") == null and GameState.world_state == before, "Unbekannte Version lässt laufende Welt unverändert")
	var codec := WorldValueCodec.new()
	codec.decode({"kind": "Script", "value": "res://evil.gd"})
	check(codec.failed, "Unbekannte Resourceklassen werden abgelehnt")
	GameState.acquire_input_lock()
	check(game.level_manager.save_world(SAVE_PATH) == ERR_BUSY, "Keine Speicherung während Interaktionen")
	GameState.release_input_lock()
	game.free()
	check(GameState.install_world(loaded), "Geprüfter Kandidat wird an Szenengrenze installiert")
	game = packed.instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame
	check(game.party.leader.health == 0 and game.party.leader.mana == 0, "Weltfiguren nutzen geladene Werte ohne Initialisierung")
	check(GameState.knows_fact("dannerman", "theft"), "Dialog-API verwendet geladene Welt")
	check(GameState.get_flag("investigation_started"), "Flags sind geladen")
	check(game.level_root.find_child("Heiltrank", true, false) == null, "Geladener Gegenstand wird nicht dupliziert")
	follower = game.party.followers[0]
	item = follower.inventory.back().item
	check(follower.drop_item_to_world(item), "Gegenstand wird wieder in die Welt gelegt")
	check(GameState.world_state.get_object_owner("level1_potion_1").is_empty(), "Abgelegter Gegenstand hat keinen Inventarbesitzer")
	LevelManager.load_level(MainGame.DEFAULT_LEVEL)
	await get_tree().process_frame
	var count := 0
	for node in get_tree().get_nodes_in_group("persistent_world_object"):
		if node.world_object_id == "level1_potion_1":
			count += 1
	check(count == 1, "Abgelegter Gegenstand erscheint nach Wiederladen genau einmal")
	check(game.level_manager.save_world(SAVE_PATH) == OK and store.read(SAVE_PATH) != null, "Abgelegter Gegenstand ist speicherbar")
	game.free()
	check(GameState.world_state.objects.is_empty() and GameState.world_state.locations.is_empty(), "Neustartbereinigung erfasst WorldState")
	check(GameState.world_state.knowledge_snapshot() == {"facts": {}, "knowledge": {}}, "Neustart leert Fakten und Wissen")
	_test_inventory()
	_finish()

func _test_inventory() -> void:
	var inventory := Inventory.new()
	var item := ItemData.new()
	item.item_id = "stack_test"
	item.max_stack = 3
	inventory.add_item(item, 7)
	check(inventory.slots.size() == 3, "Überlauf wird auf mehrere Stapel verteilt")
	check(not inventory.remove_item(item, 8), "Unterbestand wird ohne Mutation abgelehnt")
	check(inventory.remove_item(item, 7) and inventory.is_empty(), "Entnahme über mehrere Stapel erhält Mengen")

func _finish() -> void:
	print("world_state: %d Checks, %d Fehler" % [checks, failed])
	get_tree().quit(1 if failed else 0)

func _test_invalid_saves(store: WorldSaveStore) -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	for mutation in ["inventory", "count", "location", "owner", "array", "knowledge", "duplicate", "missing_facts"]:
		var bad := original.duplicate(true)
		var data: Dictionary = bad.world.value
		var character: Dictionary = data.characters.value.dannerman.value.data.value
		match mutation:
			"knowledge": data.knowledge_state.value.knowledge.value.dannerman = ["missing"]
			"duplicate": data.knowledge_state.value.knowledge.value.dannerman = ["theft", "theft"]
			"missing_facts": data.erase("knowledge_state")
			"inventory": character.inventory = null
			"count": character.inventory.value.slots[0].value.count = -1
			"location": data.active_location = "res://missing.tscn"
			"owner": data.objects.value.level1_potion_1.value.removed = false
			"array": character.learned_skills = [42]
		var file := FileAccess.open(SAVE_PATH + ".bad", FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		check(store.read(SAVE_PATH + ".bad") == null, "Beschädigte Daten abgelehnt: " + mutation)
	var file := FileAccess.open(SAVE_PATH + ".bad", FileAccess.WRITE)
	file.store_string('{"version":')
	file.close()
	check(store.read(SAVE_PATH + ".bad") == null, "Abgebrochene Datei abgelehnt")
	check(store.read(SAVE_PATH) != null, "Originaldatei bleibt nach fehlerhaften Leseversuchen gültig")
	var legacy := original.duplicate(true)
	legacy.version = 1
	legacy.world.value.erase("knowledge_state")
	for entry in legacy.world.value.characters.value.values():
		entry.value.data.value.erase("is_defeated")
	var legacy_file := FileAccess.open(SAVE_PATH + ".legacy", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	var migrated := store.read(SAVE_PATH + ".legacy")
	check(migrated != null and migrated.knowledge_snapshot() == {"facts": {}, "knowledge": {}}, "Version 1 migriert mit leerem Wissen")
	check(migrated != null and migrated.characters.get_character("dannerman").gold == 137, "Migration erhält vorhandene Charakterdaten")
	var v2 := original.duplicate(true)
	v2.version = 2
	for entry in v2.world.value.characters.value.values():
		entry.value.data.value.erase("is_defeated")
	legacy_file = FileAccess.open(SAVE_PATH + ".legacy", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(v2))
	legacy_file.close()
	migrated = store.read(SAVE_PATH + ".legacy")
	check(migrated != null and not migrated.characters.get_character("dannerman").is_defeated and migrated.knows_fact("dannerman", "theft"), "Version 2 migriert ohne Wissensverlust")
	v2.version = 3
	legacy_file = FileAccess.open(SAVE_PATH + ".legacy", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(v2))
	legacy_file.close()
	check(store.read(SAVE_PATH + ".legacy") == null, "Version 3 verlangt expliziten Niederlagenzustand")
	var broken := store.read(SAVE_PATH)
	broken.characters.get_character("dannerman").inventory.slots[0].count = -1
	check(store.write(broken, SAVE_PATH) == ERR_INVALID_DATA, "Ungültiger Schreibkandidat wird abgelehnt")
	check(store.read(SAVE_PATH) != null, "Fehlerhaftes Schreiben erhält letzten gültigen Stand")

func _test_knowledge(world: WorldState) -> void:
	check(world.define_fact("theft", "bandit_01", "stole", "key_01"), "Strukturierte Aussage anlegen")
	check(world.define_fact("theft", "bandit_01", "stole", "key_01"), "Identische Faktdefinition ist idempotent")
	check(not world.define_fact("theft", "shalka", "stole", "key_01"), "Fakt-ID darf ihre Bedeutung nicht wechseln")
	check(not world.define_fact(" ", "bandit_01", "stole", "key_01"), "Leere Identität ablehnen")
	check(not world.knows_fact("dannerman", "theft"), "Definition erzeugt kein globales Wissen")
	check(not world.learn_fact("unknown", "theft") and not world.learn_fact("dannerman", "missing"), "Unbekannte Referenzen ablehnen")
	check(GameState.learn_fact("dannerman", "theft") and GameState.learn_fact("dannerman", "theft"), "Wissenserwerb ist idempotent")
	check(world.knowledge_snapshot().knowledge.dannerman.size() == 1, "Keine doppelten Wissenseinträge")
	check(not GameState.knows_fact("shalka", "theft"), "Wissen bleibt individuell")
	var fact := world.get_fact("theft")
	fact.object = "changed"
	check(world.get_fact("theft").object == "key_01", "Abfragen geben keine schreibbare interne Referenz heraus")
	var invalid := world.knowledge_snapshot()
	invalid.knowledge.dannerman.append("missing")
	check(not world.restore_knowledge(invalid) and world.knows_fact("dannerman", "theft"), "Ungültiger Import erhält vorhandenes Wissen")
	check(GameState.forget_fact("dannerman", "theft") and not GameState.knows_fact("dannerman", "theft"), "Wissen kann entfernt werden")
	check(not GameState.forget_fact("dannerman", "theft") and not world.get_fact("theft").is_empty(), "Vergessen löscht nicht die Aussage")
	GameState.learn_fact("dannerman", "theft")
