class_name SequenceCommandRegistry extends RefCounted

## Gemeinsame Quelle für Argumentschema, Hilfe und Ausführung.
## Erweiterungen registrieren ein Schema und einen Handler, keinen Parser-Sonderfall.
var _commands: Dictionary = {}

func _init() -> void:
	register_command(&"wait", {"positional": ["number"], "required": {}, "optional": {}}, _wait)
	register_command(&"set", {"positional": [], "required": {"flag": "string", "value": "bool", "id": "identifier"}, "optional": {}}, _set_flag)
	register_command(&"end", {"positional": [], "required": {}, "optional": {"code": "string"}}, _end)
	register_command(&"abort", {"positional": [], "required": {}, "optional": {"reason": "string"}}, _abort)

func register_command(name: StringName, schema: Dictionary, handler: Callable) -> bool:
	if _commands.has(name) or not handler.is_valid():
		return false
	_commands[name] = {"schema": schema.duplicate(true), "handler": handler}
	return true

func has_command(name: StringName) -> bool:
	return _commands.has(name)

func schema_for(name: StringName) -> Dictionary:
	return _commands[name].schema.duplicate(true) if has_command(name) else {}

func start_command(context: SequenceContext, instruction: Dictionary) -> SequenceHandle:
	if not has_command(instruction.command):
		var failed := SequenceHandle.new()
		failed.finish(&"FAILED", &"SEQ_CAPABILITY_MISSING", "Befehl nicht implementiert: " + String(instruction.command))
		return failed
	return _commands[instruction.command].handler.call(context, instruction)

func _wait(_context: SequenceContext, instruction: Dictionary) -> SequenceHandle:
	var handle := SequenceHandle.new()
	handle.wait_for(float(instruction.positional[0]))
	return handle

func _set_flag(context: SequenceContext, instruction: Dictionary) -> SequenceHandle:
	var handle := SequenceHandle.new()
	var args: Dictionary = instruction.arguments
	if context.applied_effect_ids.has(args.id):
		handle.finish()
		return handle
	if not GameState.apply_effects([{"type": "set_flag", "key": args.flag, "value": args.value}]):
		handle.finish(&"FAILED", &"SEQ_EFFECT_REJECTED", "Weltregel lehnt Flag-Effekt ab.")
		return handle
	context.applied_effect_ids[args.id] = true
	handle.finish()
	return handle

func _end(_context: SequenceContext, instruction: Dictionary) -> SequenceHandle:
	var handle := SequenceHandle.new()
	handle.finish(&"SUCCESS", &"", "", {"sequence_status": &"COMPLETED", "end_code": instruction.arguments.get("code", "completed")})
	return handle

func _abort(_context: SequenceContext, instruction: Dictionary) -> SequenceHandle:
	var handle := SequenceHandle.new()
	handle.finish(&"SUCCESS", &"", "", {"sequence_status": &"ABORTED", "end_code": instruction.arguments.get("reason", "aborted")})
	return handle
