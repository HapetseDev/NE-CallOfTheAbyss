class_name StateWalk extends State

@export var base_speed : float = 1.0
@export var sprint_speed : float = 2.5
@export var acceleration : float = 4.0  # Wie schnell die Geschwindigkeit ansteigt
@export var deceleration : float = 6.0  # Wie schnell die Geschwindigkeit abnimmt

var current_speed : float = 0.0
var is_sprinting : bool = false

@onready var idle: State = $"../Idle"
@onready var action_menu = $"../ActionMenu"


# Was passiert, wenn der State betreten wird?
func enter() -> void:
	_update_locomotion_animation()
	current_speed = base_speed
	is_sprinting = false

	# Schrittgeräusche starten
	if player.footstep_player:
		player.footstep_player.start_walking(is_sprinting)
	pass

# Was passiert beim Verlassen des States?
func exit() -> void:
	is_sprinting = false

	# Schrittgeräusche stoppen
	if player.footstep_player:
		player.footstep_player.stop_walking()
	pass

# Was passiert beim _process Update?
func process(_delta: float) -> State:
	if player.direction == Vector3.ZERO:
		return idle

	var target_speed: float
	var was_sprinting := is_sprinting

	if player is Player and (player as Player).uses_mouse_locomotion():
		target_speed = (player as Player).get_mouse_locomotion_speed()
		var mid := (base_speed + sprint_speed) * 0.5
		is_sprinting = target_speed >= mid
	else:
		is_sprinting = Input.is_action_pressed("Run")
		target_speed = sprint_speed if is_sprinting else base_speed

	if is_sprinting != was_sprinting:
		if player.footstep_player:
			player.footstep_player.set_sprinting(is_sprinting)
		_update_locomotion_animation()

	if current_speed < target_speed:
		current_speed = min(current_speed + acceleration * _delta, target_speed)
	elif current_speed > target_speed:
		current_speed = max(current_speed - deceleration * _delta, target_speed)

	player.set_horizontal_velocity(player.direction * current_speed)

	if player.set_direction():
		_update_locomotion_animation()
	return null


func _update_locomotion_animation() -> void:
	player.update_animation("run" if is_sprinting else "walk")

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
