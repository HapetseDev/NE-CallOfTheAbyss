class_name NPCCombatBrain
extends Object

## Ein LimboAI-Runner pro tatsächlichem KI-Zug, als Kind der CombatSession.
static func take_turn(session: CombatSession, participant: CombatParticipant) -> void:
	if not is_instance_valid(session) or participant == null or not is_instance_valid(participant.playable):
		return
	if session.state != CombatSession.SessionState.ACTIVE or session.get_active_participant() != participant or participant.is_out_of_combat() or not participant.playable.can_participate_in_combat():
		return
	var name := "NPCCombatTurn_%d" % participant.playable.get_instance_id()
	if session.get_node_or_null(name):
		return
	var profile: Resource = load("res://src/resources/combat/ai/melee_default.tres")
	if participant.playable is NPC and participant.playable.combat_ai_profile:
		profile = participant.playable.combat_ai_profile
	var runner = load("res://src/gameplay/combat/ai/npc_combat_turn.gd").new()
	runner.name = name
	session.add_child(runner)
	runner.start(session, participant, profile)
