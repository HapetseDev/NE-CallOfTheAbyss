class_name Hitbox extends Area3D

signal damaged( damage : int)

func take_damage ( damage : int ) -> void:
	damaged.emit( damage )
