class_name Dannerman extends Player


func _ready() -> void:
	if character_sheet == null:
		character_sheet = _SheetFactory.load_sheet("dannerman")
	character_name = "Dannerman"
	super._ready()
