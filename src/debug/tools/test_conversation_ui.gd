extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func drain(window: Node) -> void:
	for index in 20:
		if window.dialogue_line == null or not window.dialogue_line.responses.is_empty():
			return
		await window.next(window.dialogue_line.next_id)

func _run() -> void:
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	var system := DialogueSystem.instance
	var merchant := game.level_root.find_child("MerchantNPC", true, false) as NPC
	var quest := game.level_root.find_child("QuestNPC", true, false) as NPC
	var enemy := game.level_root.find_child("EnemyNPC", true, false) as NPC
	var interaction := merchant.get_node("Interaction") as NPCInteraction
	var player := game.party.leader
	interaction.perform_action("talk", player)
	await get_tree().process_frame
	var window: Control = system._active_balloon
	check(window != null and window.size.is_equal_approx(window.get_viewport_rect().size), "Gespräch nimmt gesamten Bildschirm ein")
	check(window.left_speaker.name == merchant.get_display_name() and window.right_speaker.name == player.get_display_name(), "Startporträts sind Händler und aktueller Anführer")
	check(window.right_speaker.portrait == player.character.get_portrait(), "Vorhandenes Spielerporträt wird benutzt")
	check(window._right.picture.size.y > 100, "Porträt hat sichtbare Größe auch ohne Platzhalter")
	check(window._left.fallback.visible, "Fehlendes NPC-Porträt hat Platzhalter")
	interaction.perform_action("talk", player)
	check(system._active_balloon == window and GameState._input_lock_count == 1, "Doppelter Start erzeugt keine zweite Sitzung/Sperre")
	Input.action_press("Inventar")
	player._process(0.1)
	Input.action_release("Inventar")
	check(not player._inventory_layer.visible, "Inventartaste öffnet kein Fenster über Gespräch")
	await drain(window)
	check(window.entries.size() == 3 and system._session_active, "END erhält Verlauf und Sitzung")
	check(window._options.get_child_count() == 3, "Händler bietet Handeln, Name und Job")
	var topics := system.conversation_options(window.dialogue_resource)
	await window._topic(topics[1])
	check(window.entries[-1].text.contains("Händler"), "Namensthema läuft im gleichen Fenster")
	await drain(window)
	await window._topic(topics[2])
	await drain(window)
	check(window.entries.size() >= 7, "Verlauf über mehrere Themen bleibt erhalten")
	# Mehrere Sprecher aus beiden Lagern, inklusive identischer Anzeigenamen.
	var line := DialogueLine.new()
	line.character = "shalka"
	line.text = "Wir sollten noch nach Vorräten fragen."
	window._append_line(line)
	check(window.right_speaker.name == "Shalka" and window.left_speaker.name == merchant.get_display_name(), "Begleiter wechselt nur rechtes Porträt")
	line = DialogueLine.new()
	line.character = "Elara"
	line.text = "Vergesst nicht, dass der Weg gefährlich ist."
	window._append_line(line)
	check(window.left_speaker.name == "Elara" and window.right_speaker.name == "Shalka", "Weiterer NPC wechselt nur linkes Porträt")
	check(window.entries[-1].party == false and window.entries[-2].party == true, "Beiträge werden nach Parteizugehörigkeit ausgerichtet")
	line = DialogueLine.new()
	line.character = "Händler"
	line.text = "Dann schaut euch in Ruhe um."
	window._append_line(line)
	if "--visual" in OS.get_cmdline_user_args():
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/conversation-ui-preview.png")
		var previous_size := get_window().size
		get_window().size = Vector2i(800, 600)
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/conversation-ui-small.png")
		get_window().size = previous_size
	window._topic(topics[0])
	check(not system._session_active and ShopManager.instance._shop_ui.visible, "Handeln beendet Gespräch und öffnet Laden")
	ShopManager.close()
	check(not GameState.is_player_input_locked(), "Handel hinterlässt keine Gesprächssperre")
	# Wissen ist an die tatsächlich sprechende Figur gebunden.
	var quest_interaction := quest.get_node("Interaction") as NPCInteraction
	quest_interaction.perform_action("talk", player)
	await get_tree().process_frame
	window = system._active_balloon
	check(system.conversation_options(window.dialogue_resource).size() == 1, "Unbekanntes Wort ist kein Thema")
	GameState.world_state.define_fact("bandit_location_west", "bandit_01", "located_in", "west_of_elara")
	GameState.world_state.learn_fact(player.character.character_id, "bandit_location_west")
	check(system.conversation_options(window.dialogue_resource).size() == 2, "Gelerntes Wort wird Thema")
	window.close()
	await get_tree().process_frame
	check(game.party.move_member(game.party.followers[0], -1), "Anführerwechsel nach Gespräch möglich")
	quest_interaction.perform_action("talk", game.party.leader)
	await get_tree().process_frame
	window = system._active_balloon
	check(window.right_speaker.name == "Shalka", "Gewechselter Party-Anführer startet rechts")
	check(system.conversation_options(window.dialogue_resource).size() == 1, "Wissen eines anderen Mitglieds wird nicht vorgetäuscht")
	await drain(window)
	await window._choose(window.dialogue_line.responses[0])
	check(window.entries[-1].speaker == "Shalka", "Gesprochene Questantwort verwendet aktiven Anführer")
	await drain(window)
	check(GameState.knows_fact("shalka", "bandit_location_west"), "Questentscheidung vermittelt der sprechenden Shalka Wissen")
	GameState.acquire_input_lock()
	window.close()
	check(GameState.is_player_input_locked(), "Schließen bewahrt eine fremde Eingabesperre")
	GameState.release_input_lock()
	# Ein ungültiger Titel darf weder UI noch Sperre erzeugen.
	var invalid := interaction.data.duplicate() as NPCData
	invalid.dialogue_start = "missing_title"
	DialogueSystem.start_npc_dialogue(invalid, game.party.leader, interaction)
	check(not system._session_active and not GameState.is_player_input_locked(), "Fehlender Einstieg hinterlässt keine Sitzung")
	# Triggert aus echter Dialogue-Manager-Mutation; danach keine unsichtbare Sperre.
	var enemy_interaction := enemy.get_node("Interaction") as NPCInteraction
	enemy_interaction.perform_action("talk", game.party.leader)
	await get_tree().process_frame
	window = system._active_balloon
	check(window.dialogue_line.responses.size() == 2, "Bandit bietet seine Dialogantworten")
	await window._choose(window.dialogue_line.responses[0])
	await window.next(window.dialogue_line.next_id)
	check(not system._session_active and CombatManager.instance.is_in_combat(), "Angriffsmutation schließt Fenster und startet Kampf")
	for frame in 3: await get_tree().process_frame
	game.free()
	check(not GameState.is_player_input_locked(), "Abbau räumt Sperren auf")
	print("conversation_ui: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
