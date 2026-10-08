extends Node
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var game := preload("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame
	var ui := game.game_windows
	check(game._top_bar_hud.anchor_top == 1.0, "Spiel-Leiste unten")
	ui.open_page(0)
	check(ui.visible and GameState.is_player_input_locked(), "Fenster sperrt Weltsteuerung")
	ui.select_page(-1)
	check(ui.active_page == 6, "Party nach links wird Debug")
	ui.select_page(7)
	check(ui.active_page == 0, "Debug nach rechts wird Party")
	var follower := game.party.followers[0]
	ui._move(follower, -1)
	check(game.party.leader == follower, "Anführerwahl verwendet Partyvertrag")
	ui.select_page(1)
	check(ui._embedded_views.size() == game.party.get_all_members().size(), "Alle Charakterblätter")
	check((ui._embedded_views[0] as CharacterSheetUI).playable == follower, "Partyreihenfolge")
	await get_tree().process_frame
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	ui._scroll.grab_focus()
	ui._scroll_input(down)
	check(ui._scroll.scroll_vertical > 0, "Charakterblätter per Tastatur/Controller scrollbar")
	ui.select_page(2)
	await get_tree().process_frame
	var source := ui._embedded_views[0] as InventoryUI
	var target := ui._embedded_views[1] as InventoryUI
	var item := ItemData.new()
	item.item_id = "ui_transfer_probe"
	item.item_name = "Testgegenstand"
	item.weight = 0
	item.max_stack = 10
	source.playable.add_item(item, 2)
	var index := source.playable.inventory.size() - 1
	check(source.transfer_to(index, target.playable), "Übergabe über WorldRules")
	check(source.playable.inventory[index].count == 1, "Genau ein Stück übergeben")
	item.weight = 99999
	check(not source.transfer_to(index, target.playable), "Traglast verhindert Übergabe")
	check(source.playable.inventory[index].count == 1, "Fehlgeschlagene Übergabe erhält Gegenstand")
	item.weight = 0
	check(not source.transfer_to(index, source.playable), "Keine Selbstübergabe")
	var payload: Variant = {"type": "inventory_item", "index": index, "source": source, "item": item}
	check(payload.source == source, "Drag kennt Absender")
	check(target._inv_slots[0]._can_drop_data(Vector2.ZERO, payload), "Anderer Rucksack nimmt Drag an")
	check(not target.can_equip_from_slot(-1, "weapon"), "Ungültiger Slot abgewiesen")
	for page in [3,4,5,6,0,2]:
		ui.select_page(page)
		await get_tree().process_frame
		check(ui.active_page == page and ui._body.get_child_count() > 0, "Seite %d aufgebaut" % page)
	var controller := InputEventJoypadButton.new()
	controller.pressed = true
	controller.button_index = JOY_BUTTON_RIGHT_SHOULDER
	ui._unhandled_input(controller)
	check(ui.active_page == 3, "Controller-Schultertaste wechselt Seite")
	GameState.acquire_input_lock()
	ui.close()
	check(GameState.is_player_input_locked(), "Fremde Sperre bleibt erhalten")
	GameState.release_input_lock()
	check(not GameState.is_player_input_locked(), "Eigene Sperre freigegeben")
	ui.close()
	await get_tree().process_frame
	payload = null
	item = null
	game.free()
	await get_tree().process_frame
	print("game_windows: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
