class_name CharacterSheetUI extends Control

var playable: Playable

@onready var _title_label: Label = %TitleLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _close_button: Button = %CloseButton
@onready var _attributes_box: VBoxContainer = %AttributesBox


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)


func bind_player(playable_ref: Playable) -> void:
	playable = playable_ref
	refresh()


func refresh() -> void:
	if playable == null or playable.character_sheet == null:
		_title_label.text = "Charakterbogen"
		_summary_label.text = "Kein Charakterbogen vorhanden."
		_clear_attributes()
		return

	var sheet := playable.character_sheet
	_title_label.text = sheet.character_name if not sheet.character_name.is_empty() else playable.get_display_name()
	_summary_label.text = "SP %d / %d  ·  KP %d / %d  ·  EP %d" % [
		sheet.staerkepunkte,
		sheet.get_staerkepunkte_basis(),
		sheet.konzentrationspunkte,
		sheet.get_konzentrationspunkte_basis(),
		sheet.erfahrungspunkte,
	]
	_rebuild_attributes(sheet)


func _rebuild_attributes(sheet: CharacterSheet) -> void:
	_clear_attributes()
	for section in sheet.get_attribute_sections():
		_attributes_box.add_child(_build_attribute_section(section))


func _build_attribute_section(section: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 6)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "%s  (%d)" % [section["attribute_name"], section["attribute_value"]]
	header.add_theme_font_size_override(&"font_size", 16)
	vbox.add_child(header)

	var influence := Label.new()
	influence.text = section["influence"]
	influence.add_theme_font_size_override(&"font_size", 12)
	influence.add_theme_color_override(&"font_color", Color(0.75, 0.78, 0.82))
	vbox.add_child(influence)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 4)
	vbox.add_child(grid)

	var name_header := Label.new()
	name_header.text = "Name der Fähigkeit"
	name_header.add_theme_font_size_override(&"font_size", 11)
	grid.add_child(name_header)

	var level_header := Label.new()
	level_header.text = "Level"
	level_header.add_theme_font_size_override(&"font_size", 11)
	grid.add_child(level_header)

	for slot in section["skill_slots"]:
		var name_label := Label.new()
		var level_label := Label.new()
		if slot == null:
			name_label.text = "—"
			level_label.text = "___"
		else:
			name_label.text = slot["skill_name"]
			level_label.text = str(slot["level"])
		grid.add_child(name_label)
		grid.add_child(level_label)

	var talents: Array = section["available_talents"]
	var talent_hint := Label.new()
	talent_hint.text = "%d Talente im Katalog" % talents.size()
	talent_hint.add_theme_font_size_override(&"font_size", 11)
	talent_hint.add_theme_color_override(&"font_color", Color(0.55, 0.58, 0.62))
	vbox.add_child(talent_hint)

	return panel


func _clear_attributes() -> void:
	for child in _attributes_box.get_children():
		child.queue_free()


func _on_close_pressed() -> void:
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.visible = false
