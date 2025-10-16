class_name StateWalk extends State

@export var move_speed : float = 100.0
@onready var idle: State = $"../Idle"
@onready var attack: State = $"../Attack"


# Was passiert, wenn der State betreten wird?
func Enter() -> void:
	player.UpdateAnimation("walk")
	pass

# Was passiert beim Verlassen des States?
func Exit() -> void:
		pass
		
# Was passiert beim _process Update?
func Process(_delta: float) -> State:
	if player.direction == Vector2.ZERO:
		return idle
		
	player.velocity = player.direction * move_speed
	
	if player.SetDirection():
		player.UpdateAnimation("walk")
	return null

# Was passiert im _physics Prozess in diesem State?
func Physics(_delta: float) -> State:
	return null
	
# Was passiert mit input Events in diesem State?
func HandleInput(_event: InputEvent) -> State:
	if _event.is_action_pressed("Run"):
		move_speed = 200
	if _event.is_released():
		move_speed = 100
	if _event.is_action_pressed("Attack"):
		return attack
	return null
