class_name CombatManager
extends Node

## Kampfsystem unter MainGame/Systems. Kein Autoload. Löst BattleManager ab:
## keine separate Kampfszene, Kämpfe laufen in der normalen Spielwelt (Chrono
## Trigger/Ultima-6-Stil). Wer sich beteiligt, entscheidet ausschließlich
## RelationshipService/CombatParticipantResolver – nicht Party-Zugehörigkeit.

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
	GameState.set_flag("in_combat", true)
	combat_started.emit(active_session)


func _evaluate_bystanders(attacker: Playable, victim: Playable) -> void:
	var candidates := CombatParticipantResolver.scan_candidates(attacker)
	for candidate in candidates:
		if active_session.get_participant(candidate) != null:
			continue
		var side := CombatParticipantResolver.classify(candidate, attacker, victim)
		if side != CombatParticipantResolver.SIDE_NEUTRAL:
			active_session.admit(candidate, side)


func _on_side_wiped(losing_side: StringName, session: CombatSession) -> void:
	if session != active_session:
		return
	active_session = null
	GameState.set_flag("in_combat", false)
	combat_ended.emit(session, {"losing_side": losing_side})
	session.queue_free()
