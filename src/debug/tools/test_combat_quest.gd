extends Node

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
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	for index in 30: await get_tree().physics_frame
	var leader := game.party.leader
	var bandit := game.level_root.find_child("EnemyNPC", true, false) as NPC
	var manager := CombatManager.instance
	CombatManager.trigger_attack(leader, bandit)
	var session := manager.active_session
	session.mark_fled(session.get_participant(bandit))
	for index in 1200:
		if bandit.flee_path.is_empty(): break
		await get_tree().physics_frame
	check(not GameState.get_flag("defeated_bandit"), "Flucht erzeugt kein Sieg-Flag")
	check(not manager.is_in_combat(), "Flucht beendet diesen Kampf")
	check(game._combat_order_hud._session == null and game._combat_order_hud._entries.is_empty(), "Kampfende entfernt Sitzung und Einträge aus dem HUD")
	check(GameState.world_state.events.snapshot().is_empty(), "Flucht erzeugt kein Niederlageereignis")
	CombatManager.trigger_attack(leader, bandit)
	session = manager.active_session
	var target := session.get_participant(bandit)
	# Deterministische Schadensaktion durch denselben Resolver wie im Spiel.
	bandit.character.gewandheit = 0
	var action := CombatAction.new()
	action.type = CombatAction.ActionType.ITEM
	action.actor = session.get_participant(leader)
	action.targets = [target]
	action.item = ItemData.new()
	action.item_usage_mode = ItemUsageMode.new()
	action.item_usage_mode.power = 10000
	action.item_usage_mode.requires_line_of_sight = false
	var result := CombatResolver.resolve_action(action)
	check(result.defeated_targets.has(target) and bandit.is_character_dead(), "Resolver meldet tatsächliche Niederlage")
	for defeated in result.defeated_targets:
		session.mark_defeated(defeated)
	check(GameState.get_flag("defeated_bandit"), "Kampfniederlage setzt konfiguriertes Flag")
	check(not manager.is_in_combat(), "Kampf endet nach Niederlage")
	session.mark_defeated(target)
	check(GameState.get_flag("defeated_bandit"), "Doppelte Meldung bleibt harmlos")
	check(GameState.world_state.events.snapshot().size() == 1 and GameState.world_state.events.has_event("npc_defeated", {"character_id": "bandit_01"}), "Doppelte Niederlagemeldung erzeugt genau ein Ereignis")
	var interaction := bandit.get_node("Interaction") as NPCInteraction
	check(interaction.is_defeated(), "NPC-Interaktion erkennt Niederlage")
	var quest := game.level_root.find_child("QuestNPC", true, false) as NPC
	var quest_data: NPCData = quest.get_node("Interaction").data
	check(DialogueSystem.instance._resolve_start_cue(quest_data) == "quest_done", "Echter Einstieg wählt Belohnungsdialog")
	check(bandit.character.is_defeated, "Niederlage liegt im Charakterblatt")
	bandit.heal(10000)
	check(not bandit.can_participate_in_combat(), "Heilung hebt Niederlage nicht auf")
	CombatManager.trigger_attack(leader, bandit)
	check(not manager.is_in_combat(), "Direkter Angriff auf besiegten NPC wird verhindert")
	CombatManager.trigger_attack(bandit, leader)
	check(not manager.is_in_combat(), "Besiegter NPC darf keinen Kampf starten")
	var isolated := CombatSession.new()
	check(isolated.admit(bandit, CombatParticipantResolver.SIDE_VICTIM) == null, "Direkte Teilnahme wird ebenfalls abgelehnt")
	isolated.free()
	bandit.global_position = leader.global_position
	check(not CombatParticipantResolver.scan_candidates(leader).has(bandit), "Besiegter NPC wird nicht als Zuschauer rekrutiert")
	LevelManager.load_level(MainGame.DEFAULT_LEVEL)
	bandit = game.level_root.find_child("EnemyNPC", true, false) as NPC
	check(bandit != null and bandit.character.is_defeated and not bandit.can_participate_in_combat(), "Levelwechsel erhält sichtbaren besiegten NPC")
	interaction = bandit.get_node("Interaction") as NPCInteraction
	check(interaction.get_actions(leader).size() == 1 and interaction.get_actions(leader)[0].action_id == "talk", "Nur Reden bleibt verfügbar")
	var merchant := game.level_root.find_child("MerchantNPC", true, false) as NPC
	var merchant_interaction := merchant.get_node("Interaction") as NPCInteraction
	merchant_interaction.mark_defeated()
	check(merchant.character.is_defeated and merchant_interaction.get_actions(leader).size() == 1, "Auch NPC ohne Sieg-Flag bleibt besiegt")
	merchant_interaction.perform_action("trade", leader)
	check(not GameState.is_player_input_locked(), "Direkter Handelsaufruf wird blockiert")
	var gold: int = leader.gold
	var resource := load(quest_data.dialogue_file) as DialogueResource
	var context: Array = [{"player": leader}]
	var line := await DialogueManager.get_next_dialogue_line(resource, "quest_done", context)
	check(leader.gold == gold + 20 and GameState.get_flag("quest_bandit_done"), "Kampfsieg führt zur einmaligen Belohnung")
	line = await DialogueManager.get_next_dialogue_line(resource, "quest_done", context)
	check(leader.gold == gold + 20, "Wiederholung zahlt nicht erneut")
	check(game.level_manager.save_world("/tmp/necota-combat-quest.json") == OK, "Ergebnis nach Kampf speicherbar")
	var saved := WorldSaveStore.new().read("/tmp/necota-combat-quest.json")
	check(saved != null and saved.flags.get("defeated_bandit") and saved.flags.get("quest_bandit_done") and saved.characters.get_character("dannerman").gold == gold + 20, "Speicherstand erhält Sieg und Auszahlung")
	context.clear()
	for entry in resource.lines.values():
		entry.erase("resource")
	game.free()
	check(GameState.install_world(saved), "Gespeicherte Welt installieren")
	game = load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	bandit = game.level_root.find_child("EnemyNPC", true, false) as NPC
	check(bandit.character.is_defeated and not bandit.can_participate_in_combat(), "Laden erhält Niederlage trotz geheilter Punkte")
	check(GameState.world_state.events.snapshot().size() == 2, "Laden ergänzt weder Niederlage noch Questabschluss")
	game.free()
	game = load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	bandit = game.level_root.find_child("EnemyNPC", true, false) as NPC
	check(not bandit.character.is_defeated and bandit.can_participate_in_combat(), "Neues Spiel stellt Kampffähigkeit wieder her")
	GameState.set_flag("defeated_bandit", true)
	LevelManager.load_level(MainGame.DEFAULT_LEVEL)
	bandit = game.level_root.find_child("EnemyNPC", true, false) as NPC
	check(bandit.character.is_defeated, "Altes Sieg-Flag wird beim Szenenaufbau übernommen")
	game.free()
	check(not GameState.has_flag("defeated_bandit"), "Neustart entfernt Sieg-Flag")
	print("combat_quest: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
