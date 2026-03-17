class_name StateWalk extends State

@export var base_speed : float = 1.0
@export var sprint_speed : float = 2.5
@export var acceleration : float = 4.0  # Wie schnell die Geschwindigkeit ansteigt
@export var deceleration : float = 6.0  # Wie schnell die Geschwindigkeit abnimmt

var current_speed : float = 0.0
var is_sprinting : bool = false

@onready var idle: State = $"../Idle"
@onready var attack: State = $"../Attack"
@onready var action_menu = $"../ActionMenu"


func _ready() -> void:
	print("[Walk] _ready: action_menu = ", action_menu)

# Was passiert, wenn der State betreten wird?
func Enter() -> void:
	player.UpdateAnimation("walk")
	current_speed = base_speed
	is_sprinting = false

	# Schrittgeräusche starten
	if player.footstep_player:
		player.footstep_player.start_walking(is_sprinting)
	pass

# Was passiert beim Verlassen des States?
func Exit() -> void:
	is_sprinting = false

	# Schrittgeräusche stoppen
	if player.footstep_player:
		player.footstep_player.stop_walking()
	pass

# Was passiert beim _process Update?
func Process(_delta: float) -> State:
	if player.direction == Vector3.ZERO:
		return idle

	# Sprint-Status prüfen (kontinuierlich, nicht event-basiert)
	var was_sprinting = is_sprinting
	is_sprinting = Input.is_action_pressed("Run")

	# Schrittgeräusche-Sprint-Status aktualisieren
	if is_sprinting != was_sprinting and player.footstep_player:
		player.footstep_player.set_sprinting(is_sprinting)

	# Zielgeschwindigkeit bestimmen
	var target_speed = sprint_speed if is_sprinting else base_speed

	# Sanftes Beschleunigen/Abbremsen
	if current_speed < target_speed:
		current_speed = min(current_speed + acceleration * _delta, target_speed)
	elif current_speed > target_speed:
		current_speed = max(current_speed - deceleration * _delta, target_speed)

	player.velocity = player.direction * current_speed

	if player.SetDirection():
		player.UpdateAnimation("walk")
	return null

# Was passiert im _physics Prozess in diesem State?
func Physics(_delta: float) -> State:
	return null

# Was passiert mit input Events in diesem State?
func HandleInput(_event: InputEvent) -> State:
	if _event.is_action_pressed("Attack"):
		print("[Walk] Attack erkannt. action_menu = ", action_menu)
		return action_menu
	return null
