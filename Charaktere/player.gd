class_name Player extends CharacterBody3D

var cardinal_direction : Vector3 = Vector3(0, 0, 1)  # DOWN in 3D (positive Z)
var direction : Vector3 = Vector3.ZERO
const DIR_4 = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]  # RIGHT, DOWN, LEFT, UP


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hurt_box: HurtBox = %AttackHurtBox
@onready var footstep_player: FootstepPlayer = $FootstepPlayer

signal DirectionChanged (newDirection : Vector3)

func _ready():
	state_machine.Initialize(self)
	pass

func _process ( _delta):

	direction = Vector3(
		Input.get_axis("Left", "Right"),
		0,
		Input.get_axis("Up", "Down")
	).normalized()
	pass

func _physics_process(_delta: float):
	move_and_slide()

func SetDirection() -> bool:
	if direction == Vector3.ZERO:
		return false

	# Calculate angle in X-Z plane
	var dir_2d = Vector2(direction.x, direction.z)
	var cardinal_2d = Vector2(cardinal_direction.x, cardinal_direction.z)
	var direction_id : int = int(round((dir_2d + cardinal_2d * 0.1).angle() / TAU * DIR_4.size()))
	var new_dir = DIR_4[direction_id]

	if new_dir == cardinal_direction:
		return false
	cardinal_direction = new_dir
	DirectionChanged.emit(new_dir)
	$Sprite3D.flip_h = true if cardinal_direction == Vector3(-1, 0, 0) else false
	return true

func UpdateAnimation(state) -> void:
	animation_player.play(state + "_" + AnimDirection())
	pass

func AnimDirection() -> String:
	if cardinal_direction == Vector3(0, 0, 1):  # DOWN
		return "down"
	elif cardinal_direction == Vector3(0, 0, -1):  # UP
		return "up"
	else:
		return "side"
