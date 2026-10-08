class_name SequenceCatalog extends Resource

## Nur ausdrücklich registrierte Inhalte dürfen gestartet/verändert werden.
@export var sequences: Dictionary = {}
@export var maps: Dictionary = {}
@export var flags: PackedStringArray = []

func completion_flag(sequence_id: StringName) -> String:
	return "sequence_completed." + String(sequence_id)
