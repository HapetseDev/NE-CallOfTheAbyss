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
	GameState.reset_session()
	var game := preload("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	game.game_windows.open_page(2)
	for frame in 4: await get_tree().process_frame
	var view := game.game_windows._embedded_views[0] as InventoryUI
	var potion := preload("res://src/resources/items/heiltrank.tres")
	view.playable.add_item(potion)
	game.game_windows._scroll.scroll_vertical = 320
	for frame in 4: await get_tree().process_frame
	for id in ["Messer", "heiltrank"]:
		var index := -1
		for i in view.playable.inventory.size():
			if view.playable.inventory[i].item.item_id == id: index = i; break
		var destination: Button = view._equip_buttons["guertel_1" if id == "Messer" else "guertel_2"]
		await _drag(view._inv_slots[index], destination)
		check(view.playable.equipment.get(destination.get_meta("slot_key")) != null, id + " per echter GUI in Schnellplatz")
	check(not view._equip_buttons.has("waffe"), "Kein separater Waffenplatz")
	if "--visual-smoke" in OS.get_cmdline_user_args():
		await _preview(game.game_windows)
	game.game_windows._scroll.scroll_vertical = 80
	for frame in 4: await get_tree().process_frame
	await _drag(view._equip_buttons.guertel_1, view._equip_buttons.primaer_hand)
	check(view.playable.equipment.primaer_hand != null and view.playable.equipment.guertel_1 == null, "Schnellplatz direkt in rechte Hand")
	await _drag(view._equip_buttons.primaer_hand, view._equip_buttons.nebenhand)
	check(view.playable.equipment.nebenhand != null and view.playable.equipment.primaer_hand == null, "Messer zwischen beiden Händen verschiebbar")
	await _drag(view._equip_buttons.nebenhand, view._equip_buttons.guertel_9)
	check(view.playable.equipment.guertel_9 != null and view.playable.equipment.nebenhand == null, "Ausgerüstetes Messer direkt in neunten Schnellplatz")
	await _drag(view._equip_buttons.guertel_2, view._equip_buttons.nebenhand)
	check(view.playable.equipment.nebenhand == potion, "Auch Trank passt in linke Hand")
	var generic := ItemData.new()
	generic.item_id = "input_generic"
	generic.item_name = "Beliebiger Gegenstand"
	view.playable.add_item(generic)
	var position: Vector2 = view._equip_buttons.guertel_3.get_global_rect().get_center()
	_motion(position, Vector2.ZERO, 0)
	_button(position, true)
	_button(position, false)
	await get_tree().process_frame
	check(view._actions != null and view._actions.visible and view._action_slot == "guertel_3", "Leerer Schnellplatz öffnet Auswahl per Mausklick")
	var choice := -1
	for id in view._slot_candidates:
		if view._slot_candidates[id] == generic: choice = id
	check(choice >= 0, "Beliebiger Gegenstand in Platzauswahl")
	view._actions.id_pressed.emit(choice)
	view._actions.hide()
	check(view.playable.equipment.guertel_3 == generic, "Auswahl belegt Schnellplatz")
	await get_tree().process_frame
	await _drag(view._equip_buttons.guertel_3, view._equip_buttons.guertel_9)
	check(view.playable.equipment.guertel_9 == generic and view.playable.equipment.guertel_3.item_id == "Messer", "Belegte Schnellplätze tauschen per Drag ohne Verlust")
	check(generic.get_combat_usage_modes()[0].mode_id == "improvisiert_schlagen", "Beliebiger Gegenstand besitzt improvisierten Angriff")
	var turn := StateCombatTurn.new()
	turn.player = view.playable
	turn._vbox = VBoxContainer.new()
	turn.add_child(turn._vbox)
	turn._render_item_menu()
	var has_attack := false
	for child in turn._vbox.get_children():
		has_attack = has_attack or (child is Button and child.text == "Beliebiger Gegenstand – Schlagen (improvisiert)")
	check(has_attack, "Kampfmenü bietet Angriff mit beliebigem Schnellgegenstand")
	turn.free()
	game.game_windows.close()
	await get_tree().process_frame
	game.free()
	await get_tree().process_frame
	print("inventory_input: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
func _motion(position: Vector2, relative: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = mask
	get_viewport().push_input(event, true)
func _button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	get_viewport().push_input(event, true)
func _drag(source: Control, target: Control) -> void:
	var start := source.get_global_rect().get_center()
	var finish := target.get_global_rect().get_center()
	_motion(start, Vector2.ZERO, 0)
	await get_tree().process_frame
	_button(start, true)
	await get_tree().process_frame
	_motion(start + Vector2(24, 0), Vector2(24, 0), MOUSE_BUTTON_MASK_LEFT)
	await get_tree().process_frame
	check(get_viewport().gui_is_dragging(), "GUI startet Drag")
	_motion(finish, finish - start, MOUSE_BUTTON_MASK_LEFT)
	await get_tree().process_frame
	_button(finish, false)
	await get_tree().process_frame

func _preview(shell: GameWindows) -> void:
	shell._scroll.scroll_vertical = 0
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/necota-hands-top.png")
	shell._scroll.scroll_vertical = 320
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/necota-hands-quick.png")
