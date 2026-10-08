extends Node

const SAVE := "/tmp/necota-party-test.json"
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
	var packed := load("res://src/core/main_game/main_game.tscn") as PackedScene
	var game := packed.instantiate() as MainGame
	add_child(game)
	var initial := {"leader_id": "dannerman", "member_ids": ["dannerman", "shalka"]}
	check(GameState.world_state.party_state == initial, "Startbesetzung wird erfasst")
	check(game.party.followers[0].leader == game.party.leader, "Begleiterbindung stimmt")
	game.party.move_follower(game.party.followers[0], 1)
	check(GameState.world_state.party_state == initial, "Reihenfolge bleibt bei einzelnem Follower stabil")
	game.party.leader.health = 0
	game.party.leader.mana = 0
	game.party.followers[0].gold = 173
	check(game.level_manager.save_world(SAVE) == OK, "Party speicherbar")
	var store := WorldSaveStore.new()
	var restored := store.read(SAVE)
	check(restored != null and restored.party_state == initial, "IDs und Reihenfolge werden geladen")
	_test_invalid(store)
	LevelManager.load_level(MainGame.DEFAULT_LEVEL)
	check(GameState.world_state.party_state == initial and game.party.followers[0].gold == 173, "Levelwechsel erhält Besetzung und Charakterdaten")
	game.free()
	check(GameState.world_state.party_state.is_empty(), "Sitzungsende leert Partyzustand")
	check(GameState.install_world(restored), "Geprüfte Party installierbar")
	game = packed.instantiate() as MainGame
	add_child(game)
	check(game.party.leader.health == 0 and game.party.leader.mana == 0 and game.party.followers[0].gold == 173, "Laden bindet vorhandene Charakterdaten ohne Neuinitialisierung")
	check(game.party.followers[0].leader == game.party.leader, "Laden stellt Begleiterbindung wieder her")
	check(game.camera_system.target == game.party.leader and game.party.get_party_hud()._entries.size() == 2, "Kamera und HUD folgen geladener Party")
	# Kontrollierte Laufzeitbesetzung ohne Begleiter; keine neue Rekrutierungs-UI.
	var follower: PartyFollower = game.party.followers.pop_back()
	game.party.remove_child(follower)
	follower.free()
	check(game.level_manager.save_world(SAVE) == OK, "Geänderte Besetzung wird vor Speichern erfasst")
	restored = store.read(SAVE)
	check(restored.party_state.member_ids == ["dannerman"], "Abwesende Begleiter werden nicht als aktiv gespeichert")
	game.free()
	GameState.install_world(restored)
	game = packed.instantiate() as MainGame
	add_child(game)
	check(game.party.followers.is_empty() and game.party.get_all_members().size() == 1 and game.party.get_child_count() == 1, "Laden erzeugt keinen ungewollten Begleiter")
	check(game.party.get_party_hud()._entries.size() == 1 and game.camera_system.target == game.party.leader, "HUD und Kamera passen zur Einzelbesetzung")
	check(GameState.character_registry.get_character("shalka").gold == 173, "Inaktive Charakterdaten bleiben erhalten")
	game.free()
	# Migration aus tatsächlicher alter Spielwelt: feste Startparty rekonstruieren.
	var legacy := store.read(SAVE + ".legacy")
	check(legacy != null and GameState.install_world(legacy), "Version 6 migriert")
	game = packed.instantiate() as MainGame
	add_child(game)
	check(game.party.followers.size() == 1 and GameState.world_state.party_state == initial, "Alte Spielstände erhalten bisherige Startparty")
	game.free()
	game = packed.instantiate() as MainGame
	add_child(game)
	check(GameState.world_state.party_state == initial and game.party.leader.health > 0, "Neues Spiel erhält frische Startparty")
	game.free()
	print("party_state: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_invalid(store: WorldSaveStore) -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	for mutation in ["missing", "duplicate", "leader", "unknown", "order", "empty", "missing_character"]:
		var bad := original.duplicate(true)
		var party: Dictionary = bad.world.value.party_state.value
		match mutation:
			"missing_character": bad.world.value.characters.value.erase("shalka")
			"missing": bad.world.value.erase("party_state")
			"duplicate": party.member_ids = ["dannerman", "shalka", "shalka"]
			"leader": party.leader_id = "merchant_01"
			"unknown": party.member_ids = ["dannerman", "merchant_01"]
			"order": party.member_ids = ["shalka", "dannerman"]
			"empty": party.member_ids = []
		var file := FileAccess.open(SAVE + ".bad", FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		check(store.read(SAVE + ".bad") == null, "Ungültige Party abgelehnt: " + mutation)
	var legacy := original.duplicate(true)
	legacy.version = 6
	legacy.world.value.erase("party_state")
	var file := FileAccess.open(SAVE + ".legacy", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()

	var invalid := store.read(SAVE)
	invalid.party_state = {"leader_id": "merchant_01", "member_ids": ["merchant_01"]}
	check(store.write(invalid, SAVE) != OK and store.read(SAVE).party_state.leader_id == "dannerman", "Ungültiges Schreiben erhält letzten gültigen Stand")
