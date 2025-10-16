class_name State extends Node

static var player: Player 

func _ready() -> void:
	pass

# Was passiert, wenn der State betreten wird?
func Enter() -> void:
		pass

# Was passiert beim Verlassen des States?
func Exit() -> void:
		pass
		
# Was passiert beim _process Update?
func Process(_delta: float) -> State:
	return null
	
# Was passiert im _physics Prozess in diesem State?
func Physics(_delta: float) -> State:
	return null
	
# Was passiert mit input Events in diesem State?
func HandleInput(_event: InputEvent) -> State:
	return null
