class_name Player extends Playable

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hurt_box: HurtBox = %AttackHurtBox


func _ready() -> void:
	footstep_player = $FootstepPlayer as FootstepPlayer
	state_machine.initialize(self)
	super._ready()


# Spielereingabe als Bewegungsrichtung
func get_move_direction() -> Vector3:
	return Vector3(
		Input.get_axis("Left", "Right"),
		0,
		Input.get_axis("Up", "Down")
	).normalized()
