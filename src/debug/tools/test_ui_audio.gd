extends Node
var heard: Array[StringName] = []
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func _ready() -> void:
	UIAudio.cue_played.connect(func(cue: StringName): heard.append(cue))
	run.call_deferred()
func settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
func run() -> void:
	var panel := Control.new()
	panel.add_to_group("ui_sound_window")
	add_child(panel)
	var button := Button.new()
	panel.add_child(button)
	await settle()
	heard.clear()
	button.mouse_entered.emit()
	button.focus_entered.emit()
	await settle()
	check(heard == [&"select"], "Hover und Fokus erzeugen nur einen Select-Ton")
	heard.clear()
	button.pressed.emit()
	await settle()
	check(heard == [&"ok"], "Bestätigung spielt ok")
	heard.clear()
	button.disabled = true
	button.mouse_exited.emit()
	button.mouse_entered.emit()
	button.pressed.emit()
	await settle()
	check(heard.is_empty(), "Deaktivierte Buttons bleiben stumm")
	button.disabled = false
	button.pressed.connect(panel.hide)
	button.pressed.emit()
	await settle()
	check(heard == [&"back"], "Schließen spielt nur back statt ok und back")
	heard.clear()
	panel.show()
	await settle()
	panel.hide()
	await settle()
	check(heard == [&"back"], "Schließen ohne Button spielt back")
	var window := Window.new()
	window.visible = false
	add_child(window)
	await settle()
	heard.clear()
	window.show()
	await settle()
	window.hide()
	await settle()
	check(heard == [&"back"], "Neue Window-Fenster erhalten automatisch back")
	var list := ItemList.new()
	list.add_item("Erster")
	list.add_item("Zweiter")
	add_child(list)
	await settle()
	heard.clear()
	list.item_selected.emit(1)
	await settle()
	check(heard == [&"select"], "Listenauswahl spielt Select")
	heard.clear()
	list.item_activated.emit(1)
	await settle()
	check(heard == [&"ok"], "Listenbestätigung spielt ok")
	get_tree().paused = true
	heard.clear()
	UIAudio.request(&"back")
	await settle()
	check(heard == [&"back"], "Sounds laufen auch bei pausiertem Spiel")
	get_tree().paused = false
	for stream in UIAudio._streams.values():
		check(stream is AudioStreamWAV and stream.get_length() > 0, "WAV-Datei erfolgreich geladen")
	print("ui_audio: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
