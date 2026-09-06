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
signal participant_fled(participant: CombatParticipant)
signal participant_defeated(participant: CombatParticipant)
signal turn_started(participant: CombatParticipant)
signal turn_ended(participant: CombatParticipant)
signal round_completed
## HOOK für spätere Niederlage-Konsequenz-Logik – hier passiert bewusst nichts
## außer der reinen Zustandsänderung (state = ENDED). Siehe Plan, "Offene Punkte".
signal side_wiped(losing_side: StringName)
## Für Aktions-Feedback-HUDs (siehe CombatNarrator/EventLogHud). action kann
## null sein (z.B. Reden/Fliehen, die nicht über CombatResolver laufen).
signal action_resolved(actor: CombatParticipant, action: CombatAction, result: CombatActionResult)


func _process(delta: float) -> void:
	if state != SessionState.ACTIVE:
		return
	_tick_initiative(delta)
	_advance_turn_queue()


## Erneutes admit() eines bereits Geflohenen (z.B. wieder angegriffen) holt
## ihn zurück in den Kampf – has_fled wird zurückgesetzt, sonst bekäme er nie
## wieder eigene Züge.
func admit(playable: Playable, side: StringName) -> CombatParticipant:
	var existing := get_participant(playable)
	if existing:
		existing.side = side
		existing.has_fled = false
		return existing
	var participant := CombatParticipant.new(playable, side)
	participants.append(participant)
	if playable:
		playable.enter_combat_mode(self)
	participant_joined.emit(participant)
	return participant


## Erfolgreiche Flucht (state_combat_turn.gd). Bewusst wie mark_defeated() –
## der Teilnehmer bleibt in participants (kein Ziel mehr, keine Züge mehr,
## siehe CombatParticipant.is_out_of_combat()), bis die eigene Seite komplett
## raus ist (besiegt/geflohen) und die Session per side_wiped endet. Erst dann
## ruft CombatManager._on_side_wiped() exit_combat_mode() für alle Teilnehmer
## dieser Seite auf – ein einzeln geflohener Party-Leader bekommt seine freie
## Steuerung also nicht schon beim eigenen Fluchtversuch zurück, sondern erst
## wenn auch der Rest der Party raus ist.
func mark_fled(participant: CombatParticipant) -> void:
	if participant == null or participant.is_out_of_combat():
		return
	participant.has_fled = true
	turn_queue.erase(participant)
	if _active_turn == participant:
		_active_turn = null
	participant_fled.emit(participant)
	_check_side_wipe()


## Wer gerade am Zug ist, oder null zwischen zwei Zügen. Für HUDs (z.B.
## Kampfreihenfolge) – _active_turn bleibt intern gesetzt.
func get_active_participant() -> CombatParticipant:
	return _active_turn


## Zentraler Aufrufpunkt fürs Aktions-Feedback: von state_combat_turn.gd und
## npc_combat_brain.gd nach CombatResolver.resolve_action() aufgerufen (result
## kann für COMMUNICATE/FLEE auch direkt mit einem eigenen Text statt einem
## echten CombatActionResult kombiniert werden, siehe CombatNarrator). Speist
## zusätzlich das projektweite EventLog (EventLogHud), damit Kampfzeilen im
## selben Log wie Item-Pickups/Dialog erscheinen.
func announce_action(actor: CombatParticipant, action: CombatAction, result: CombatActionResult) -> void:
	action_resolved.emit(actor, action, result)
	EventLog.add_lines(CombatNarrator.describe(actor, action, result))


func get_participant(playable: Playable) -> CombatParticipant:
	for participant in participants:
		if participant.playable == playable:
			return participant
	return null


func mark_defeated(participant: CombatParticipant) -> void:
	if participant == null or participant.is_out_of_combat():
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
		if participant.is_out_of_combat() or participant == _active_turn or turn_queue.has(participant):
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
	var next: CombatParticipant = turn_queue.pop_front()
	if next == null:
		return
	_active_turn = next
	turn_started.emit(_active_turn)


func _check_round_completed() -> void:
	var active_count := 0
	for participant in participants:
		if not participant.is_out_of_combat():
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
		if participant.is_out_of_combat():
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
