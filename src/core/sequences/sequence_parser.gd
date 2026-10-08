class_name SequenceParser extends RefCounted

const MAX_BYTES := 256 * 1024
const MAX_INSTRUCTIONS := 10000
const MAX_WAIT_SECONDS := 3600.0
const HEADER_SCHEMA := {"positional": ["identifier"], "required": {"version": "integer", "content_version": "integer"}, "optional": {"once": "bool", "map": "identifier"}}
var _identifier := RegEx.new()
var _number := RegEx.new()

func _init() -> void:
	_identifier.compile("^[A-Za-z_][A-Za-z0-9_.-]*$")
	_number.compile("^-?[0-9]+(\\.[0-9]+)?$")

func parse(source: String, path: String, registry: SequenceCommandRegistry, catalog: SequenceCatalog) -> SequenceProgram:
	var program := SequenceProgram.new()
	program.source_path = path
	program.content_hash = source.sha256_text()
	if source.to_utf8_buffer().size() > MAX_BYTES:
		_error(program, 1, 1, &"SEQ_FILE_TOO_LARGE", "Sequence-Datei überschreitet das Größenlimit.")
		return program
	if source.begins_with(String.chr(0xfeff)):
		source = source.substr(1)
	var lines := source.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var header_seen := false
	var terminal_seen := false
	var effect_ids: Dictionary = {}
	for index in lines.size():
		var line_number := index + 1
		var tokens := _lex(lines[index], program, line_number)
		if tokens.is_empty():
			continue
		var name: StringName = StringName(tokens[0].value)
		if tokens[0].kind != "word":
			_error(program, line_number, tokens[0].column, &"SEQ_SYNTAX", "Befehlsname erwartet.")
			continue
		if not header_seen:
			header_seen = true
			if name != &"sequence":
				_error(program, line_number, 1, &"SEQ_HEADER_MISSING", "Erste Anweisung muss ein sequence-Header sein.")
				continue
			var header := _arguments(tokens, HEADER_SCHEMA, program, line_number)
			if header.is_empty():
				continue
			program.sequence_id = StringName(header.positional[0])
			program.dsl_version = header.arguments.version
			program.content_version = header.arguments.content_version
			program.once = header.arguments.get("once", false)
			program.map_id = StringName(header.arguments.get("map", ""))
			if program.dsl_version != 1 or program.content_version < 1:
				_error(program, line_number, 1, &"SEQ_VERSION", "Unterstützt: DSL-Version 1, positive Content-Version.")
			if not program.map_id.is_empty() and not catalog.maps.has(String(program.map_id)):
				_error(program, line_number, 1, &"SEQ_MAP_UNKNOWN", "Nicht registrierte Startkarte: " + String(program.map_id))
			continue
		if name == &"sequence":
			_error(program, line_number, 1, &"SEQ_HEADER_DUPLICATE", "Nur ein Header ist erlaubt.")
			continue
		if not registry.has_command(name):
			_error(program, line_number, tokens[0].column, &"SEQ_CAPABILITY_MISSING", "Befehl noch nicht implementiert: " + String(name))
			continue
		if terminal_seen:
			_error(program, line_number, 1, &"SEQ_UNREACHABLE", "Anweisung nach end/abort ist im MVP nicht erreichbar.")
			continue
		var parsed := _arguments(tokens, registry.schema_for(name), program, line_number)
		if parsed.is_empty():
			continue
		var args: Dictionary = parsed.arguments
		if name == &"wait" and (float(parsed.positional[0]) < 0.0 or float(parsed.positional[0]) > MAX_WAIT_SECONDS):
			_error(program, line_number, 1, &"SEQ_DURATION", "Wartezeit muss zwischen 0 und 3600 Sekunden liegen.")
		if name == &"set":
			if not catalog.flags.has(args.flag) or String(args.flag).begins_with("sequence_completed."):
				_error(program, line_number, 1, &"SEQ_FLAG_UNKNOWN", "Nicht registrierter oder reservierter Flag: " + String(args.flag))
			if effect_ids.has(args.id):
				_error(program, line_number, 1, &"SEQ_EFFECT_ID_DUPLICATE", "Effekt-ID doppelt: " + String(args.id))
			effect_ids[args.id] = true
		program.instructions.append({"command": name, "arguments": args, "positional": parsed.positional, "line": line_number, "column": tokens[0].column})
		terminal_seen = name == &"end" or name == &"abort"
	if not header_seen:
		_error(program, 1, 1, &"SEQ_HEADER_MISSING", "Sequence-Header fehlt.")
	if not terminal_seen:
		_error(program, lines.size(), 1, &"SEQ_END_MISSING", "Explizites end oder abort fehlt.")
	if program.instructions.size() > MAX_INSTRUCTIONS:
		_error(program, 1, 1, &"SEQ_INSTRUCTION_LIMIT", "Zu viele Anweisungen.")
	return program

func _lex(line: String, program: SequenceProgram, line_number: int) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	var i := 0
	while i < line.length():
		var ch := line.substr(i, 1)
		if ch == " " or ch == "\t":
			i += 1
			continue
		if ch == "#":
			break
		var column := i + 1
		if ch == "=":
			tokens.append({"kind": "equals", "value": "=", "column": column})
			i += 1
			continue
		if ch == "\"":
			i += 1
			var value := ""
			var closed := false
			while i < line.length():
				ch = line.substr(i, 1)
				i += 1
				if ch == "\"":
					closed = true
					break
				if ch == "\\":
					if i >= line.length():
						break
					var escaped := line.substr(i, 1)
					i += 1
					match escaped:
						"n": value += "\n"
						"t": value += "\t"
						"\\", "\"": value += escaped
						_:
							_error(program, line_number, i, &"SEQ_ESCAPE", "Unbekannte Escape-Sequenz.")
							return []
				else:
					value += ch
			if not closed:
				_error(program, line_number, column, &"SEQ_STRING", "String nicht geschlossen.")
				return []
			if i < line.length() and not line.substr(i, 1) in [" ", "\t", "#", "="]:
				_error(program, line_number, i + 1, &"SEQ_SYNTAX", "Trennzeichen nach String erwartet.")
				return []
			tokens.append({"kind": "string", "value": value, "column": column})
			continue
		var start := i
		while i < line.length() and not line.substr(i, 1) in [" ", "\t", "#", "=", "\""]:
			i += 1
		tokens.append({"kind": "word", "value": line.substr(start, i - start), "column": column})
	return tokens

func _arguments(tokens: Array[Dictionary], schema: Dictionary, program: SequenceProgram, line_number: int) -> Dictionary:
	var positional: Array = []
	var args: Dictionary = {}
	var i := 1
	var named_seen := false
	var errors_before := program.diagnostics.size()
	while i < tokens.size():
		var token: Dictionary = tokens[i]
		if i + 1 < tokens.size() and tokens[i + 1].kind == "equals":
			named_seen = true
			var key: String = token.value
			if token.kind != "word" or i + 2 >= tokens.size() or tokens[i + 2].kind == "equals":
				_error(program, line_number, token.column, &"SEQ_ARGUMENT", "Benannter Parameter erwartet key=value.")
				break
			if args.has(key):
				_error(program, line_number, token.column, &"SEQ_ARGUMENT_DUPLICATE", "Parameter doppelt: " + key)
			var type: String = schema.required.get(key, schema.optional.get(key, ""))
			if type.is_empty():
				_error(program, line_number, token.column, &"SEQ_ARGUMENT_UNKNOWN", "Unbekannter Parameter: " + key)
			else:
				args[key] = _value(tokens[i + 2], type, program, line_number)
			i += 3
		else:
			if named_seen or positional.size() >= schema.positional.size() or token.kind == "equals":
				_error(program, line_number, token.column, &"SEQ_ARGUMENT", "Unerwarteter Positionsparameter.")
			else:
				positional.append(_value(token, schema.positional[positional.size()], program, line_number))
			i += 1
	if positional.size() != schema.positional.size():
		_error(program, line_number, 1, &"SEQ_ARGUMENT_REQUIRED", "Positionsparameter fehlt.")
	for key in schema.required:
		if not args.has(key):
			_error(program, line_number, 1, &"SEQ_ARGUMENT_REQUIRED", "Pflichtparameter fehlt: " + key)
	return {"positional": positional, "arguments": args} if errors_before == program.diagnostics.size() else {}

func _value(token: Dictionary, type: String, program: SequenceProgram, line_number: int) -> Variant:
	var value: String = token.value
	match type:
		"string":
			if token.kind == "string": return value
		"identifier":
			if token.kind == "word" and _identifier.search(value) != null: return value
		"bool":
			if token.kind == "word" and value in ["true", "false"]: return value == "true"
		"integer":
			if token.kind == "word" and value.is_valid_int() and value.length() <= 9: return int(value)
		"number":
			if token.kind == "word" and _number.search(value) != null and is_finite(float(value)): return float(value)
	_error(program, line_number, token.column, &"SEQ_TYPE", "Erwarteter Typ: " + type)
	return null

func _error(program: SequenceProgram, line: int, column: int, code: StringName, message: String) -> void:
	program.diagnostics.append({"severity": &"ERROR", "code": code, "path": program.source_path, "line": line, "column": column, "message": message})
