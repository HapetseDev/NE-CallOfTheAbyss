class_name StateIdle extends State

@onready var walk: State = $"../Walk"
@onready var attack: State = $"../Attack"
@onready var action_menu = $"../ActionMenu"

# Was passiert, wenn der State betreten wird?
func Enter() -> void:
	player.UpdateAnimation("idle")
	pass

# Was passiert beim Verlassen des States?
func Exit() -> void:
		pass

# Was passiert beim _process Update?
func Process(_delta: float) -> State:
	if player.direction != Vector3.ZERO:
		return walk
	player.velocity = Vector3.ZERO
	return null

# Was passiert im _physics Prozess in diesem State?
func Physics(_delta: float) -> State:
	return null

# Was passiert mit input Events in diesem State?
func HandleInput(_event: InputEvent) -> State:
	if _event.is_action_pressed("Attack"):
		print("[Idle] Attack-Taste erkannt. action_menu = ", action_menu)
		return action_menu
	return null
