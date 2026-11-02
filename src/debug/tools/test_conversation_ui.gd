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
	var previous_speed := DialogueSettings.speed_index
	var previous_sound := DialogueSettings.sound_enabled
	DialogueSettings.speed_index = 1
	DialogueSettings.sound_enabled = true
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	game.game_windows.open_page(5)
	game.game_windows._options()
	var speed_choice: OptionButton
	var sound_choice: CheckButton
	for control in game.game_windows._body.get_children():
		if control is OptionButton and control.item_count == 4 and control.get_item_text(0) == "Langsam":
			speed_choice = control
		if control is CheckButton and control.text == "Sprechton beim Textaufbau":
			sound_choice = control
	check(speed_choice != null and speed_choice.selected == 1 and sound_choice != null, "Optionen enthalten Texttempo und Sprechton")
	if "--visual" in OS.get_cmdline_user_args():
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		game.game_windows._scroll.ensure_control_visible(sound_choice)
		for frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/dialogue-options-preview.png"))
	game.game_windows.close()
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
	check(not window._typing_labels.is_empty(), "Neue Zeile startet mit Schreibanimation")
	var typing_label: DialogueLabel = window._typing_labels[0]
	check(typing_label.visible_characters < typing_label.get_total_character_count(), "Text erscheint anfangs unvollständig")
	var entry_count: int = window.entries.size()
	await get_tree().create_timer(0.15).timeout
	check(typing_label.visible_characters > 0 and typing_label.visible_ratio < 1, "Text wächst über die Zeit")
	check(window._options.get_child_count() == 1 and window._options.get_child(0).text == "Text vollständig anzeigen", "Antworten warten auf Textende")
	window._options.get_child(0).pressed.emit()
	await get_tree().process_frame
	check(typing_label.visible_ratio == 1 and window._typing_labels.is_empty(), "Überspringen zeigt vollständigen Text")
	check(window.entries.size() == entry_count, "Überspringen schaltet keine Zeile weiter")
	check(window.left_speaker.name == merchant.get_display_name() and window.right_speaker.name == player.get_display_name(), "Startporträts sind Händler und aktueller Anführer")
	check(window.right_speaker.portrait == player.character.get_portrait(), "Vorhandenes Spielerporträt wird benutzt")
	check(window._right.picture.size.y > 100, "Porträt hat sichtbare Größe auch ohne Platzhalter")
	check(window._left.fallback.visible, "Fehlendes NPC-Porträt hat Platzhalter")
	window._last_voice_msec = -1000
	window._on_letter_spoken("A", 0, 1.0, 0.75, true)
	check(is_equal_approx(window._voice_player.pitch_scale, 0.75), "Voice verändert Tonhöhe")
	window._last_voice_msec = -1000
	window._on_letter_spoken(" ", 0, 1.0, 1.5, true)
	check(is_equal_approx(window._voice_player.pitch_scale, 0.75), "Leerzeichen bleiben stumm")
	DialogueSettings.sound_enabled = false
	window._on_letter_spoken("A", 0, 1.0, 1.5, true)
	check(is_equal_approx(window._voice_player.pitch_scale, 0.75), "Tonoption deaktiviert Sprechton")

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
	var before_reply: DialogueLine = window.dialogue_line
	window._topic(topics[1])
	check(window._reply_pending and not window._typing_labels.is_empty(), "Gewählte Party-Antwort wird eingetickert")
	check(window.dialogue_line == before_reply, "NPC wartet auf die gesprochene Party-Antwort")
	check(window._typing_labels[0].horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Gesprochene Party-Antwort bleibt rechtsbündig")
	window._finish_typing()
	await get_tree().process_frame
	await drain(window)

	await window._topic(topics[1])
	check(window.entries[-1].text.contains("Händler"), "Namensthema läuft im gleichen Fenster")
	await drain(window)
	await window._topic(topics[2])
	await drain(window)
	check(window.entries.size() >= 7, "Verlauf über mehrere Themen bleibt erhalten")
	DialogueSettings.speed_index = 3
	var instant_line := DialogueLine.new()
	instant_line.text = "Sofort sichtbarer Text."
	window._append_line(instant_line)
	var instant_body: DialogueLabel = window._history.get_child(-1).get_child(-1)
	check(window._typing_labels.is_empty() and instant_body.visible_ratio == 1.0, "Sofort zeigt Text ohne Animation")
	DialogueSettings.speed_index = 1
	var short_line := DialogueLine.new()
	short_line.text = "Ja"
	window._append_line(short_line)
	window._refresh_options()
	await get_tree().create_timer(0.2).timeout
	check(window._typing_labels.is_empty() and window._options.get_child_count() == 3, "Natürliches Textende stellt Themenauswahl wieder her")
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
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/conversation-ui-preview.png"))
		var previous_size := get_window().size
		get_window().size = Vector2i(800, 600)
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/conversation-ui-small.png"))
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
	window._speak_choice("Dies ist eine noch nicht vollständig gesprochene Antwort.", "start")
	check(window._reply_pending, "Party-Antwort wartet während der Animation")
	window.close()
	check(not window._reply_pending and not system._session_active, "Schließen bricht wartende Party-Antwort sauber ab")
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
	DialogueSettings.speed_index = previous_speed
	DialogueSettings.sound_enabled = previous_sound
	check(not GameState.is_player_input_locked(), "Abbau räumt Sperren auf")
	print("conversation_ui: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
