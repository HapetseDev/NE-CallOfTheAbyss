extends Node

const Catalog := preload("res://src/core/world/save_catalog.gd")
const Menu := preload("res://src/ui/menus/save_load_menu.gd")
var checks := 0
var failures := 0
var folder := "/tmp/necota-save-menu-%d" % Time.get_ticks_usec()

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	tree.change_scene_to_file("res://src/core/main_game/main_game.tscn")
	await tree.scene_changed
	var game := tree.current_scene as MainGame
	var catalog := Catalog.new()
	catalog.directory = folder
	check(catalog.entries().is_empty(), "Neuer Speicherordner ist leer")
	game.party.leader.gold = 147
	var first := catalog.save_new("Lyrandis", game.level_manager)
	game.party.leader.gold = 258
	var second := catalog.save_new("Lyrandis", game.level_manager)
	check(first.error == OK and second.error == OK and first.path != second.path, "Gleiche Namen erzeugen getrennte Slots")
	check(WorldSaveStore.new().read(first.path).characters.get_character("dannerman").gold == 147, "Späteres Speichern überschreibt früheren Stand nicht")
	check(catalog.entries().size() == 2 and catalog.entries()[0].title == "Lyrandis", "Titel werden wiedergefunden")
	var hostile := catalog.save_new("../../Außen/Ort:*?", game.level_manager)
	check(hostile.error == OK and hostile.path.get_base_dir() == folder, "Titel kann Speicherordner nicht verlassen")
	check(catalog._safe_title(" ") == "Spielstand" and catalog._safe_title("Ä".repeat(100)).to_utf8_buffer().size() <= 80, "Leere und lange Unicode-Namen behandelt")
	GameState.acquire_input_lock()
	check(catalog.save_new("Gesperrt", game.level_manager).error == ERR_BUSY and catalog.entries().size() == 3, "Fremde Sperre verhindert neue Datei")
	GameState.release_input_lock()
	# Große Liste ohne viele Weltdekodierungen; beschädigte Dateien bleiben auswählbar.
	for index in range(120):
		var file := FileAccess.open(folder.path_join("Test-%03d.json" % index), FileAccess.WRITE)
		file.store_string("broken")
		file.close()
	var temp := FileAccess.open(folder.path_join("unfinished.json.tmp"), FileAccess.WRITE)
	temp.store_string("broken")
	temp.close()
	check(catalog.entries().size() == 123, "Keine feste Slotgrenze; temporäre Dateien ausgeblendet")
	game.game_windows.open_page(5)
	game.game_windows._open_saves()
	var menu = game.menu_root.get_node("SaveLoadMenu")
	menu.catalog = catalog
	menu._refresh()
	await tree.process_frame
	check(not game.game_windows.visible and GameState._input_lock_count == 1, "Pausemenü übergibt genau eine eigene Sperre")
	check(menu._list.item_count == 50 and not menu._next.disabled, "Liste ist seitenweise begrenzt")
	menu._next.pressed.emit()
	check(menu._page == 1 and menu._list.item_count == 50, "Nächste Seite erreichbar")
	menu._search.text = "Lyrandis"
	menu._search.text_changed.emit("Lyrandis")
	check(menu._list.item_count == 2 and menu._page == 0, "Suche filtert über alle Seiten")
	menu._search.text = "kein Treffer"
	menu._search.text_changed.emit("kein Treffer")
	check(menu._list.item_count == 0 and menu._load.disabled, "Leere Suche verhindert Laden")
	GameState.acquire_input_lock()
	menu._save_new()
	check(catalog.entries().size() == 123 and GameState._input_lock_count == 2, "UI-Speichern löst fremde Sperre nicht")
	GameState.release_input_lock()
	menu._title.text = "Aus Menü"
	menu._save_new()
	check(catalog.entries().size() == 124 and GameState._input_lock_count == 1, "UI speichert neuen Slot und bleibt gesperrt")
	menu._search.text = "Test-000"
	menu._filter()
	menu._list.select(0)
	menu._load_selected()
	check(menu._confirming and not menu._busy, "Laden aus Spiel erfordert Bestätigung")
	await menu._load_selected()
	check(tree.current_scene == game and not menu._busy and GameState._input_lock_count == 1 and not menu._status.text.is_empty(), "Beschädigte Datei erhält Sitzung und nutzbares Menü")
	menu.close()
	await tree.process_frame
	check(GameState._input_lock_count == 0, "Schließen gibt Menüsperre frei")
	# Schreibfehler wird sichtbar, bestehende Slots bleiben erhalten.
	var bad_catalog := Catalog.new()
	bad_catalog.directory = first.path
	check(bad_catalog.save_new("Fehler", game.level_manager).error != OK and not bad_catalog.last_error.is_empty(), "Ordnerfehler wird gemeldet")
	# Echtes Laden aus einem UI, das durch Erfolg selbst freigegeben wird.
	game.game_windows.open_page(5)
	game.game_windows._open_saves()
	menu = game.menu_root.get_node("SaveLoadMenu")
	menu.catalog = catalog
	menu._refresh()
	menu._search.text = "Aus Menü"
	menu._filter()
	menu._list.select(0)
	menu._load_selected()
	menu._load_selected()
	await GameState.game_loaded
	check(not is_instance_valid(menu) and not is_instance_valid(game) and GameState._input_lock_count == 0, "Erfolgreiches UI-Laden beendet sich ohne verwaiste Sperre")
	check(MainGame.instance.party.leader.gold == 258, "UI lädt gewählten Spielstand")
	tree.change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	await tree.scene_changed
	var main := tree.current_scene as MainMenu
	main._open_saves()
	menu = main.get_node("SaveLoadMenu")
	menu.catalog = catalog
	menu._refresh()
	check(not menu._save.visible and not menu._title.visible, "Hauptmenü bietet nur Laden")
	menu._search.text = "Aus Menü"
	menu._filter()
	menu._list.select(0)
	menu._load_selected()
	await GameState.game_loaded
	check(MainGame.instance != null and GameState._input_lock_count == 0, "Hauptmenü lädt über gemeinsamen Ablauf")
	tree.current_scene.free()
	print("save_menu: %d Checks, %d Fehler" % [checks, failures])
	tree.quit(1 if failures else 0)
