class_name StateInventory extends State

@onready var _idle: State = $"../Idle"


func enter() -> void:
	if player is Player:
		(player as Player).clear_click_move()
	player.stop_horizontal_velocity()
	if player is Player:
		(player as Player).open_inventory()


func exit() -> void:
	if player is Player:
		(player as Player).close_inventory()


func process(_delta: float) -> State:
	player.stop_horizontal_velocity()
	return null


func handle_input(event: InputEvent) -> State:
	if event.is_action_pressed("Inventar") or event.is_action_pressed("ui_cancel"):
		return _idle
	return null
