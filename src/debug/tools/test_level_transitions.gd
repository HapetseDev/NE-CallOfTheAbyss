extends Node

const LAIR := "res://src/world/levels/regions/MonsterLair-Level1/MonsterLair-Level1.tscn"
const ARRIVAL := ^"Levelwechseln/Eingang/Eingangsshape"
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func frames(count: int = 5) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame
	# Übergänge beinhalten jetzt einen zeitgesteuerten Fade samt Physik-Wartezeit.
	for frame in range(240):
		if LevelManager.instance == null or not LevelManager.instance._transition_pending:
			break
		await get_tree().physics_frame
		await get_tree().process_frame

func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	tree.change_scene_to_file("res://src/core/main_game/main_game.tscn")
	await tree.scene_changed
	var game := tree.current_scene as MainGame
	var manager := game.level_manager
	var black_during_switch: Array[bool] = []
	manager.level_loaded.connect(func(_level: BaseLevel) -> void:
		var cover := game.transition_root.get_node("FadeRect") as ColorRect
		black_during_switch.append(cover.visible and is_equal_approx(cover.modulate.a, 1.0)))
	var player := game.party.leader
	var follower := game.party.followers[0]
	var exit_area := manager.current_level.get_node("Levelwechseln/Ausgang") as Area3D
	var exit_shape := exit_area.get_node("Ausgangshape") as CollisionShape3D
	await frames()
	follower.global_position = exit_shape.global_position
	await frames()
	check(manager.current_level_path == MainGame.DEFAULT_LEVEL, "Begleiter löst keinen Wechsel aus")
	GameState.acquire_input_lock()
	player.global_position = exit_shape.global_position
	await frames()
	check(manager.current_level_path == MainGame.DEFAULT_LEVEL, "Interaktionssperre verhindert Übergang")
	GameState.release_input_lock()
	await frames()
	check(manager.current_level_path == LAIR, "Echte Shape-Berührung lädt Monsterhöhle")
	check(black_during_switch == [true], "Levelaufbau erfolgt erst bei vollständig schwarzem Bild")
	check(not game.transition_root.get_node("FadeRect").visible and not GameState.is_player_input_locked(), "Fade endet ohne sichtbare Abdeckung oder verwaiste Sperre")
	check(game.party.leader == player and game.party.followers[0] == follower, "Party-Nodes bleiben erhalten")
	check(GameState.character_registry.get_character("lair_bandit_01") != null and GameState.character_registry.get_character("lair_bandit_01") != GameState.character_registry.get_character("bandit_01"), "Gegner besitzt unabhängige Identität")
	check(GameState.world_state.objects.has("lair1_potion_1") and GameState.world_state.objects.has("level1_potion_1"), "Heiltränke besitzen unabhängige Weltzustände")
	var destination := manager.current_level.get_node(ARRIVAL) as Node3D
	check(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(destination.global_position.x, destination.global_position.z)) < 0.2, "Ankunft an designierter Eingangszone")
	player.gold = 321
	check(manager.save_world("/tmp/necota-transition-test.json") == OK, "Neues Level speicherbar")
	var saved_position := player.global_position
	check(await GameState.load_game("/tmp/necota-transition-test.json") == OK, "Neues Level über sicheren Ablauf ladbar")
	game = tree.current_scene as MainGame
	manager = game.level_manager
	player = game.party.leader
	check(manager.current_level_path == LAIR and player.global_position.is_equal_approx(saved_position) and player.gold == 321, "Laden erhält gespeicherte Position statt Eingang zu erzwingen")
	await frames()
	exit_area = manager.current_level.get_node("Levelwechseln/Ausgang") as Area3D
	var old_level := manager.current_level
	check(not manager._load_level(MainGame.DEFAULT_LEVEL, ^"MissingArrival") and manager.current_level == old_level, "Fehlender Ankunftspunkt erhält laufendes Level")
	var session := CombatSession.new()
	CombatManager.instance.active_session = session
	player.global_position = exit_area.get_node("Ausgangshape").global_position
	await frames()
	check(manager.current_level_path == LAIR, "Laufender Kampf verhindert Übergang")
	CombatManager.instance.active_session = null
	session.free()
	# Direkt im Ausgang speichern, bevor die nächste Physikauswertung wechselt.
	check(manager.save_world("/tmp/necota-transition-exit.json") == OK, "Spielstand im Ausgang speicherbar")
	# Eigene Szene kurz gegen Übergang sperren, bis der Loader vorbereitet ist:
	# _armed=false simuliert hier nur das bereits ausgelöste Ausgangsereignis.
	exit_area.set("_armed", false)
	check(await GameState.load_game("/tmp/necota-transition-exit.json") == OK, "Spielstand im Ausgang ladbar")
	game = tree.current_scene as MainGame
	manager = game.level_manager
	player = game.party.leader
	await frames(12)
	check(manager.current_level_path == LAIR, "Laden innerhalb Ausgang löst keinen Wechsel aus")
	var lair_enemy := manager.current_level.get_node("EnemyNPC") as NPC
	lair_enemy.get_node("Interaction").mark_defeated()
	check(not GameState.get_flag("defeated_bandit") and not GameState.character_registry.get_character("bandit_01").is_defeated, "Höhlengegner beeinflusst ursprünglichen Questbanditen nicht")
	exit_area = manager.current_level.get_node("Levelwechseln/Ausgang") as Area3D
	player.global_position = manager.current_level.get_node(ARRIVAL).global_position
	await frames()
	player.global_position = exit_area.get_node("Ausgangshape").global_position
	await frames()
	check(manager.current_level_path == MainGame.DEFAULT_LEVEL, "Ausgang führt zurück")
	destination = manager.current_level.get_node(ARRIVAL) as Node3D
	check(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(destination.global_position.x, destination.global_position.z)) < 0.2, "Rückkehr nutzt Eingang statt alter Ausgangsposition")
	await frames(12)
	check(manager.current_level_path == MainGame.DEFAULT_LEVEL, "Kein sofortiges Zurückspringen")
	check(player.gold == 321 and game.party.followers[0].global_position.distance_to(player.global_position) < 3, "Daten und Begleiter bleiben bei Rückkehr erhalten")
	exit_area = manager.current_level.get_node("Levelwechseln/Ausgang") as Area3D
	check(manager.request_transition(exit_area, LAIR, ^"MissingArrival"), "Fehlerhafter Übergang startet kontrolliert")
	await frames()
	check(manager.current_level_path == MainGame.DEFAULT_LEVEL and not game.transition_root.get_node("FadeRect").visible and not GameState.is_player_input_locked(), "Fehler blendet alte Szene wieder ein und gibt Eingabe frei")
	tree.current_scene.free()
	print("level_transitions: %d Checks, %d Fehler" % [checks, failures])
	tree.quit(1 if failures else 0)
