class_name Shalka extends PartyFollower


func _ready() -> void:
	if character_sheet == null:
		character_sheet = _SheetFactory.load_sheet("shalka")
	character_name = "Shalka"
	super._ready()
