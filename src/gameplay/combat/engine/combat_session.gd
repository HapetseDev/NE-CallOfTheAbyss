class_name CombatSession
extends Node

## Ein laufender Kampf, in der normalen Spielwelt (kein Szenenwechsel).
## Treibt die Initiative-Uhr: statt fester Rundenreihenfolge sammelt jeder
## Teilnehmer proportional zu seiner Gewandheit ein Energiemeter, bei
## Erreichen der Schwelle kommt er in die Zug-Warteschlange. Ein doppelt so
## flinker Charakter sammelt so zwei Zugberechtigungen an, bevor ein
## langsamer die erste bekommt – löst "schnelle Charaktere kommen mehrfach
## pro Runde dran" ohne starre Rundenzählung.

## "SessionState" statt "State", da "State" bereits die globale Basisklasse
## der Charakter-State-Machine ist (state.gd) – ein gleichnamiges Enum hier
## kollidiert damit beim Typ-Check ("Cannot assign CombatSession.State to
## variable of type State").
enum SessionState { ACTIVE, ENDED }

var participants: Array[CombatParticipant] = []
var turn_queue: Array[CombatParticipant] = []
var state: SessionState = SessionState.ACTIVE

var _active_turn: CombatParticipant = null
var _turned_this_round: Array[CombatParticipant] = []

signal participant_joined(participant: CombatParticipant)
signal participant_left(participant: CombatParticipant)
signal participant_defeated(participant: CombatParticipant)
signal turn_started(participant: CombatParticipant)
signal turn_ended(participant: CombatParticipant)
signal round_completed
## HOOK für spätere Niederlage-Konsequenz-Logik – hier passiert bewusst nichts
## außer der reinen Zustandsänderung (state = ENDED). Siehe Plan, "Offene Punkte".
signal side_wiped(losing_side: StringName)


func _process(delta: float) -> void:
	if state != SessionState.ACTIVE:
		return
	_tick_initiative(delta)
	_advance_turn_queue()


func admit(playable: Playable, side: StringName) -> CombatParticipant:
	var existing := get_participant(playable)
	if existing:
		existing.side = side
		return existing
	var participant := CombatParticipant.new(playable, side)
	participants.append(participant)
	if playable:
		playable.enter_combat_mode(self)
	participant_joined.emit(participant)
	return participant


func remove(participant: CombatParticipant) -> void:
	if not participants.has(participant):
		return
	participants.erase(participant)
	turn_queue.erase(participant)
	_turned_this_round.erase(participant)
	if _active_turn == participant:
		_active_turn = null
	if participant.playable and is_instance_valid(participant.playable):
		participant.playable.exit_combat_mode()
	participant_left.emit(participant)
	_check_side_wipe()


func get_participant(playable: Playable) -> CombatParticipant:
	for participant in participants:
		if participant.playable == playable:
			return participant
	return null


func mark_defeated(participant: CombatParticipant) -> void:
	if participant == null or participant.is_defeated:
		return
	participant.is_defeated = true
	turn_queue.erase(participant)
	if _active_turn == participant:
		_active_turn = null
	participant_defeated.emit(participant)
	_check_side_wipe()


## Vom aktiven Zug (StateCombatTurn/NPCCombatBrain, ab PR6) aufgerufen, wenn
## die Aktion des Teilnehmers abgeschlossen ist – gibt die Zug-Warteschlange frei.
func end_turn(participant: CombatParticipant) -> void:
	if _active_turn != participant:
		return
	_active_turn = null
	turn_ended.emit(participant)
	if not _turned_this_round.has(participant):
		_turned_this_round.append(participant)
	_check_round_completed()


func _tick_initiative(delta: float) -> void:
	for participant in participants:
		if participant.is_defeated or participant == _active_turn or turn_queue.has(participant):
			continue
		var playable := participant.playable
		if playable == null or not is_instance_valid(playable):
			continue
		var speed := playable.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)
		participant.initiative_meter += speed * delta * CombatBalance.INITIATIVE_SPEED_FACTOR
		if participant.initiative_meter >= CombatBalance.INITIATIVE_THRESHOLD:
			participant.initiative_meter -= CombatBalance.INITIATIVE_THRESHOLD
			turn_queue.append(participant)


func _advance_turn_queue() -> void:
	if _active_turn != null or turn_queue.is_empty():
		return
	_active_turn = turn_queue.pop_front()
	turn_started.emit(_active_turn)


func _check_round_completed() -> void:
	var active_count := 0
	for participant in participants:
		if not participant.is_defeated:
			active_count += 1
	if active_count > 0 and _turned_this_round.size() >= active_count:
		_turned_this_round.clear()
		round_completed.emit()


func _check_side_wipe() -> void:
	if state != SessionState.ACTIVE:
		return
	var attacker_alive := false
	var victim_alive := false
	for participant in participants:
		if participant.is_defeated:
			continue
		if participant.side == CombatParticipantResolver.SIDE_ATTACKER:
			attacker_alive = true
		elif participant.side == CombatParticipantResolver.SIDE_VICTIM:
			victim_alive = true
	if not attacker_alive and victim_alive:
		state = SessionState.ENDED
		side_wiped.emit(CombatParticipantResolver.SIDE_ATTACKER)
	elif not victim_alive and attacker_alive:
		state = SessionState.ENDED
		side_wiped.emit(CombatParticipantResolver.SIDE_VICTIM)
