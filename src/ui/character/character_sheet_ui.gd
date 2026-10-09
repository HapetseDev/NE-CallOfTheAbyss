class_name CharacterSheetUI extends Control

# Local reference palette: deliberately scoped to the character document.
const SHEET_THEME := preload("res://src/ui/character/character_sheet_theme.tres")
const SHEET_PAPER := Color(0.85, 0.91, 0.99, 1)

var embedded := false
var playable: Playable

@onready var _content: Control = $Window/MarginContainer
@onready var _window: Window = %Window
@onready var _title_label: Label = %TitleLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _attributes_box: VBoxContainer = %AttributesBox


func _ready() -> void:
	_window.close_requested.connect(_on_close_requested)
	visibility_changed.connect(_on_visibility_changed)


func bind_player(playable_ref: Playable) -> void:
	playable = playable_ref
	refresh()


func _on_visibility_changed() -> void:
	if not is_node_ready() or embedded:
		return
	if is_visible_in_tree():
		_window.visible = true
		_window.grab_focus()
		refresh()
	else:
		_window.visible = false


func refresh() -> void:
	if not is_node_ready():
		return
	if playable == null or playable.character == null:
		_title_label.show()
		_summary_label.show()
		_title_label.text = "Charakterbogen"
		_window.title = "Charakterbogen"
		_summary_label.text = "Kein Charakter vorhanden."
		_clear_attributes()
		return

	var data := playable.character
	var display_name := data.character_name if not data.character_name.is_empty() else playable.get_display_name()
	_title_label.text = display_name
	_window.title = "Charakterbogen — %s" % display_name
	_summary_label.text = "SP %d / %d  ·  KP %d / %d  ·  EP %d" % [
		data.staerkepunkte,
		data.get_staerkepunkte_basis(),
		data.konzentrationspunkte,
		data.get_konzentrationspunkte_basis(),
		data.erfahrungspunkte,
	]
	_rebuild_attributes(data)


# The reference sheet is one continuous document; GameWindows removes only
# the local scroll wrapper when embedding it in the party-wide scroll.
func _rebuild_attributes(data: CharacterResource) -> void:
	_clear_attributes()
	var content := _content
	content.theme = SHEET_THEME
	if not content.has_node("SheetPaper"):
		var paper := ColorRect.new()
		paper.name = "SheetPaper"
		paper.color = SHEET_PAPER
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(paper)
		content.move_child(paper, 0)
		paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_label.hide()
	_summary_label.hide()
	_attributes_box.add_theme_constant_override(&"separation", NEDimensions.SPACING_L)
	var identity := _panel()
	identity.add_theme_stylebox_override(&"panel", SHEET_THEME.get_stylebox(&"identity", &"PanelContainer"))
	_attributes_box.add_child(identity)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", NEDimensions.SPACING_L)
	identity.get_child(0).add_child(row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(NEDimensions.LIST_ROW_HEIGHT + NEDimensions.SPACING_XL, NEDimensions.LIST_ROW_HEIGHT + NEDimensions.SPACING_XL)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = data.get_portrait()
	row.add_child(portrait)
	if portrait.texture == null:
		var placeholder := Label.new()
		placeholder.text = "◯\n╱│╲"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_size_override(&"font_size", NETypography.SIZE_H1)
		portrait.add_child(placeholder)
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 2.0
	row.add_child(details)
	var traits := PackedStringArray()
	for feature in data.besonderheiten:
		traits.append(_enum_name(CharacterEnums.Besonderheit, feature))
	for text in ["Name: " + _title_label.text,
		"Ausbildung: " + _enum_name(CharacterEnums.Ausbildung, data.ausbildung),
		"Spezies: " + _enum_name(CharacterEnums.Spezies, data.spezies),
		"Herkunft: " + _enum_name(CharacterEnums.Herkunft, data.herkunft),
		"Ziel: " + (data.ziel if not data.ziel.is_empty() else "—"),
		"Besonderheiten: " + (", ".join(traits) if not traits.is_empty() else "—")]:
		_text(details, text)
	var points := VBoxContainer.new()
	points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(points)
	_points(points, "SP", data.staerkepunkte, data.get_staerkepunkte_basis(), "hp_fill")
	_points(points, "KP", data.konzentrationspunkte, data.get_konzentrationspunkte_basis(), "mp_fill")
	var xp := _text(points, "EP: %d" % data.erfahrungspunkte)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sections := {}
	for section in data.get_attribute_sections():
		sections[section.attribute] = section
	var order := [CharacterEnums.Attribute.KOERPERKRAFT, CharacterEnums.Attribute.GEWANDHEIT,
		CharacterEnums.Attribute.ROBUSTHEIT, CharacterEnums.Attribute.WILLENSKRAFT,
		CharacterEnums.Attribute.VERSTAND, CharacterEnums.Attribute.BEWUSSTSEIN]
	for index in range(0, order.size(), 2):
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", NEDimensions.SPACING_XL)
		_attributes_box.add_child(pair)
		pair.add_child(_build_attribute_section(sections[order[index]]))
		pair.add_child(_build_attribute_section(sections[order[index + 1]]))
	var presence := HBoxContainer.new()
	_attributes_box.add_child(presence)
	for index in 3:
		if index == 1:
			presence.add_child(_build_attribute_section(sections[CharacterEnums.Attribute.PRAESENZ]))
		else:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.size_flags_stretch_ratio = 0.5
			presence.add_child(spacer)
	var companions := PackedStringArray()
	for entry in data.begleiter:
		if entry:
			companions.append("%s, %s, %s" % [entry.name, entry.details, entry.befristung if not entry.befristung.is_empty() else "ohne Befristung"])
	_social("Begleiter", companions)
	var relationships := PackedStringArray()
	for entry in data.beziehungen:
		if entry:
			var target_name := entry.target_id
			if entry.target_type == RelationshipEntry.TargetType.CHARACTER:
				var target := GameState.character_registry.get_character(entry.target_id)
				if target and not target.character_name.is_empty():
					target_name = target.character_name
			relationships.append("%s, %+d%s" % [target_name, entry.wertung, " · " + entry.details if not entry.details.is_empty() else ""])
	_social("Beziehungen", relationships)


func _enum_name(values: Dictionary, value: int) -> String:
	return str(values.keys()[value]).capitalize().replace("Buergerlich", "Bürgerlich").replace("Feinfuehlig", "Feinfühlig")


func _text(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override(&"font_size", NETypography.SIZE_SMALL)
	parent.add_child(label)
	return label


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(StringName("margin_" + side), NEDimensions.PANEL_MARGIN)
	panel.add_child(margin)
	return panel


func _points(parent: Node, title: String, current: int, basis: int, fill: String) -> void:
	var label := _text(parent, "%s: %d / %d" % [title, current, basis])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, basis)
	bar.value = maxi(0, current)
	bar.show_percentage = false
	bar.custom_minimum_size.y = NEDimensions.PROGRESS_BAR_HEIGHT
	var style := load("res://src/ui/components/indicators/%s.tres" % fill).duplicate() as StyleBoxFlat
	if title == "KP":
		style.bg_color = NEColors.SUCCESS
	bar.add_theme_stylebox_override(&"fill", style)
	bar.tooltip_text = "%s: %d / %d" % [title, current, basis]
	parent.add_child(bar)


func _build_attribute_section(section: Dictionary) -> Control:
	var lines := PackedStringArray()
	for slot in section.skill_slots:
		lines.append("%s Level %d" % [slot.skill_name, slot.level] if slot else "—")
	var panel := _table("%s Level %d" % [section.attribute_name, section.attribute_value], lines)
	panel.tooltip_text = section.influence
	return panel


func _table(title: String, lines: PackedStringArray) -> Control:
	var panel := _panel()
	var margin := panel.get_child(0) as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(StringName("margin_" + side), NEDimensions.SPACING_XS)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	panel.get_child(0).add_child(box)
	var header := Label.new()
	header.theme_type_variation = &"SheetHeader"
	header.add_theme_font_size_override(&"font_size", NETypography.SIZE_BODY)
	header.text = title
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)
	for line in lines:
		_text(box, line)
	return panel


func _social(title: String, lines: PackedStringArray) -> void:
	if lines.is_empty():
		lines.append("—")
	_attributes_box.add_child(_table(title, lines))


func _clear_attributes() -> void:
	for child in _attributes_box.get_children():
		_attributes_box.remove_child(child)
		child.queue_free()


func _on_close_requested() -> void:
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.visible = false
