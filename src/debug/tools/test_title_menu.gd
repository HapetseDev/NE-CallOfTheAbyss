extends Node
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var menu := preload("res://src/ui/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	if "--visual-smoke" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/necota-title-menu.png")
	check(menu.start_button.has_focus(), "Initialer Fokus")
	check(menu.load_button.text == "Spiel laden", "Drei Menüoptionen")
	var old_y: float = menu.camera.position.y
	menu._process(1.0)
	check(menu.camera.position.y < old_y, "Kamera bewegt sich abwärts")
	menu.set_process(false)
	menu.fade_duration = 0.01
	for index in range(3):
		var expected: int = (index + 1) % 3
		menu._cycle_background()
		await menu.cycle_tween.finished
		check(menu.background_index == expected, "Reihenfolge einschließlich Rücksprung")
		check(menu.room.get_node("WorldEnvironment").environment.fog_enabled, "Raum besitzt Nebel")
		check(menu.background_fade.modulate.a < 0.01, "Blende endet transparent")
		check(menu.start_button.is_visible_in_tree(), "Menü bleibt sichtbar")
	menu._open_saves()
	menu._open_saves()
	check(menu.get_node("SaveLoadMenu") != null, "Ladeoberfläche öffnet")
	check(GameState._input_lock_count == 1, "Keine doppelte Ladeoberfläche")
	menu.get_node("SaveLoadMenu").close()
	await get_tree().process_frame
	check(GameState._input_lock_count == 0 and menu.load_button.has_focus(), "Schließen gibt Sperre und Fokus zurück")
	menu.queue_free()
	await get_tree().process_frame
	print("title_menu: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
