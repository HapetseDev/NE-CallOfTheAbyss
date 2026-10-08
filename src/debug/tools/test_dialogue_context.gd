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
	var quest := game.level_root.find_child("QuestNPC", true, false) as NPC
	var interaction := quest.get_node("Interaction") as NPCInteraction
	var player := game.party.leader
	interaction.perform_action("talk", player)
	await get_tree().process_frame
	var balloon: Node = DialogueSystem.instance._active_balloon
	check(balloon != null and balloon.get("dialogue_line") != null, "Echter Gesprächsstart löst player auf")
	check(GameState.is_player_input_locked(), "Gespräch sperrt Eingaben")
	# Bis zur Antwortauswahl und über den echten Annahmezweig weitergehen.
	await balloon.next(balloon.get("dialogue_line").next_id)
	check(balloon.get("dialogue_line").responses.size() == 2, "Questantworten verfügbar")
	await balloon.next(balloon.get("dialogue_line").responses[0].next_id)
	await balloon.next(balloon.get("dialogue_line").next_id)
	check(GameState.world_state.get_quest_state("bandit") == "active" and GameState.knows_fact(player.character.character_id, "bandit_location_west"), "Annahme verwendet den tatsächlichen Gesprächspartner")
	await balloon.next(balloon.get("dialogue_line").next_id)
	await get_tree().process_frame
	check(GameState.is_player_input_locked(), "Zweigende hält Themenauswahl offen")
	balloon.close()
	check(not GameState.is_player_input_locked(), "Explizites Gesprächsende gibt Eingaben frei")
	GameState.set_flag("defeated_bandit", true)
	var gold: int = player.gold
	if is_instance_valid(balloon): balloon.close()
	interaction.perform_action("talk", player)
	await get_tree().process_frame
	balloon = DialogueSystem.instance._active_balloon
	check(player.gold == gold + 20 and GameState.world_state.get_quest_state("bandit") == "completed", "Echter Belohnungsstart löst player ebenfalls auf")
	await balloon.next(balloon.get("dialogue_line").next_id)
	await get_tree().process_frame
	if is_instance_valid(balloon): balloon.close()
	interaction.perform_action("talk", player)
	await get_tree().process_frame
	balloon = DialogueSystem.instance._active_balloon
	check(player.gold == gold + 20, "Erneutes Gespräch zahlt nicht doppelt")
	await balloon.next(balloon.get("dialogue_line").next_id)
	await get_tree().process_frame
	balloon.close()
	check(not GameState.is_player_input_locked(), "Wiederholung hinterlässt keine Sperre")
	game.free()
	print("dialogue_context: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
