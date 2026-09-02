class_name Dannerman extends Player


func _ready() -> void:
	if character == null:
		character = _SheetFactory.load_sheet("dannerman")
	super._ready()
