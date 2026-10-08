extends Node

const SAVE := "/tmp/necota-leader-test.json"
const LAIR := "res://src/world/levels/regions/MonsterLair-Level1/MonsterLair-Level1.tscn"
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	tree.root.add_child(game)
	tree.current_scene = game
	var party := game.party
	var dannerman := party.leader
	var shalka := party.followers[0]
	var d_data := dannerman.character
	var s_data := shalka.character
	var d_position := dannerman.global_position
	var s_position := shalka.global_position
	dannerman.gold = 193
	shalka.gold = 47
	var ui := game.game_windows
	ui.open_page(0)
	var rows := ui._body
	check(not rows.get_child(2).get_child(2).disabled, "Shalkas Aufwärtspfeil ist aktiv")
	check(GameState.is_player_input_locked(), "Partyfenster sperrt Bewegung")
	rows.get_child(2).get_child(2).pressed.emit()
	check(party.leader == shalka and party.followers == [dannerman], "Echter UI-Pfeil wechselt Anführer")
	check(shalka.is_player_controlled and not dannerman.is_player_controlled, "Genau eine Figur wird gesteuert")
	check(dannerman.leader == shalka and shalka.leader == null, "Alter Anführer folgt neuem")
	check(shalka.global_position == s_position and dannerman.global_position == d_position, "Wechsel teleportiert keine Figur")
	check(dannerman.character == d_data and shalka.character == s_data and dannerman.gold == 193 and shalka.gold == 47, "Figuren behalten Daten und Inventaridentität")
	check(game.camera_system.target == shalka, "Kamera folgt Shalka")
	check(party.get_party_hud()._entries[0].member == shalka, "HUD übernimmt neue Reihenfolge")
	check(GameState.world_state.party_state == {"leader_id": "shalka", "member_ids": ["shalka", "dannerman"]}, "Partyreihenfolge wird gespeichert")
	check(dannerman.is_in_group("interactable") and not shalka.is_in_group("interactable"), "Tauschinteraktion folgt Begleiterrolle")
	if "--visual" in OS.get_cmdline_user_args():
		await tree.process_frame
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("/tmp/party-leader-preview.png")
	ui.close()
	check(not GameState.is_player_input_locked(), "Schließen gibt Bewegung frei")
	Input.action_press("Right")
	check(shalka.get_move_direction().x > 0.0 and dannerman.get_move_direction() == Vector3.ZERO, "WASD steuert ausschließlich Shalka")
	Input.action_release("Right")
	shalka.global_position += Vector3(5, 0, 0)
	dannerman._update_follow(0.1)
	check(Vector2(dannerman.velocity.x, dannerman.velocity.z).length() > 0.0, "Dannerman läuft als Begleiter")
	shalka.toggle_inventory()
	check(ui.visible and ui.active_page == 2 and (ui._embedded_views[0] as InventoryUI).playable == shalka, "Inventar gehört neuem Anführer")
	shalka.toggle_inventory()
	shalka.toggle_character_sheet()
	check(ui.visible and ui.active_page == 1, "Shalkas Charakterbogen funktioniert")
	shalka.toggle_character_sheet()
	var interact := InputEventAction.new()
	interact.action = "Interact"
	interact.pressed = true
	check(shalka.state_machine.current_state.handle_input(interact) == shalka.get_node("StateMachine/ActionMenu"), "Shalka hat vollständige Interaktionssteuerung")
	GameState.acquire_input_lock()
	check(not party.move_member(dannerman, -1), "Fremde Interaktionssperre verhindert Wechsel")
	ui.open_page(0)
	check(not ui.visible, "Pfeile bei fremder Sperre deaktiviert")
	ui.close()
	check(GameState.is_player_input_locked(), "Fenster löst fremde Sperre nicht")
	GameState.release_input_lock()
	var session := CombatSession.new()
	game.get_node("Systems/CombatManager").active_session = session
	check(not party.move_member(dannerman, -1), "Kampf verhindert Wechsel")
	game.get_node("Systems/CombatManager").active_session = null
	shalka.enter_combat_mode(session)
	dannerman.enter_combat_mode(session)
	check(not shalka._follow_enabled and not dannerman._follow_enabled, "Keine Figur folgt während Kampf")
	shalka.exit_combat_mode()
	dannerman.exit_combat_mode()
	check(shalka.state_machine.process_mode == Node.PROCESS_MODE_INHERIT and dannerman.state_machine.process_mode == Node.PROCESS_MODE_DISABLED, "Kampfende stellt Steuerungsrollen wieder her")
	check(not shalka._follow_enabled and dannerman._follow_enabled, "Kampfende stellt Begleiterbewegung wieder her")
	session.free()
	check(game.level_manager._load_level(LAIR, ^"Levelwechseln/Eingang/Eingangsshape"), "Ortswechsel mit Shalka möglich")
	check(party.leader == shalka and game.camera_system.target == shalka, "Levelwechsel erhält Anführer")
	check(shalka.global_position.is_equal_approx(game.level_manager.current_level.get_node("Levelwechseln/Eingang/Eingangsshape").global_position), "Neuer Anführer landet am Eingang")
	check(game.level_manager.save_world(SAVE) == OK, "Shalka als Anführer speicherbar")
	check(await GameState.load_game(SAVE) == OK, "Echter Spiellader lädt neue Rollen")
	game = tree.current_scene as MainGame
	party = game.party
	check(party.leader.character.character_id == "shalka" and party.followers[0].character.character_id == "dannerman", "Laden rekonstruiert Rollen")
	check(party.leader.gold == 47 and party.followers[0].gold == 193, "Laden erhält getrennte Charakterwerte")
	check(game.camera_system.target == party.leader and party.followers[0].leader == party.leader, "Laden bindet Kamera und Begleiter")
	check(party.move_member(party.followers[0], -1), "Wechsel zurück zu Dannerman möglich")
	check(party.leader.character.character_id == "dannerman" and party.leader.is_player_controlled, "Dannerman wieder steuerbar")
	tree.current_scene = null
	game.free()
	print("party_leader: %d Checks, %d Fehler" % [checks, failures])
	tree.quit(1 if failures else 0)
