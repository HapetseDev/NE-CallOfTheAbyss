class_name SequenceRunner extends Node

signal finished(result: Dictionary)
const INSTRUCTIONS_PER_FRAME := 100

var context: SequenceContext
var _instructions: Array[Dictionary] = []
var _registry: SequenceCommandRegistry
var _path: String = ""
var _handle: SequenceHandle
var _terminal := false
var _configured := false

func configure(program: SequenceProgram, registry: SequenceCommandRegistry, run_context: SequenceContext) -> void:
	context = run_context
	_registry = registry
	_path = program.source_path
	_instructions = program.instructions.duplicate(true)
	_configured = true

func _process(delta: float) -> void:
	if not _configured or _terminal or context.paused:
		return
	if _handle != null:
		_handle.tick(delta)
	for _step in INSTRUCTIONS_PER_FRAME:
		if _terminal:
			return
		if _handle != null:
			if not _handle.is_terminal():
				return
			var result := _handle.get_result()
			_handle = null
			if result.status != &"SUCCESS":
				_finish(&"FAILED", result.error_code, result.message)
				return
			if result.data.has("sequence_status"):
				_finish(result.data.sequence_status, &"", "", result.data.end_code)
				return
			context.instruction_pointer += 1
		if context.instruction_pointer >= _instructions.size():
			_finish(&"FAILED", &"SEQ_END_MISSING", "Sequence endet ohne Abschluss.")
			return
		_handle = _registry.start_command(context, _instructions[context.instruction_pointer])
		if _handle == null:
			_finish(&"FAILED", &"SEQ_HANDLE_MISSING", "Befehl liefert keinen Handle.")
			return
		# Auch bei wait 0 mindestens einen neuen Frame abwarten.
		if not _handle.is_terminal():
			return

func cancel(reason: StringName = &"cancelled") -> void:
	if _terminal:
		return
	if _handle != null:
		_handle.cancel(reason)
	_finish(&"ABORTED", reason, "Sequence abgebrochen.")

func set_paused(value: bool) -> void:
	if context != null:
		context.paused = value

func _finish(status: StringName, code: StringName, message: String, end_code: String = "") -> void:
	if _terminal:
		return
	_terminal = true
	set_process(false)
	var diagnostic: Dictionary = {}
	if status == &"FAILED":
		var instruction: Dictionary = _instructions[mini(context.instruction_pointer, _instructions.size() - 1)] if not _instructions.is_empty() else {}
		diagnostic = {"severity": &"ERROR", "code": code, "path": _path, "line": instruction.get("line", 1), "column": instruction.get("column", 1), "message": message, "run_id": context.run_id}
	finished.emit({"run_id": context.run_id, "sequence_id": context.sequence_id, "status": status, "end_code": end_code, "error_code": code, "message": message, "diagnostic": diagnostic})
