extends Node

const PLANNER := preload("res://src/gameplay/combat/ai/combat_ai_planner.gd")
const GRID := preload("res://src/world/combat/combat_grid.gd")
var session: CombatSession
var participant: CombatParticipant
var profile: Resource
var plan: Dictionary = {}
var _tree: RefCounted
var _done := false
var _executing := false
var _cancel_requested := false
var _started_move := false
var _move_done := false
var _move_success := false
var _attacked := false
var _elapsed := 0.0
var _timeout := 0.0

func start(combat: CombatSession, actor: CombatParticipant, behavior: Resource) -> void:
	session = combat
	participant = actor
	profile = behavior
	session.turn_ended.connect(_on_turn_ended)
	session.participant_fled.connect(_on_lost)
	session.participant_defeated.connect(_on_lost)
	participant.playable.tree_exiting.connect(_on_actor_removed)
	if profile == null or profile.behavior_tree == null:
		_finish()
		return
	var blackboard = ClassDB.instantiate("Blackboard")
	_tree = profile.behavior_tree.instantiate(self, blackboard, self, session)
	if _tree == null:
		_finish()

func _valid() -> bool:
	return not _done and is_instance_valid(session) and session.state == CombatSession.SessionState.ACTIVE and session.get_active_participant() == participant and not participant.is_out_of_combat() and is_instance_valid(participant.playable) and participant.playable.can_participate_in_combat()

func _process(delta: float) -> void:
	if not _valid():
		_finish()
		return
	_executing = true
	var status: int = _tree.update(delta)
	_executing = false
	if _cancel_requested or status != BTTask.RUNNING:
		_finish()

func plan_turn() -> bool:
	if not _valid():
		return false
	PLANNER.update_observations(session, participant, profile)
	plan = PLANNER.choose(session, participant, profile)
	participant.ai_reposition_cooldown = maxi(0, participant.ai_reposition_cooldown - 1)
	return not plan.is_empty()

func execute_plan(delta: float) -> int:
	if not _valid() or plan.is_empty():
		return BTTask.FAILURE
	var target := plan.target as CombatParticipant
	if not is_instance_valid(target.playable) or target.is_out_of_combat():
		return BTTask.FAILURE
	if plan.kind == "attack":
		if _attacked:
			return BTTask.SUCCESS
		# Keine veraltete Waffe, Position, Reichweite oder Angriffslinie verwenden.
		var enemies := PLANNER.perceived_enemies(session, participant, profile)
		if not enemies.has(target):
			return BTTask.FAILURE
		var fresh := PLANNER.best_attack(participant, [target], PLANNER.attack_options(participant), profile, participant.playable.global_position)
		if fresh.is_empty():
			return BTTask.FAILURE
		_attacked = true
		var action := fresh.action as CombatAction
		var result := CombatResolver.resolve_action(action)
		session.announce_action(participant, action, result)
		for defeated in result.defeated_targets:
			session.mark_defeated(defeated)
		return BTTask.SUCCESS if result.success else BTTask.FAILURE
	if not _started_move:
		_started_move = true
		# Dieselben Felder erneut prüfen, falls sich eine Belegung geändert hat.
		var path := GRID.find_path(participant.playable, session, plan.path[-1], float(plan.radius))
		if path.size() < 2:
			return BTTask.FAILURE
		var length := 0.0
		for index in path.size():
			if Vector2(path[index].x - plan.origin.x, path[index].z - plan.origin.z).length() > float(plan.radius) + 0.01:
				return BTTask.FAILURE
			if index > 0:
				length += path[index - 1].distance_to(path[index])
		_timeout = length / CombatBalance.COMBAT_MOVE_SPEED + 3.0
		if not participant.playable.begin_combat_path(get_instance_id(), path, CombatBalance.COMBAT_MOVE_SPEED, _on_arrived):
			return BTTask.FAILURE
		if plan.get("tactical", false):
			participant.ai_reposition_cooldown = maxi(1, profile.reposition_cooldown_turns)
	_elapsed += delta
	if _elapsed > _timeout:
		return BTTask.FAILURE
	if not _move_done:
		return BTTask.RUNNING
	var action := CombatAction.new()
	action.actor = participant
	action.type = CombatAction.ActionType.MOVE
	action.move_target_position = participant.playable.global_position
	var result := CombatResolver.resolve_action(action)
	if not _move_success:
		GRID.place(participant.playable, session)
		result.success = false
		result.failed_reason = "movement_blocked"
	session.announce_action(participant, action, result)
	return BTTask.SUCCESS if result.success else BTTask.FAILURE

func _on_arrived(success: bool) -> void:
	_move_done = true
	_move_success = success

func _on_lost(actor: CombatParticipant) -> void:
	if actor == participant or plan.get("target") == actor:
		_cancel_requested = true
		if not _executing:
			_finish()

func _on_turn_ended(actor: CombatParticipant) -> void:
	if actor == participant:
		_finish()

func _on_actor_removed() -> void:
	_finish()

func _cleanup() -> void:
	if is_instance_valid(participant.playable):
		participant.playable.cancel_combat_path(get_instance_id())
		if participant.playable.tree_exiting.is_connected(_on_actor_removed):
			participant.playable.tree_exiting.disconnect(_on_actor_removed)
	if is_instance_valid(session):
		for event in [session.turn_ended, session.participant_fled, session.participant_defeated]:
			var callback := _on_turn_ended if event == session.turn_ended else _on_lost
			if event.is_connected(callback):
				event.disconnect(callback)
	if _tree:
		_tree.get_root_task().abort()
	_tree = null
	plan.clear()

func _finish() -> void:
	if _done:
		return
	_done = true
	_cleanup()
	if is_instance_valid(session) and session.state == CombatSession.SessionState.ACTIVE and session.get_active_participant() == participant:
		session.end_turn(participant)
	queue_free()

func _exit_tree() -> void:
	if not _done:
		_done = true
		_cleanup()
