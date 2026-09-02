class_name Shalka extends PartyFollower


func _ready() -> void:
	if character == null:
		character = _SheetFactory.load_sheet("shalka")
	super._ready()
