class_name PartyHud extends PanelContainer

var _party: Party
var _row: HBoxContainer
var _entries: Array[PartyHudEntry] = []
var _ui_built: bool = false


func _ready() -> void:
	_ensure_ui_built()
	if _party:
		_rebuild_entries()


func setup(party: Party) -> void:
	_party = party
	_ensure_ui_built()
	_rebuild_entries()


func _ensure_ui_built() -> void:
	if _ui_built:
		return
	_ui_built = true

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	add_child(margin)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 16)
	margin.add_child(_row)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.11, 0.82)
	panel_style.set_corner_radius_all(6)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.35, 0.38, 0.42, 0.9)
	add_theme_stylebox_override(&"panel", panel_style)


func _rebuild_entries() -> void:
	if _row == null:
		return
	for entry in _entries:
		entry.queue_free()
	_entries.clear()
	if _party == null:
		return
	for member in _party.get_all_members():
		var entry := PartyHudEntry.new()
		entry.bind(member)
		_row.add_child(entry)
		_entries.append(entry)


func refresh() -> void:
	for entry in _entries:
		entry.refresh()


func _process(_delta: float) -> void:
	refresh()
