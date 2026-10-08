class_name SequenceProgram extends RefCounted

## Kompilierte Daten pro Start. Keine Nodes oder Ausführungszustände.
var sequence_id: StringName
var dsl_version: int = 1
var content_version: int = 1
var once: bool = false
var map_id: StringName
var source_path: String = ""
var content_hash: String = ""
var instructions: Array[Dictionary] = []
var diagnostics: Array[Dictionary] = []

func is_valid() -> bool:
	return diagnostics.is_empty()
