class_name HurtBox extends Area3D

@export var damage : int = 1

func _ready() -> void:
	area_entered.connect(area_entered_handler)

func area_entered_handler(a : Area3D) -> void:
	if a is Hitbox:
		a.take_damage ( damage)
