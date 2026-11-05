extends Node

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _ready() -> void:
	_run.call_deferred()

func wait_animation() -> void:
	await get_tree().create_timer(NEDimensions.COMBAT_CARD_TRANSITION_SEC + 0.12).timeout

func _run() -> void:
	GameState.reset_session()
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	for index in 3:
		await get_tree().process_frame
	var party_hud := game._party_hud
	var hud := game._combat_order_hud
	var leader := game.party.leader
	var follower := game.party.followers[0]
	var original_leader_card := party_hud._world_panels[0]
	var original_follower_card := party_hud._world_panels[1]
	check(not hud.visible and original_leader_card.visible, "Außerhalb Kampf nur Weltkarten sichtbar")
	var enemy := Playable.new()
	enemy.character = CharacterResource.new()
	enemy.character.character_name = "Testgegner"
	enemy.character.ensure_initialized()
	game.add_child(enemy)
	enemy.set_physics_process(false)
	var session := CombatSession.new()
	add_child(session)
	session.set_process(false)
	var a := session.admit(leader, CombatParticipantResolver.SIDE_ATTACKER)
	var b := session.admit(follower, CombatParticipantResolver.SIDE_ATTACKER)
	var c := session.admit(enemy, CombatParticipantResolver.SIDE_VICTIM)
	var a_speed := leader.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)
	var b_speed := follower.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)
	leader.character.gewandheit += maxi(0, b_speed - a_speed) + 10
	a.initiative_meter = 90
	b.initiative_meter = 0
	c.initiative_meter = 0
	hud._on_combat_started(session)
	check(hud._entries.size() == 3, "Alle Kombattanten besitzen Karten")
	check(hud._entries[a].card == original_leader_card and hud._entries[b].card == original_follower_card, "Partykarten werden übernommen, nicht dupliziert")
	check(party_hud._borrowed.size() == 2, "Welttracking pausiert nur für übernommene Karten")
	check(hud._entries[c].card.get_child(0) is PartyHudEntry, "Gegner verwendet dieselbe Charakterkarte")
	check(hud._entries[c].find_child("ReadinessBar", true, false) == null, "Keine Initiativebalken in der neuen Reihe")
	await wait_animation()
	if "--preview-cards" in OS.get_cmdline_user_args():
		await get_tree().create_timer(60).timeout
		get_tree().quit()
		return
	check(hud._entries[a].scale.is_equal_approx(Vector2.ONE * 0.5), "Alle Kartendimensionen auf 50 Prozent skaliert")
	check(hud._entries[a].position.y == 0, "Karten erreichen obere Reihe")
	session.turn_queue.assign([b, c])
	session._advance_turn_queue()
	hud._sync_entries()
	check(hud._ordered_participants()[0] == b and hud._ordered_participants()[1] == c, "Aktiver Zug vor wartenden Zügen")
	session.end_turn(b)
	hud._sync_entries()
	check(hud._ordered_participants()[0] == c, "Wartender Zug rückt nach Abschluss nach links")
	session.turn_queue.clear()
	a.initiative_meter = 0
	b.initiative_meter = 80
	leader.character.gewandheit += 100
	hud._sync_entries()
	check(hud._ordered_participants().find(a) < hud._ordered_participants().find(b), "Hohe Geschwindigkeit kann niedrigen Füllstand überholen")
	var original_enemy_entry := hud._entries[c] as CombatOrderEntry
	c.has_fled = true
	session.participant_fled.emit(c)
	check(not hud._entries.has(c) and hud._departing.has(c), "Flucht entfernt Karte sofort aus Sortierung, startet Animation")
	await get_tree().create_timer(0.08).timeout
	check(float(original_enemy_entry._exit_material.get_shader_parameter("desaturation")) > 0, "Ausscheidende Karte wird ausgegraut")
	session.admit(enemy, CombatParticipantResolver.SIDE_VICTIM)
	check(hud._entries.get(c) == original_enemy_entry and not hud._departing.has(c), "Rückkehr während Animation bricht Entfernung ab")
	await wait_animation()
	check(is_instance_valid(original_enemy_entry) and original_enemy_entry.modulate.a == 1.0, "Zurückgekehrte Karte bleibt sichtbar und wird nicht verspätet gelöscht")
	c.has_fled = true
	session.participant_fled.emit(c)
	await wait_animation()
	check(not is_instance_valid(original_enemy_entry) and not hud._departing.has(c), "Nach Austritt sind Karten-Node und UI-Referenz freigegeben")
	check(session.get_participant(enemy) == c, "Autoritativer Teilnehmer bleibt für Rückkehr erhalten")
	session.admit(enemy, CombatParticipantResolver.SIDE_VICTIM)
	check(hud._entries.has(c) and hud._entries.size() == 3, "Späte Rückkehr erzeugt genau eine neue Karte")
	var newcomer := Playable.new()
	newcomer.character = CharacterResource.new()
	newcomer.character.ensure_initialized()
	game.add_child(newcomer)
	newcomer.set_physics_process(false)
	var d := session.admit(newcomer, CombatParticipantResolver.SIDE_ATTACKER)
	check(hud._entries.has(d) and hud._entries.size() == 4, "Später Verbündeter wird ohne Neustart aufgenommen")
	check(session.admit(newcomer, CombatParticipantResolver.SIDE_ATTACKER) == d and hud._entries.size() == 4, "Doppelter Beitritt dupliziert keine Karte")
	var departed_party_entry := hud._entries[b] as CombatOrderEntry
	session.mark_defeated(b)
	await wait_animation()
	check(not is_instance_valid(departed_party_entry) and not party_hud._borrowed.has(follower), "KO gibt auch geliehene Karten frei")
	hud._on_combat_ended(session, {})
	check(hud._session == null and hud._entries.is_empty(), "Kampfende löst aktive Session- und Sortierreferenzen")
	check(party_hud._borrowed.is_empty() and party_hud._entries.size() == 2, "Party erhält Weltkarten einschließlich neuer KO-Karte zurück")
	check(party_hud._world_panels.has(original_leader_card), "Überlebende Weltkarte bleibt dieselbe Instanz")
	await wait_animation()
	check(original_leader_card.scale.is_equal_approx(Vector2.ONE) and not hud.visible and hud._departing.is_empty(), "Rückkehr zur normalen Größe, NPC-Anzeigen bereinigt")
	for p in session.participants:
		if is_instance_valid(p.playable):
			p.playable.exit_combat_mode()
	session.free()
	game.free()
	await get_tree().process_frame
	print("combat_cards: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
