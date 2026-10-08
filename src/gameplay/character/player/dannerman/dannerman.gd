class_name Dannerman extends Player


func _ready() -> void:
	if character == null:
		character = _SheetFactory.load_sheet("dannerman")
	character = GameState.character_registry.register_character("dannerman", character)
	if character == null:
		push_error("Charakterregistrierung fehlgeschlagen: dannerman")
		queue_free()
		return
	super._ready()
