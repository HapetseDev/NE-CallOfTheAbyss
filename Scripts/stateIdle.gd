class_name StateIdle extends State

@onready var walk: State = $"../Walk"
@onready var action_menu = $"../ActionMenu"

# Was passiert, wenn der State betreten wird?
func enter() -> void:
	player.update_animation("idle")
	pass

# Was passiert beim Verlassen des States?
func exit() -> void:
		pass

# Was passiert beim _process Update?
func process(_delta: float) -> State:
	if player.direction != Vector3.ZERO:
		return walk
	player.stop_horizontal_velocity()
	return null

# Was passiert im _physics Prozess in diesem State?
func physics(_delta: float) -> State:
	return null

# Was passiert mit input Events in diesem State?
func handle_input(_event: InputEvent) -> State:
	if GameDialogueBridge.is_player_input_locked():
		return null
	if _event.is_action_pressed("Interact"):
		return action_menu
	return null
