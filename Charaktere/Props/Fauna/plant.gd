class_name Plant extends Node2D
@onready var h_itbox: Hitbox = $HItbox



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	h_itbox.Damaged.connect( TakeDamage)
	pass

func TakeDamage(_damage : int) -> void:
	queue_free()
	pass
