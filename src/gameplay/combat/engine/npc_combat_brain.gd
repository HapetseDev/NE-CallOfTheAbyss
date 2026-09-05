class_name NPCCombatBrain
extends Object

## Einfache Kampf-KI für jeden Teilnehmer ohne eigene Spieler-Steuerung
## (echte NPCs/Gegner ohne CombatTurn-State – alle Partymitglieder haben
## inzwischen eine eigene, siehe PartyFollower). CombatManager ruft
## take_turn() auf, sobald turn_started für einen solchen Teilnehmer feuert.
## Bewusst simpel: wählt das erreichbare Ziel mit der größten Feindseligkeit
## und greift mit dem ersten nutzbaren Gegenstand oder sonst waffenlos
## (Fausthieb) an. Kein Item-/Fähigkeiten-Taktieren, keine Fluchtentscheidung.

const FALLBACK_ABILITY_ID := "fausthieb"


static func take_turn(session: CombatSession, participant: CombatParticipant) -> void:
	if session == null or participant == null or participant.playable == null:
		return
	var target := _choose_target(session, participant)
	if target == null:
		session.end_turn(participant)
		return
	var action := _build_attack_action(participant, target)
	var result := CombatResolver.resolve_action(action)
	session.announce_action(participant, action, result)
	for defeated in result.defeated_targets:
		session.mark_defeated(defeated)
	session.end_turn(participant)


static func _enemy_side_of(participant: CombatParticipant) -> StringName:
	if participant.side == CombatParticipantResolver.SIDE_ATTACKER:
		return CombatParticipantResolver.SIDE_VICTIM
	return CombatParticipantResolver.SIDE_ATTACKER


static func _choose_target(session: CombatSession, participant: CombatParticipant) -> CombatParticipant:
	var enemy_side := _enemy_side_of(participant)
	var best: CombatParticipant = null
	var best_score := -1000
	for candidate in session.participants:
		if candidate.side != enemy_side or candidate.is_out_of_combat():
			continue
		if not CombatLineOfSight.has_clear_line(participant.playable, candidate.playable):
			continue
		var score := -RelationshipService.get_disposition(participant.get_character(), candidate.get_character())
		if score > best_score:
			best_score = score
			best = candidate
	return best


static func _build_attack_action(participant: CombatParticipant, target: CombatParticipant) -> CombatAction:
	var action := CombatAction.new()
	action.actor = participant
	action.targets = [target]
	var weapon := _first_usable_item(participant.playable)
	if not weapon.is_empty():
		action.type = CombatAction.ActionType.ITEM
		action.item = weapon["item"]
		action.item_usage_mode = weapon["mode"]
	else:
		action.type = CombatAction.ActionType.ABILITY
		action.ability = AbilityCatalog.get_definition(FALLBACK_ABILITY_ID)
	return action


static func _first_usable_item(playable: Playable) -> Dictionary:
	for item in playable.get_combat_usable_items():
		if item.usage_modes.is_empty():
			continue
		return {"item": item, "mode": item.usage_modes[0]}
	return {}
