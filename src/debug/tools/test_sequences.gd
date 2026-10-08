extends Node

const HEADER := "sequence test version=1 content_version=1 once=false\n"
var checks := 0
var failures := 0
var results: Array[Dictionary] = []
var failed_signals := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_parser()
	_test_handles()
	_test_leases()
	await _test_main_game()
	print("sequences: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_parser() -> void:
	var parser := SequenceParser.new()
	var registry := SequenceCommandRegistry.new()
	var catalog := preload("res://src/resources/sequences/sequence_catalog.tres")
	var source := String.chr(0xfeff) + (HEADER + "# comment\nwait 0.5\nset flag=\"sequence_mvp_done\" value=true id=test\nend code=\"quoted \\\"#\\\" and \\\\ slash\\nline\" # comment\n").replace("\n", "\r\n")
	var program := parser.parse(source, "fixture.sequence", registry, catalog)
	check(program.is_valid(), "BOM, CRLF, Kommentare und Escapes akzeptiert")
	if program.is_valid():
		check(program.instructions[2].arguments.code == "quoted \"#\" and \\ slash\nline", "String-Escapes und # bleiben erhalten")
		check(program.instructions[0].line == 3 and program.instructions[0].column == 1, "Sourceposition bleibt korrekt")
	for fixture in [
		["move player to=missing\nend", "SEQ_CAPABILITY_MISSING"],
		["wait 1 unknown=true\nend", "SEQ_ARGUMENT_UNKNOWN"],
		["end code=\"a\" code=\"b\"", "SEQ_ARGUMENT_DUPLICATE"],
		["wait -1\nend", "SEQ_DURATION"],
		["wait 3601\nend", "SEQ_DURATION"],
		["wait NaN\nend", "SEQ_TYPE"],
		["wait 0.1" , "SEQ_END_MISSING"],
		["set flag=\"missing\" value=true id=one\nend", "SEQ_FLAG_UNKNOWN"],
		["set flag=\"sequence_mvp_done\" value=\"true\" id=one\nend", "SEQ_TYPE"],
		["set flag=\"sequence_mvp_done\" value=true\nend", "SEQ_ARGUMENT_REQUIRED"],
		["set flag=\"sequence_mvp_done\" value=true id=one\nset flag=\"sequence_mvp_done\" value=false id=one\nend", "SEQ_EFFECT_ID_DUPLICATE"],
		["end code=\"bad\\q\"", "SEQ_ESCAPE"],
		["end code=\"open", "SEQ_STRING"],
		["end\nwait 1", "SEQ_UNREACHABLE"],
		["sequence other version=1 content_version=1\nend", "SEQ_HEADER_DUPLICATE"]
	]:
		program = parser.parse(HEADER + fixture[0], "fixture.sequence", registry, catalog)
		check(not program.is_valid() and _has_code(program, fixture[1]), "Ungültige DSL abgelehnt: " + fixture[1])
	program = parser.parse("sequence bad version=2 content_version=1\nend", "fixture.sequence", registry, catalog)
	check(_has_code(program, "SEQ_VERSION"), "Zukunftsversion abgelehnt")
	check(not parser.parse("wait 1\nend", "fixture.sequence", registry, catalog).is_valid(), "Fehlender Header abgelehnt")
	check(not parser.parse("", "fixture.sequence", registry, catalog).is_valid(), "Leere Datei abgelehnt")
	check(not registry.register_command(&"wait", {}, _failed_command), "Doppelte Commandregistrierung abgelehnt")

func _has_code(program: SequenceProgram, code: String) -> bool:
	for diagnostic in program.diagnostics:
		if String(diagnostic.code) == code:
			return true
	return false

func _test_handles() -> void:
	var handle := SequenceHandle.new()
	var emitted: Array = []
	handle.completed.connect(func(result: Dictionary) -> void: emitted.append(result))
	handle.finish()
	handle.cancel()
	check(handle.is_terminal() and handle.get_result().status == &"SUCCESS" and emitted.size() == 1, "Sofortiger Handleabschluss einmalig und abrufbar")
	handle = SequenceHandle.new()
	handle.wait_for(0)
	check(not handle.is_terminal(), "wait 0 ist zunächst blockierend")
	handle.tick(0.01)
	check(handle.is_terminal(), "wait 0 endet am nächsten Tick")

func _test_leases() -> void:
	GameState.reset_session()
	var lease := GameState.acquire_input_lease(&"test")
	GameState.acquire_input_lock()
	GameState.release_input_lock()
	GameState.release_input_lock()
	check(GameState.is_player_input_locked(), "Legacy release löst keinen Besitzer-Lease")
	check(GameState.release_input_lease(lease), "Eigener Lease wird gelöst")
	check(not GameState.release_input_lease(lease) and not GameState.is_player_input_locked(), "Doppelte Freigabe verändert nichts")
	var old := GameState.acquire_input_lease(&"old")
	GameState.reset_session()
	var fresh := GameState.acquire_input_lease(&"fresh")
	check(old != fresh and not GameState.release_input_lease(old) and GameState.is_player_input_locked(), "Alter Token kann neue Sitzung nicht entsperren")
	GameState.release_input_lease(fresh)

func _test_main_game() -> void:
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	var manager := game.sequence_manager
	var catalog := SequenceCatalog.new()
	catalog.flags = PackedStringArray(["sequence_mvp_done"])
	for name in ["wait", "once", "abort", "failure", "invalid"]:
		catalog.sequences["test_" + name] = "res://src/resources/sequences/tests/" + name + ".sequence"
	manager.catalog = catalog
	manager.sequence_finished.connect(func(_id: String, result: Dictionary) -> void: results.append(result))
	manager.sequence_failed.connect(func(_id: String, _diagnostic: Dictionary) -> void: failed_signals += 1)
	GameState.acquire_input_lock()
	check(manager.start(&"test_wait").error_code == &"BUSY", "Fremde Interaktion verhindert Start")
	GameState.release_input_lock()
	get_tree().paused = true
	check(manager.start(&"test_wait").error_code == &"BUSY", "Pause verhindert Start")
	get_tree().paused = false
	check(manager.start(&"missing").error_code == &"SEQ_NOT_FOUND", "Unregistrierte Sequence abgelehnt")
	check(not manager.start(&"test_invalid").accepted and not GameState.is_player_input_locked(), "Validierungsfehler erwirbt keine Sperre")
	var started := manager.start(&"test_wait")
	check(started.accepted and GameState.is_player_input_locked(), "MainGame startet Sequence und sperrt Input")
	check(manager.start(&"test_wait").error_code == &"BUSY", "Zweiter Start im selben Frame abgelehnt")
	var foreign := GameState.acquire_input_lease(&"foreign")
	manager.cancel("wrong-run")
	check(manager.is_running(), "Fremde Run-ID kann nicht canceln")
	manager.cancel(started.run_id)
	manager.cancel(started.run_id)
	check(results.size() == 1 and results.back().status == &"ABORTED", "Cancel vor erstem Tick endet genau einmal")
	check(GameState.is_player_input_locked() and not GameState.get_flag("sequence_mvp_done", false), "Cancel erhält Fremdsperre und führt keine Folgeeffekte aus")
	GameState.release_input_lease(foreign)
	check(not GameState.is_player_input_locked(), "Sequence-Lease ist freigegeben")
	started = manager.start(&"test_wait")
	await get_tree().process_frame
	manager.pause(started.run_id)
	await get_tree().create_timer(0.25).timeout
	check(manager.is_running() and not GameState.get_flag("sequence_mvp_done", false), "Sequence-Pause stoppt Timer und Folgeeffekte")
	manager.resume(started.run_id)
	await _wait_for_finish(manager)
	check(results.back().status == &"COMPLETED" and results.back().end_code == "tested" and GameState.get_flag("sequence_mvp_done", false), "Resume beendet Wait und führt Weltregel aus")
	check(not GameState.is_player_input_locked(), "Normaler Abschluss gibt Input frei")
	manager.start(&"test_once")
	await _wait_for_finish(manager)
	check(manager.start(&"test_once").error_code == &"ALREADY_COMPLETED", "Einmalige Completion verhindert Neustart")
	var path := "user://sequence_test_" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	check(game.level_manager.save_world(path) == OK, "Freies Gameplay speichert Sequenceflags")
	var saved := WorldSaveStore.new().read(path)
	check(saved != null and saved.flags.get("sequence_mvp_done", false) and saved.flags.get("sequence_completed.test_once", false), "Flags und Completion über vorhandenen Savevertrag erhalten")
	DirAccess.remove_absolute(path)
	manager.start(&"test_abort")
	await _wait_for_finish(manager)
	check(results.back().status == &"ABORTED" and not GameState.has_flag("sequence_completed.test_abort"), "DSL-abort verbraucht keine Completion")
	manager.command_registry.register_command(&"test_failure", {"positional": [], "required": {}, "optional": {}}, _failed_command)
	manager.start(&"test_failure")
	await _wait_for_finish(manager)
	check(results.back().status == &"FAILED" and failed_signals == 1 and results.back().diagnostic.line == 2, "Runtimefehler mit Sourcezeile und einmaligem Failed-Signal")
	check(not GameState.is_player_input_locked(), "Runtimefehler gibt eigene Sperre frei")
	# Debugstart: Fenster gibt nur seinen eigenen Legacy-Lock vor Start ab.
	manager.catalog = preload("res://src/resources/sequences/sequence_catalog.tres")
	DebugMenu.open_character_editor(game.party.leader)
	check(DebugMenu.is_open() and GameState.is_player_input_locked(), "Debugfenster hat eigene Sperre")
	DebugMenu.instance._start_sequence_demo()
	check(not DebugMenu.is_open() and manager.is_running(), "Demo schließt Debugfenster und startet echte Sequence")
	manager.cancel(manager.active_run_id())
	check(not GameState.is_player_input_locked(), "Debugdemo-Abbruch gibt Kontrolle frei")
	manager.catalog = catalog
	# WorldLoader-Rollback hängt alte Systeme aus und setzt sie wieder ein.
	var systems := manager.get_parent()
	systems.remove_child(manager)
	systems.add_child(manager)
	started = manager.start(&"test_wait")
	check(started.accepted, "Nach Aushängen/Wiedereinsetzen bleibt Manager startbar")
	manager.cancel(started.run_id)
	GameState.set_flag("sequence_mvp_done", false)
	started = manager.start(&"test_wait")
	await get_tree().process_frame
	get_tree().paused = true
	await get_tree().create_timer(0.25, true).timeout
	check(manager.is_running() and not GameState.get_flag("sequence_mvp_done", false), "Globale Spielpause stoppt Runner ohne Folgeeffekte")
	get_tree().paused = false
	await _wait_for_finish(manager)
	check(GameState.get_flag("sequence_mvp_done", false), "Nach globaler Pause wird Sequence fortgesetzt")
	manager.start(&"test_wait")
	await get_tree().process_frame
	foreign = GameState.acquire_input_lease(&"outside_main_game")
	game.preserve_state_on_exit = true
	var before := results.size()
	game.free()
	check(results.size() == before + 1 and results.back().status == &"ABORTED", "MainGame-Abbau cancelt laufenden Run")
	check(GameState.is_player_input_locked(), "MainGame-Cleanup löst keine Fremdsperre")
	GameState.release_input_lease(foreign)
	check(not GameState.is_player_input_locked(), "MainGame-Abbau hinterlässt keinen Sequence-Lease")
	await get_tree().process_frame
	GameState.reset_session()

func _wait_for_finish(manager: SequenceManager) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while manager.is_running() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.01).timeout
	check(not manager.is_running(), "Run erreicht terminalen Zustand vor Timeout")
	if manager.is_running():
		manager.cancel(manager.active_run_id(), &"test_timeout")

func _failed_command(_context: SequenceContext, _instruction: Dictionary) -> SequenceHandle:
	var handle := SequenceHandle.new()
	handle.finish(&"FAILED", &"TEST_FAILURE", "Absichtlicher Adapterfehler")
	return handle
