class_name Shalka extends PartyFollower


func _ready() -> void:
	if character == null:
		character = _SheetFactory.load_sheet("shalka")
	character = GameState.character_registry.register_character("shalka", character)
	if character == null:
		push_error("Charakterregistrierung fehlgeschlagen: shalka")
		queue_free()
		return
	super._ready()
