class_name DebugCharacterSheetEditor extends Control

signal closed

const _SheetFactory = preload("res://src/gameplay/character/character_sheet_factory.gd")

var _playables: Array[Playable] = []
var _selected: Playable

@onready var _title_label: Label = %TitleLabel
@onready var _character_select: OptionButton = %CharacterSelect
@onready var _summary_label: Label = %SummaryLabel
@onready var _attributes_box: VBoxContainer = %AttributesBox
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_character_select.item_selected.connect(_on_character_selected)


func open(focus: Playable = null) -> void:
	_playables = DebugMenu.find_all_playables(get_tree().current_scene)
	_populate_character_select(focus)
	_refresh()


func _populate_character_select(focus: Playable) -> void:
	_character_select.clear()
	var focus_index := 0
	for i in _playables.size():
		var playable := _playables[i]
		_character_select.add_item(playable.get_display_name(), i)
		if focus != null and playable == focus:
			focus_index = i
	if _playables.is_empty():
		_character_select.add_item("(Kein Charakter)", -1)
		_selected = null
		return
	_character_select.select(focus_index)
	_selected = _playables[focus_index]


func _on_character_selected(index: int) -> void:
	var id := _character_select.get_item_id(index)
	if id < 0 or id >= _playables.size():
		_selected = null
	else:
		_selected = _playables[id]
	_refresh()


func _refresh() -> void:
	_clear_attributes()
	if _selected == null:
		_summary_label.text = "Kein Charakter ausgewählt."
		return

	_ensure_sheet(_selected)
	var data := _selected.character
	if data == null:
		_summary_label.text = "Kein Charakter vorhanden."
		return

	_title_label.text = "Debug: %s" % data.character_name
	_summary_label.text = "SP %d / %d  ·  KP %d / %d  ·  EP %d" % [
		data.staerkepunkte,
		data.get_staerkepunkte_basis(),
		data.konzentrationspunkte,
		data.get_konzentrationspunkte_basis(),
		data.erfahrungspunkte,
	]

	for section in data.get_attribute_sections():
		_attributes_box.add_child(_build_attribute_editor(section, data))


func _ensure_sheet(playable: Playable) -> void:
	if playable.character != null:
		return
	playable.bind_character(_SheetFactory.create_default(playable.get_display_name()), false)


func _build_attribute_editor(section: Dictionary, data: CharacterResource) -> Control:
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

	var attr: CharacterEnums.Attribute = section["attribute"]
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var header := Label.new()
	header.text = "%s  (effektiv %d)" % [section["attribute_name"], section["attribute_value"]]
	header.add_theme_font_size_override(&"font_size", 15)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	var base_label := Label.new()
	base_label.text = "Basis:"
	header_row.add_child(base_label)

	var base_spin := SpinBox.new()
	base_spin.min_value = 0
	base_spin.max_value = 99
	base_spin.value = data.get_base_attribute(attr)
	base_spin.value_changed.connect(_on_base_attribute_changed.bind(data, attr))
	header_row.add_child(base_spin)

	var influence := Label.new()
	influence.text = section["influence"]
	influence.add_theme_font_size_override(&"font_size", 11)
	influence.add_theme_color_override(&"font_color", Color(0.7, 0.73, 0.78))
	vbox.add_child(influence)

	var learned := data.get_learned_skills_for_attribute(attr)
	for learned_skill in learned:
		vbox.add_child(_build_skill_row(data, learned_skill))

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override(&"separation", 8)
	vbox.add_child(add_row)

	var add_select := OptionButton.new()
	add_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var unlearned: Array[SkillDefinition] = data.get_unlearned_talents_for_attribute(attr)
	if unlearned.is_empty() or learned.size() >= CharacterEnums.FAEHIGKEITEN_PRO_ATTRIBUT:
		add_select.add_item("(Kein Talent verfügbar)", -1)
		add_select.disabled = true
	else:
		add_select.add_item("Talent hinzufügen…", -1)
		for i in unlearned.size():
			add_select.add_item(unlearned[i].skill_name, i)
	add_row.add_child(add_select)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.disabled = add_select.disabled
	if not add_select.disabled:
		add_btn.pressed.connect(_on_add_talent_pressed.bind(data, attr, add_select, unlearned))
	add_row.add_child(add_btn)

	return panel


func _build_skill_row(data: CharacterResource, learned: LearnedSkill) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

	var definition := SkillCatalog.get_definition(learned.skill_id)
	var name_label := Label.new()
	name_label.text = definition.skill_name if definition else learned.skill_id
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var level_spin := SpinBox.new()
	level_spin.min_value = 0
	level_spin.max_value = data.get_skill_level_cap(learned.skill_id)
	level_spin.value = learned.level
	level_spin.value_changed.connect(_on_skill_level_changed.bind(data, learned.skill_id))
	row.add_child(level_spin)

	var remove_btn := Button.new()
	remove_btn.text = "−"
	remove_btn.pressed.connect(_on_remove_skill_pressed.bind(data, learned.skill_id))
	row.add_child(remove_btn)

	return row


func _on_base_attribute_changed(data: CharacterResource, attr: CharacterEnums.Attribute, value: float) -> void:
	data.debug_set_base_attribute(attr, int(value))
	_refresh()


func _on_skill_level_changed(data: CharacterResource, skill_id: String, value: float) -> void:
	data.debug_set_skill_level(skill_id, int(value))
	_refresh()


func _on_remove_skill_pressed(data: CharacterResource, skill_id: String) -> void:
	data.debug_remove_skill(skill_id)
	_refresh()


func _on_add_talent_pressed(
	data: CharacterResource,
	attr: CharacterEnums.Attribute,
	add_select: OptionButton,
	unlearned: Array[SkillDefinition]
) -> void:
	var pick_index := add_select.selected
	if pick_index <= 0 or pick_index - 1 >= unlearned.size():
		return
	var definition := unlearned[pick_index - 1]
	if data.debug_add_skill(definition.skill_id, 1):
		_refresh()


func _clear_attributes() -> void:
	for child in _attributes_box.get_children():
		child.queue_free()


func _on_close_pressed() -> void:
	closed.emit()
