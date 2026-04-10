class_name State extends Node

var player: Playable

func _ready() -> void:
	pass

# Was passiert, wenn der State betreten wird?
func enter() -> void:
		pass

# Was passiert beim Verlassen des States?
func exit() -> void:
		pass

# Was passiert beim _process Update?
func process(_delta: float) -> State:
	return null

# Was passiert im _physics Prozess in diesem State?
func physics(_delta: float) -> State:
	return null

# Was passiert mit input Events in diesem State?
func handle_input(_event: InputEvent) -> State:
	return null
