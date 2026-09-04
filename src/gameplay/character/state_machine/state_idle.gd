class_name StateIdle extends State

@onready var walk: State = $"../Walk"
@onready var action_menu: State = $"../ActionMenu"
@onready var party_skills: State = $"../PartySkills"


func enter() -> void:
	player.update_animation("idle")


func process(_delta: float) -> State:
	if not player.is_on_floor():
		_update_airborne_animation()
		if player.direction != Vector3.ZERO:
			return walk
		player.stop_horizontal_velocity()
		return null
	if player.direction != Vector3.ZERO:
		return walk
	player.stop_horizontal_velocity()
	return null


func handle_input(_event: InputEvent) -> State:
	if GameState.is_player_input_locked():
		return null
	if _try_jump_from_input(_event):
		return null
	if _event.is_action_pressed("Interact"):
		return action_menu
	if _event.is_action_pressed("Faehigkeiten"):
		return party_skills
	return null
