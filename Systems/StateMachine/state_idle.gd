class_name StateIdle extends State

@onready var walk: State = $"../Walk"
@onready var action_menu: State = $"../ActionMenu"


func enter() -> void:
	player.update_animation("idle")


func process(_delta: float) -> State:
	if player.direction != Vector3.ZERO:
		return walk
	player.stop_horizontal_velocity()
	return null


func handle_input(_event: InputEvent) -> State:
	if GameDialogueBridge.is_player_input_locked():
		return null
	if _event.is_action_pressed("Interact"):
		return action_menu
	return null
