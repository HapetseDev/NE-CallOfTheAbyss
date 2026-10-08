extends Node

class SuccessfulSteal extends StealUI:
	func _roll_success() -> bool:
		return true

var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func talk(game: MainGame, accept: bool = false) -> void:
	var quest := game.level_root.find_child("QuestNPC", true, false) as NPC
	quest.get_node("Interaction").perform_action("talk", game.party.leader)
	await get_tree().process_frame
	var balloon: Node = DialogueSystem.instance._active_balloon
	for step in range(12):
		if not is_instance_valid(balloon) or not DialogueSystem.instance._session_active:
			break
		var line: DialogueLine = balloon.get("dialogue_line")
		if line == null:
			balloon.close()
			break
		var next_id: String = line.responses[0 if accept else 1].next_id if not line.responses.is_empty() else line.next_id
		await balloon.next(next_id)
		await get_tree().process_frame
	check(not GameState.is_player_input_locked(), "Gespräch vollständig beendet")

func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	tree.change_scene_to_file("res://src/core/main_game/main_game.tscn")
	await tree.scene_changed
	var game := tree.current_scene as MainGame
	var player := game.party.leader
	var starting_gold: int = player.gold
	await talk(game, true)
	check(GameState.world_state.get_quest_state("bandit") == "active", "Quest über echtes Gespräch angenommen")
	player.gold = 200 # Deterministisches Budget für die kombinierte Testreise.
	var shop := ShopManager.instance.get_shop("haendler_01")
	var initial_stock: int = shop.entries[0].stock
	ShopManager.open("haendler_01", player)
	var shop_ui := ShopManager.instance._shop_ui
	shop_ui._on_shop_item_selected(0)
	shop_ui._on_player_item_selected(player.inventory.size() - 1)
	shop_ui.close()
	check(player.gold == 182 and shop.entries[0].stock == initial_stock - 1, "Handeln erhält Geld und begrenzten Bestand")
	var potion := game.level_root.find_child("Heiltrank", true, false) as BasicItem
	potion.perform_action("pickup", player)
	check(GameState.apply_effects([{"type": "transfer_item", "character_id": "dannerman", "target_id": "shalka", "world_object_id": "level1_potion_1", "count": 1}]), "Weltgegenstand an Begleiterin übergeben")
	var merchant := game.level_root.find_child("MerchantNPC", true, false) as NPC
	# Ein normales vorhandenes Item als deterministisches Diebstahlangebot.
	merchant.add_item(load("res://src/resources/items/heiltrank.tres"), 1)
	var steal := SuccessfulSteal.new()
	StealManager.instance.add_child(steal)
	StealManager.instance._steal_ui = steal
	steal.closed.connect(StealManager.instance._on_steal_ui_closed)
	StealManager.open(player, merchant)
	steal._on_item_selected(merchant.inventory.size() - 1)
	steal.close()
	check(GameState.world_state.events.has_event("item_stolen", {"character_id": "dannerman"}), "Erfolgreicher Diebstahl wird erfasst")
	var bandit := game.level_root.find_child("EnemyNPC", true, false) as NPC
	CombatManager.trigger_attack(player, bandit)
	var session := CombatManager.instance.active_session
	var target := session.get_participant(bandit)
	bandit.character.gewandheit = 0
	var action := CombatAction.new()
	action.type = CombatAction.ActionType.ITEM
	action.actor = session.get_participant(player)
	action.targets = [target]
	action.item = ItemData.new()
	action.item_usage_mode = ItemUsageMode.new()
	action.item_usage_mode.power = 10000
	action.item_usage_mode.requires_line_of_sight = false
	var result := CombatResolver.resolve_action(action)
	for defeated in result.defeated_targets:
		session.mark_defeated(defeated)
	check(not CombatManager.instance.is_in_combat() and GameState.world_state.get_quest_state("bandit") == "ready", "Kampf macht Quest abgabebereit")
	await talk(game)
	check(player.gold == 202 and GameState.world_state.get_quest_state("bandit") == "completed", "Quest zahlt nach Handel genau einmal aus")
	LevelManager.load_level(MainGame.DEFAULT_LEVEL)
	check(GameState.world_state.get_object_owner("level1_potion_1") == "shalka", "Level-Neuaufbau erhält eindeutigen Besitz")
	check(ShopManager.instance.get_shop("haendler_01").entries[0].stock == initial_stock - 1, "Level-Neuaufbau erhält Händlerbestand")
	var before: Array = GameState.world_state.events.snapshot()
	var inventories: Dictionary = {}
	for id in GameState.character_registry.get_registered_ids():
		inventories[id] = WorldValueCodec.new().encode(GameState.character_registry.get_character(id).inventory)
	var catalog := preload("res://src/core/world/save_catalog.gd").new()
	catalog.directory = "/tmp/necota-journey-%d" % Time.get_ticks_usec()
	var saved: Dictionary = catalog.save_new("Nach Questabschluss", game.level_manager)
	check(saved.error == OK, "Kombinierte Sitzung in neuem Slot gespeichert")
	player.gold = 1
	check(await GameState.load_game(saved.path) == OK, "Gemeinsamer Ladeablauf übernimmt komplette Sitzung")
	game = tree.current_scene as MainGame
	player = game.party.leader
	check(player.gold == 202 and GameState.world_state.events.snapshot() == before, "Laden stellt Geld und unveränderte Ereignisfolge her")
	var inventories_match := true
	for id in inventories:
		inventories_match = inventories_match and inventories[id] == WorldValueCodec.new().encode(GameState.character_registry.get_character(id).inventory)
	check(inventories_match, "Alle Inventare nach Handel, Übergabe und Diebstahl vollständig wiederhergestellt")
	check(GameState.world_state.get_object_owner("level1_potion_1") == "shalka" and game.party.followers.size() == 1, "Laden erhält Party und Besitz")
	check(GameState.knows_fact("dannerman", "bandit_location_west") and GameState.world_state.get_quest_state("bandit") == "completed", "Wissen und Questabschluss bleiben erhalten")
	check(ShopManager.instance.get_shop("haendler_01").entries[0].stock == initial_stock - 1, "Laden erhält erschöpften Händlerbestand")
	bandit = game.level_root.find_child("EnemyNPC", true, false) as NPC
	check(bandit.character.is_defeated, "Besiegter Bandit bleibt besiegt")
	await talk(game)
	check(player.gold == 202 and GameState.world_state.events.snapshot() == before, "Wiederholtes Gespräch nach Laden erzeugt keine Belohnung")
	tree.change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	await tree.scene_changed
	var main := tree.current_scene as MainMenu
	main._on_start_pressed()
	await tree.scene_changed
	game = tree.current_scene as MainGame
	check(game.party.leader.gold == starting_gold and GameState.world_state.events.snapshot().is_empty(), "Neues Spiel startet mit frischem Gold und Ereignisprotokoll")
	check(GameState.world_state.get_quest_state("bandit") == "not_started" and not GameState.knows_fact("dannerman", "bandit_location_west"), "Neustart entfernt Quest und Wissen")
	check(GameState.world_state.get_object_owner("level1_potion_1").is_empty() and ShopManager.instance.get_shop("haendler_01").entries[0].stock == initial_stock, "Neustart stellt Weltgegenstand und Shop wieder her")
	check(WorldSaveStore.new().read(saved.path).characters.get_character("dannerman").gold == 202, "Neues Spiel verändert gespeicherte Datei nicht")
	tree.current_scene.free()
	print("gameplay_journey: %d Checks, %d Fehler" % [checks, failures])
	tree.quit(1 if failures else 0)
