class_name SequenceManager extends Node

signal sequence_started(run_id: String, sequence_id: StringName)
signal sequence_finished(run_id: String, result: Dictionary)
signal sequence_failed(run_id: String, diagnostic: Dictionary)

@export var catalog: SequenceCatalog = preload("res://src/resources/sequences/sequence_catalog.tres")
var command_registry := SequenceCommandRegistry.new()
var last_result: Dictionary = {}
var _runner: SequenceRunner
var _lease: int = 0
var _exiting := false

func _enter_tree() -> void:
	_exiting = false

func start(sequence_id: StringName, _bindings: Dictionary = {}, _trigger_id: StringName = &"") -> Dictionary:
	if is_running():
		return _rejected(&"BUSY", "Eine Sequence läuft bereits.")
	if _exiting or not is_inside_tree() or MainGame.instance == null or not MainGame.instance.is_node_ready() or get_parent() != MainGame.instance.get_node("Systems"):
		return _rejected(&"UNAVAILABLE", "Spielwelt ist nicht bereit.")
	if MainGame.instance.level_manager.current_level == null or MainGame.instance.party == null or MainGame.instance.party.leader == null:
		return _rejected(&"UNAVAILABLE", "Level oder Party ist nicht bereit.")
	if get_tree().paused or GameState.is_player_input_locked() or (CombatManager.instance != null and CombatManager.instance.is_in_combat()):
		return _rejected(&"BUSY", "Kampf, Pause oder eine andere Interaktion ist aktiv.")
	if not _bindings.is_empty():
		return _rejected(&"SEQ_CAPABILITY_MISSING", "Actor-Bindings werden erst in Phase 2 unterstützt.")
	if catalog == null or not catalog.sequences.has(String(sequence_id)):
		return _rejected(&"SEQ_NOT_FOUND", "Sequence ist nicht registriert: " + String(sequence_id))
	var path: String = catalog.sequences[String(sequence_id)]
	if not path.begins_with("res://src/resources/sequences/") or not path.ends_with(".sequence"):
		return _rejected(&"SEQ_PATH", "Ungültiger Catalogpfad.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _rejected(&"SEQ_FILE", "Sequence-Datei nicht lesbar: " + path)
	if file.get_length() > SequenceParser.MAX_BYTES:
		return _rejected(&"SEQ_FILE_TOO_LARGE", "Sequence-Datei überschreitet das Größenlimit.")
	var program := SequenceParser.new().parse(file.get_as_text(), path, command_registry, catalog)
	if not program.is_valid():
		var diagnostic: Dictionary = program.diagnostics[0]
		var rejected := _rejected(diagnostic.code, diagnostic.message)
		rejected.diagnostics = program.diagnostics.duplicate(true)
		return rejected
	if program.sequence_id != sequence_id:
		return _rejected(&"SEQ_ID_MISMATCH", "Catalog-ID und Sequence-Header stimmen nicht überein.")
	if not program.map_id.is_empty() and MainGame.instance.level_manager.current_level_path != catalog.maps[String(program.map_id)]:
		return _rejected(&"SEQ_MAP_MISMATCH", "Sequence benötigt eine andere Startkarte.")
	if program.once and GameState.get_flag(catalog.completion_flag(sequence_id), false):
		return _rejected(&"ALREADY_COMPLETED", "Einmalige Sequence ist bereits abgeschlossen.")
	var context := SequenceContext.new(sequence_id)
	_runner = SequenceRunner.new()
	_runner.configure(program, command_registry, context)
	_runner.finished.connect(_on_finished.bind(program.once), CONNECT_ONE_SHOT)
	_lease = GameState.acquire_input_lease(&"sequence")
	add_child(_runner)
	var accepted := {"accepted": true, "run_id": context.run_id, "error_code": &"", "message": ""}
	sequence_started.emit(context.run_id, sequence_id)
	return accepted

func is_running() -> bool:
	return _runner != null

func active_run_id() -> String:
	return _runner.context.run_id if _runner != null else ""

func cancel(run_id: String, reason: StringName = &"cancelled") -> void:
	if _runner != null and _runner.context.run_id == run_id:
		_runner.cancel(reason)

func pause(run_id: String) -> void:
	if _runner != null and _runner.context.run_id == run_id:
		_runner.set_paused(true)

func resume(run_id: String) -> void:
	if _runner != null and _runner.context.run_id == run_id:
		_runner.set_paused(false)

func _on_finished(result: Dictionary, once: bool) -> void:
	var old_runner := _runner
	_runner = null
	if once and result.status == &"COMPLETED":
		if not GameState.apply_effects([{"type": "set_flag", "key": catalog.completion_flag(result.sequence_id), "value": true}]):
			result.status = &"FAILED"
			result.error_code = &"SEQ_COMPLETION_REJECTED"
			result.message = "Completion-Flag konnte nicht gespeichert werden."
			result.diagnostic = {"code": result.error_code, "message": result.message, "run_id": result.run_id}
	_release_lease()
	if old_runner != null:
		old_runner.queue_free()
	last_result = result.duplicate(true)
	if result.status == &"FAILED":
		sequence_failed.emit(result.run_id, result.diagnostic.duplicate(true))
	sequence_finished.emit(result.run_id, result.duplicate(true))

func _release_lease() -> void:
	if _lease != 0:
		GameState.release_input_lease(_lease)
		_lease = 0

func _exit_tree() -> void:
	_exiting = true
	if _runner != null:
		_runner.cancel(&"scene_exiting")
	_release_lease()

func _rejected(code: StringName, message: String) -> Dictionary:
	return {"accepted": false, "run_id": "", "error_code": code, "message": message}
