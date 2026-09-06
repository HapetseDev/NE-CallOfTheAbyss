class_name PartyFollower extends Playable

@export var follow_distance: float = 1.35
@export var follow_speed: float = 1.65
@export var arrive_distance_sq: float = 0.14

var leader: Playable
var _was_moving: bool = false
var _follow_enabled: bool = true


func set_leader(p: Playable) -> void:
	leader = p


func _ready() -> void:
	add_to_group("interactable")
	footstep_player = get_node_or_null("FootstepPlayer") as FootstepPlayer
	var state_machine := get_node_or_null("StateMachine") as PlayerStateMachine
	if state_machine:
		# Initialisiert den State-Graph korrekt (current_state = Idle, player-Referenz
		# gesetzt), läuft aber außerhalb des Kampfes nicht automatisch – Follower
		# reagieren sonst auf globale Inputs (Interact/Jump), die nur dem Leader
		# gelten. enter_combat_mode()/exit_combat_mode() schalten process_mode
		# gezielt während der eigenen Kampfteilnahme ein/aus.
		state_machine.initialize(self)
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	super._ready()


func get_move_direction() -> Vector3:
	return Vector3.ZERO


func enter_combat_mode(session: CombatSession) -> void:
	set_follow_enabled(false)
	super.enter_combat_mode(session)


func exit_combat_mode() -> void:
	super.exit_combat_mode()
	var state_machine := get_node_or_null("StateMachine") as PlayerStateMachine
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	set_follow_enabled(true)


## Während aktiver Kampfteilnahme (nicht nur im eigenen Zug) soll ein Follower
## dem Leader nicht hinterherlaufen – sonst würde er sich mitten im Kampf
## umherbewegen, während Initiative-Uhr/Kampfmenü über ihn entscheiden.
func set_follow_enabled(enabled: bool) -> void:
	_follow_enabled = enabled
	if not enabled:
		_stop_follow_motion()


func _physics_process(delta: float) -> void:
	_update_follow(delta)
	super._physics_process(delta)


func _update_follow(_delta: float) -> void:
	if not _follow_enabled:
		return
	if leader == null or not is_instance_valid(leader):
		_stop_follow_motion()
		return

	var target_pos := _get_follow_target_position()
	var to := target_pos - global_position
	to.y = 0.0
	var moving := to.length_squared() > arrive_distance_sq

	if moving:
		direction = to.normalized()
		set_direction()
		set_horizontal_velocity(direction * follow_speed)
		update_animation("walk")
		if footstep_player and not _was_moving:
			footstep_player.start_walking(false)
	else:
		direction = Vector3.ZERO
		stop_horizontal_velocity()
		update_animation("idle")
		if footstep_player and _was_moving:
			footstep_player.stop_walking()

	_was_moving = moving


func _stop_follow_motion() -> void:
	direction = Vector3.ZERO
	stop_horizontal_velocity()
	if footstep_player and _was_moving:
		footstep_player.stop_walking()
	_was_moving = false


func _get_follow_target_position() -> Vector3:
	var back := Vector3(-leader.facing_direction.x, 0.0, -leader.facing_direction.z)
	if back.length_squared() < 0.01:
		back = Vector3(0.0, 0.0, 1.0)
	return leader.global_position + back.normalized() * follow_distance


# --- E-Menü-Interaktion (state_action_menu.gd, "interactable"-Gruppe) ---
# Direkt auf dem Follower selbst statt über eine eigene Interaction-Node
# (wie bei NPCs) - der Follower ist bereits sein eigener Node3D-Wurzelknoten,
# eine zusätzliche Ebene wäre hier nur Overhead.

func get_actions(_player: Playable) -> Array[Dictionary]:
	return [{"label": "Tauschen", "action_id": "trade_party"}]


func perform_action(action_id: String, player: Playable) -> void:
	if action_id == "trade_party":
		PartyTradeManager.open(player, self)
