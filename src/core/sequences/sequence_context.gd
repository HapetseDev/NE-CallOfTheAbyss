class_name SequenceContext extends RefCounted

## Laufzeitdaten, noch kein Save-/Resumevertrag.
var run_id: String = ""
var sequence_id: StringName
var instruction_pointer: int = 0
var applied_effect_ids: Dictionary = {}
var paused: bool = false

func _init(id: StringName = &"") -> void:
	sequence_id = id
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
