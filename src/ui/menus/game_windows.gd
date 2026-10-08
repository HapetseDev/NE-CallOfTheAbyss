class_name GameWindows
extends Control

## Shared shell. Owns only its input lease; content uses existing domain APIs.
const PAGES := ["Party", "Charakter", "Inventar", "Karte", "Log", "Menü", "Debug"]
var party: Party
var active_page := 0
var _lock_token := 0
var _body: VBoxContainer
var _title: Label
var _previous: Button
var _next: Button
var _stage: Control
var _panel: PanelContainer
var _covers: Array[Button] = []
var _return_focus: Control
var _scroll_positions: Dictionary = {}
var _scroll: ScrollContainer
var _embedded_views: Array[Control] = []

func _ready() -> void:
	add_to_group("ui_sound_window")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = NEColors.SCRIM
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.offset_bottom = -MainGame.TOP_BAR_HEIGHT
	add_child(dim)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_stage.offset_bottom = -MainGame.TOP_BAR_HEIGHT
	add_child(_stage)
	for offset in [-3, -2, -1, 3, 2, 1]:
		var cover := Button.new()
		cover.focus_mode = FOCUS_NONE
		cover.pressed.connect(func() -> void: select_page(active_page + offset))
		_stage.add_child(cover)
		_covers.append(cover)
	_panel = PanelContainer.new()
	_stage.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, NEDimensions.PANEL_MARGIN)
	_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", NEDimensions.SPACING_S)
	margin.add_child(root)
	var nav := HBoxContainer.new()
	root.add_child(nav)
	_previous = _button(nav, "◀", func() -> void: select_page(active_page - 1))
	_previous.tooltip_text = "Vorheriges Fenster · Q / linke Schultertaste"
	_title = Label.new()
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", NETypography.SIZE_H1)
	nav.add_child(_title)
	_next = _button(nav, "▶", func() -> void: select_page(active_page + 1))
	_next.tooltip_text = "Nächstes Fenster · E / rechte Schultertaste"
	_button(nav, "Schließen", close)
	_scroll = ScrollContainer.new()
	_scroll.follow_focus = true
	_scroll.focus_mode = FOCUS_ALL
	_scroll.gui_input.connect(_scroll_input)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_previous.focus_neighbor_bottom = _previous.get_path_to(_scroll)
	_next.focus_neighbor_bottom = _next.get_path_to(_scroll)
	_scroll.focus_neighbor_top = _scroll.get_path_to(_previous)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", NEDimensions.SPACING_M)
	_scroll.add_child(_body)
	resized.connect(_layout)
	hide()
	_layout()

func setup(party_ref: Party) -> void:
	party = party_ref

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func open_page(index: int) -> void:
	if visible and active_page == posmod(index, PAGES.size()):
		close()
		return
	if not visible:
		if GameState.is_player_input_locked():
			return
		_return_focus = get_viewport().gui_get_focus_owner()
		_lock_token = GameState.acquire_input_lease(&"game_windows")
		show()
	select_page(index)

func select_page(index: int) -> void:
	_scroll_positions[active_page] = _scroll.scroll_vertical
	active_page = posmod(index, PAGES.size())
	_title.text = PAGES[active_page]
	_clear_content()
	match active_page:
		0: _build_party()
		1: _build_characters()
		2: _build_inventories()
		3: _build_map()
		4:
			var log_view := preload("res://src/ui/hud/event_log_hud.tscn").instantiate()
			log_view.custom_minimum_size.y = _stage.size.y * 0.6
			_body.add_child(log_view)
		5: _build_menu()
		6: _build_debug()
	_layout()
	_previous.grab_focus()
	_restore_scroll.call_deferred()

func _restore_scroll() -> void:
	_scroll.scroll_vertical = _scroll_positions.get(active_page, 0)

func _clear_content() -> void:
	for view in _embedded_views:
		view.queue_free()
	_embedded_views.clear()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

func close() -> void:
	if not visible:
		return
	hide()
	_release_lock()
	_clear_content()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()

func _release_lock() -> void:
	if _lock_token != 0:
		GameState.release_input_lease(_lock_token)
		_lock_token = 0

func _exit_tree() -> void:
	_release_lock()

func _layout() -> void:
	if not _panel:
		return
	var available := _stage.size
	_panel.position = Vector2(available.x * 0.16, NEDimensions.SPACING_M)
	_panel.size = Vector2(available.x * 0.68, maxf(0, available.y - NEDimensions.SPACING_XL))
	var offsets := [-3, -2, -1, 3, 2, 1]
	for i in _covers.size():
		var offset: int = offsets[i]
		var cover := _covers[i]
		cover.text = PAGES[posmod(active_page + offset, PAGES.size())]
		cover.size = Vector2(available.x * 0.105, available.y * (0.68 - abs(offset) * 0.08))
		cover.position = Vector2(available.x * (0.03 + (3 - abs(offset)) * 0.025 if offset < 0 else 0.865 - (3 - abs(offset)) * 0.025), (available.y - cover.size.y) * 0.5)
		cover.rotation = deg_to_rad(-8 if offset < 0 else 8)
		cover.scale.x = 0.8

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
			open_page(5)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("Inventar"):
		open_page(2)
	elif event.is_action_pressed("Charakterbogen"):
		open_page(1)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_E]:
		select_page(active_page + (-1 if event.keycode == KEY_Q else 1))
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		select_page(active_page + (-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1))
	else:
		return
	get_viewport().set_input_as_handled()

func _build_party() -> void:
	_label(_body, "Platz 1 ist der Anführer. ▲ / ▼ ändern die Reihenfolge.")
	if not party:
		return
	var members := party.get_all_members()
	for index in members.size():
		var member := members[index]
		var row := HBoxContainer.new()
		_body.add_child(row)
		var entry := preload("res://src/ui/hud/party_hud_entry.tscn").instantiate() as PartyHudEntry
		entry.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(entry)
		entry.bind(member)
		var lead := _button(row, "Anführer" if index == 0 else "Anführen", _move.bind(member, -index))
		lead.disabled = index == 0 or not _can_reorder()
		var up := _button(row, "▲", _move.bind(member, -1))
		up.disabled = index == 0 or not _can_reorder()
		var down := _button(row, "▼", _move.bind(member, 1))
		down.disabled = index == members.size() - 1 or not _can_reorder()

func _move(member: Playable, delta: int) -> void:
	_release_lock()
	var success := party.move_member(member as Player, delta)
	_lock_token = GameState.acquire_input_lease(&"game_windows")
	select_page(0)
	if not success:
		_label(_body, "Wechsel gesperrt: Kampf, Interaktion oder kampfunfähiger Anführer.")

func _embed(view: Control) -> Control:
	view.embedded = true
	view.mouse_filter = MOUSE_FILTER_IGNORE
	view.hide()
	add_child(view)
	_embedded_views.append(view)
	view.get_node("Overlay").hide()
	var content := view.get_node("Window/MarginContainer") as Control
	content.reparent(_body)
	content.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	return content

func _build_characters() -> void:
	if not party:
		return
	for member in party.get_all_members():
		var view := preload("res://src/ui/character/character_sheet_ui.tscn").instantiate() as CharacterSheetUI
		var content := _embed(view)
		view.bind_player(member)
		# One outer scroll, with sheets directly below each other.
		var inner := content.get_node("VBoxContainer/ScrollContainer")
		var attributes := inner.get_node("AttributesBox")
		attributes.reparent(inner.get_parent())
		inner.queue_free()

func _build_inventories() -> void:
	if not party:
		return
	for member in party.get_all_members():
		_label(_body, member.get_display_name())
		var view := preload("res://src/ui/inventory/InventoryUI.tscn").instantiate() as InventoryUI
		var content := _embed(view)
		view.bind_player(member, party)
		view._menu_hud.hide()
		content.get_node("VBoxContainer/DropHint").text = "Auswählen: Aktionsmenü · Ziehen auf Ausrüstung: ausrüsten · Ziehen in anderen Rucksack: 1 Stück übergeben"

func _build_map() -> void:
	var view := preload("res://src/ui/menus/map_ui.tscn").instantiate() as MapUI
	var content := _embed(view)
	content.custom_minimum_size.y = _stage.size.y * 0.65
	view.cartography.update(MainGame.instance)
	view._refresh()
	view._map.reset_view()
	view.get_node("Window").hide()
	view.show()
	var close_button := content.find_child("CloseMap", true, false) as Button
	if close_button:
		close_button.pressed.disconnect(view._on_close_requested)
		close_button.pressed.connect(close)

func _build_menu() -> void:
	_button(_body, "Weiter spielen", close)
	_button(_body, "Speichern / Laden", _open_saves)
	_button(_body, "Optionen", _options)
	_button(_body, "Zum Hauptmenü", _on_main_menu_pressed)
	_button(_body, "Spiel beenden", func() -> void: get_tree().quit())

func _open_saves() -> void:
	var parent := get_parent()
	close()
	var menu := preload("res://src/ui/menus/save_load_menu.gd").new()
	menu.name = "SaveLoadMenu"
	menu._can_save = true
	parent.add_child(menu)

func _options() -> void:
	_clear_content()
	_label(_body, "Lautstärke")
	for bus in AudioServer.bus_count:
		_label(_body, AudioServer.get_bus_name(bus))
		var slider := HSlider.new()
		slider.min_value = -60
		slider.max_value = 0
		slider.value = AudioServer.get_bus_volume_db(bus)
		slider.value_changed.connect(func(value: float) -> void: AudioServer.set_bus_volume_db(bus, value))
		_body.add_child(slider)
	_button(_body, "Zurück", func() -> void: select_page(5))

func _build_debug() -> void:
	_label(_body, "Entwicklungswerkzeuge")
	if party:
		for member in party.get_all_members():
			_button(_body, "Charakter bearbeiten: " + member.get_display_name(), func() -> void:
				close()
				DebugMenu.open_character_editor(member))


func _can_reorder() -> bool:
	if not party:
		return false
	var owned := _lock_token != 0
	_release_lock()
	var allowed := party.can_reorder()
	if owned:
		_lock_token = GameState.acquire_input_lease(&"game_windows")
	return allowed


func _on_main_menu_pressed() -> void:
	close()
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")


func _scroll_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical += NEDimensions.BUTTON_HEIGHT * (1 if event.is_action_pressed("ui_down") else -1)
		_scroll.accept_event()
