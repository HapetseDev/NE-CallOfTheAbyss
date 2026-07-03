class_name Dannerman extends Player


func _ready() -> void:
	if character_sheet == null:
		character_sheet = load("res://Ressources/Character/sheets/dannerman.tres") as CharacterSheet
	character_name = "Dannerman"
	super._ready()
