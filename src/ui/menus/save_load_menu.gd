extends Control

const Catalog := preload("res://src/core/world/save_catalog.gd")
const PAGE_SIZE := 50
var catalog := Catalog.new()
var _entries: Array[Dictionary] = []
var _filtered: Array[Dictionary] = []
var _page := 0
var _lock_owned := false
var _busy := false
var _confirming := false
var _can_save := false
var _list: ItemList
var _search: LineEdit
var _title: LineEdit
var _status: Label
var _page_label: Label
var _save: Button
var _load: Button
var _back: Button
var _next: Button
var _close: Button

func _ready() -> void:
	add_to_group("ui_sound_window")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = NEColors.SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT, 0.1)
	panel.set_anchor(SIDE_RIGHT, 0.9)
	panel.set_anchor(SIDE_TOP, 0.08)
	panel.set_anchor(SIDE_BOTTOM, 0.92)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, NEDimensions.PANEL_MARGIN)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", NEDimensions.SPACING_S)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = "Spielstände"
	heading.add_theme_font_size_override("font_size", NETypography.SIZE_H1)
	box.add_child(heading)
	_search = LineEdit.new()
	_search.placeholder_text = "Spielstände suchen …"
	_search.text_changed.connect(func(_text: String) -> void: _page = 0; _filter())
	box.add_child(_search)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(_index: int) -> void: _cancel_confirmation(); _update_buttons())
	box.add_child(_list)
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", NEDimensions.SPACING_S)
	box.add_child(pages)
	_back = _button(pages, "Zurück", func() -> void: _page -= 1; _render())
	_page_label = Label.new()
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pages.add_child(_page_label)
	_next = _button(pages, "Weiter", func() -> void: _page += 1; _render())
	_title = LineEdit.new()
	_title.placeholder_text = "Name des neuen Spielstands (optional)"
	_title.max_length = 80
	_title.visible = _can_save
	box.add_child(_title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", NEDimensions.SPACING_S)
	box.add_child(actions)
	_save = _button(actions, "Neu speichern", _save_new)
	_save.visible = _can_save
	_load = _button(actions, "Laden", _load_selected)
	_close = _button(actions, "Schließen", close)
	_acquire_lock()
	_refresh()
	_search.grab_focus()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _acquire_lock() -> void:
	if not _lock_owned:
		GameState.acquire_input_lock()
		_lock_owned = true

func _release_lock() -> void:
	if _lock_owned:
		GameState.release_input_lock()
		_lock_owned = false

func _exit_tree() -> void:
	_release_lock()

func close() -> void:
	if _busy:
		return
	hide()
	_release_lock()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirming:
			_cancel_confirmation()
		else:
			close()

func _refresh() -> void:
	_entries = catalog.entries()
	_filter()
	_status.text = catalog.last_error if not catalog.last_error.is_empty() else ("Noch keine Spielstände vorhanden." if _entries.is_empty() else "Jedes Speichern legt einen neuen Spielstand an.")

func _filter() -> void:
	_filtered.clear()
	for entry in _entries:
		if _search.text.strip_edges().is_empty() or entry.title.to_lower().contains(_search.text.strip_edges().to_lower()):
			_filtered.append(entry)
	_render()

func _render() -> void:
	_cancel_confirmation()
	_list.clear()
	_page = clampi(_page, 0, maxi(0, ceili(float(_filtered.size()) / PAGE_SIZE) - 1))
	for index in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, _filtered.size())):
		var entry := _filtered[index]
		var date := Time.get_datetime_string_from_unix_time(entry.modified).replace("T", " ")
		_list.add_item(entry.title + "  ·  " + date + " UTC")
		_list.set_item_metadata(_list.item_count - 1, entry.path)
	_page_label.text = "%d Spielstände · Seite %d / %d" % [_filtered.size(), _page + 1, maxi(1, ceili(float(_filtered.size()) / PAGE_SIZE))]
	_update_buttons()

func _cancel_confirmation() -> void:
	_confirming = false
	if _load != null:
		_load.text = "Laden"
	if _status != null:
		_status.text = ""

func _update_buttons() -> void:
	if _load == null:
		return
	_load.disabled = _busy or _list.get_selected_items().is_empty()
	_save.disabled = _busy
	_close.disabled = _busy
	_back.disabled = _busy or _page == 0
	_next.disabled = _busy or (_page + 1) * PAGE_SIZE >= _filtered.size()
	_search.editable = not _busy
	_title.editable = not _busy
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if _busy else Control.MOUSE_FILTER_STOP

func _save_new() -> void:
	if _busy or not _can_save:
		return
	_cancel_confirmation()
	_release_lock()
	var result: Dictionary = catalog.save_new(_title.text, LevelManager.instance)
	_acquire_lock()
	if result.error != OK:
		_status.text = catalog.last_error
		return
	_search.text = ""
	_page = 0
	_refresh()
	_status.text = "Neuer Spielstand gespeichert."

func _load_selected() -> void:
	if _busy or _list.get_selected_items().is_empty():
		return
	if MainGame.instance != null and not _confirming:
		_confirming = true
		_load.text = "Jetzt laden"
		_status.text = "Die aktuelle Sitzung wird ersetzt. Ungespeicherter Fortschritt geht verloren. Zum Bestätigen erneut laden."
		return
	var path: String = _list.get_item_metadata(_list.get_selected_items()[0])
	_busy = true
	_update_buttons()
	_status.text = "Spielstand wird geladen …"
	_release_lock()
	# Erfolg entfernt diese Oberfläche. Der Autoload beendet den Ablauf unabhängig.
	var error := await GameState.load_game(path)
	if error != OK:
		_acquire_lock()
		_busy = false
		_cancel_confirmation()
		_status.text = GameState.last_load_error if not GameState.last_load_error.is_empty() else "Laden ist derzeit gesperrt."
		_update_buttons()
