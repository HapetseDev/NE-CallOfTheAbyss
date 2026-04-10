class_name NPC extends Playable

@onready var state_machine: PlayerStateMachine = get_node_or_null("StateMachine") as PlayerStateMachine

# Zielposition für KI-Bewegung
var _target_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	if state_machine:
		state_machine.initialize(self)
	super._ready()


# Wird von KI-Logik / States gesetzt, nicht von Input
func get_move_direction() -> Vector3:
	return _target_direction


func set_target_direction(dir: Vector3) -> void:
	_target_direction = dir.normalized()
