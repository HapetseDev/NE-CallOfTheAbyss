class_name CombatManager
extends Node

## Kampfsystem unter MainGame/Systems. Kein Autoload. Löst BattleManager ab:
## keine separate Kampfszene, Kämpfe laufen in der normalen Spielwelt (Chrono
## Trigger/Ultima-6-Stil). Wer sich beteiligt, entscheidet primär
## RelationshipService/CombatParticipantResolver; Party-Zugehörigkeit ist der
## Fallback für Kandidaten ohne gepflegte Beziehungsdaten (siehe
## _default_party_side) – eine echte Beziehung kann das weiterhin übersteuern.

static var instance: CombatManager

var active_session: CombatSession = null

signal combat_started(session: CombatSession)
## outcome enthält bisher nur "losing_side" – KEINE Sieg/Niederlage-Konsequenz
## (Game Over, Loot, …) ist hier verdrahtet. Siehe Plan, "Offene Punkte".
signal combat_ended(session: CombatSession, outcome: Dictionary)


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func trigger_attack(attacker: Playable, victim: Playable) -> void:
	if instance == null:
		push_error("CombatManager: MainGame ist nicht aktiv.")
		return
	instance._trigger_attack(attacker, victim)


func is_in_combat() -> bool:
	return active_session != null and is_instance_valid(active_session)


func get_session_for(playable: Playable) -> CombatSession:
	if not is_in_combat():
		return null
	if active_session.get_participant(playable) == null:
		return null
	return active_session


func _trigger_attack(attacker: Playable, victim: Playable) -> void:
	if attacker == null or victim == null or attacker == victim:
		return
	if not is_in_combat():
		_start_session()
	active_session.admit(attacker, CombatParticipantResolver.SIDE_ATTACKER)
	active_session.admit(victim, CombatParticipantResolver.SIDE_VICTIM)
	_evaluate_bystanders(attacker, victim)


func _start_session() -> void:
	active_session = CombatSession.new()
	add_child(active_session)
	active_session.side_wiped.connect(_on_side_wiped.bind(active_session))
	active_session.turn_started.connect(_on_turn_started)
	GameState.set_flag("in_combat", true)
	combat_started.emit(active_session)


## Teilnehmer mit eigenem CombatTurn-State (Player und Party-Follower – jedes
## Partymitglied bekommt eine eigene StateMachine mit CombatWait/CombatTurn,
## siehe PartyFollower._ready) reagieren selbst auf turn_started
## (state_combat_wait.gd). Alle anderen – echte NPCs/Gegner ohne eigene
## CombatTurn-State – bekommen ihren Zug automatisch von NPCCombatBrain
## abgenommen, sonst würde die Initiative-Uhr auf ihrem Zug hängen bleiben.
##
## NPCCombatBrain.take_turn() wird deferred aufgerufen statt direkt hier:
## Löst der KI-Zug den Kampf aus (z.B. Sieg -> side_wiped -> exit_combat_mode
## auf allen Teilnehmern, u.a. Player.StateCombatWait.exit() trennt sich
## dabei selbst von diesem turn_started-Signal), würde das mitten in der
## laufenden Signal-Verteilung passieren und die restlichen, noch nicht
## aufgerufenen Listener mit korrumpierten/fehlenden Argumenten treffen
## (genau das erzeugte "Invalid access ... on a base object of type Nil").
## call_deferred lässt die Emission erst sauber durchlaufen.
func _on_turn_started(participant: CombatParticipant) -> void:
	if participant == null or participant.playable == null:
		return
	if _has_manual_control(participant.playable):
		return
	var session := active_session
	if session == null:
		return
	NPCCombatBrain.take_turn.call_deferred(session, participant)


func _has_manual_control(playable: Playable) -> bool:
	if playable == null:
		return false
	var machine := playable.get_node_or_null("StateMachine") as PlayerStateMachine
	if machine == null:
		return false
	return machine.get_node_or_null("CombatTurn") != null


func _evaluate_bystanders(attacker: Playable, victim: Playable) -> void:
	var candidates := CombatParticipantResolver.scan_candidates(attacker)
	for candidate in candidates:
		if active_session.get_participant(candidate) != null:
			continue
		var side := CombatParticipantResolver.classify(candidate, attacker, victim)
		if side == CombatParticipantResolver.SIDE_NEUTRAL:
			side = _default_party_side(candidate, attacker, victim)
		if side != CombatParticipantResolver.SIDE_NEUTRAL:
			active_session.admit(candidate, side)


## Fällt ein Kandidat mangels Beziehungsdaten auf "neutral", greift die eigene
## Party trotzdem füreinander ein – Party-Zugehörigkeit ist selbst ohne
## gepflegten RelationshipEntry ein starkes "wir gehören zusammen"-Signal.
## Eine tatsächliche Beziehung (siehe classify()) hat weiterhin Vorrang und
## kann ein Mitglied auch gegen die eigene Party stellen.
func _default_party_side(candidate: Playable, attacker: Playable, victim: Playable) -> StringName:
	if _same_party(candidate, attacker):
		return CombatParticipantResolver.SIDE_ATTACKER
	if _same_party(candidate, victim):
		return CombatParticipantResolver.SIDE_VICTIM
	return CombatParticipantResolver.SIDE_NEUTRAL


func _same_party(a: Playable, b: Playable) -> bool:
	var party := _find_party(a)
	return party != null and party.get_all_members().has(b)


func _find_party(playable: Playable) -> Party:
	var node: Node = playable
	while node:
		if node is Party:
			return node as Party
		node = node.get_parent()
	return null


func _on_side_wiped(losing_side: StringName, session: CombatSession) -> void:
	if session != active_session:
		return
	active_session = null
	GameState.set_flag("in_combat", false)
	for participant in session.participants:
		if participant.playable and is_instance_valid(participant.playable):
			participant.playable.exit_combat_mode()
	combat_ended.emit(session, {"losing_side": losing_side})
	session.queue_free()
