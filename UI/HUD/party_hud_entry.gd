class_name PartyHudEntry extends HBoxContainer

const PORTRAIT_SIZE := Vector2(52, 52)

var member: Playable
var _name_label: Label
var _hp_label: Label
var _hp_bar: ProgressBar
var _mp_label: Label
var _mp_bar: ProgressBar


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	custom_minimum_size.y = 72.0

	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = PORTRAIT_SIZE
	add_child(portrait_panel)

	var portrait := ColorRect.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.color = Color(0.35, 0.38, 0.45, 1.0)
	portrait_panel.add_child(portrait)

	var portrait_label := Label.new()
	portrait_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_label.text = "?"
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.add_theme_font_size_override(&"font_size", 22)
	portrait_panel.add_child(portrait_label)

	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override(&"separation", 4)
	add_child(stats)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override(&"font_size", 14)
	stats.add_child(_name_label)

	_hp_label = _make_stat_caption("HP")
	stats.add_child(_hp_label)
	_hp_bar = _make_stat_bar(Color(0.75, 0.2, 0.2))
	stats.add_child(_hp_bar)

	_mp_label = _make_stat_caption("MP")
	stats.add_child(_mp_label)
	_mp_bar = _make_stat_bar(Color(0.2, 0.35, 0.85))
	stats.add_child(_mp_bar)


func _make_stat_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 11)
	label.add_theme_color_override(&"font_color", Color(0.75, 0.78, 0.82))
	return label


func _make_stat_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(110, 16)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override(&"fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.14, 0.9)
	bar.add_theme_stylebox_override(&"background", bg)
	return bar


func bind(playable: Playable) -> void:
	member = playable
	if member:
		_name_label.text = member.get_display_name()
	refresh()


func refresh() -> void:
	if member == null:
		return
	_hp_bar.max_value = member.max_health
	_hp_bar.value = member.health
	_hp_label.text = "HP %d / %d" % [member.health, member.max_health]
	_mp_bar.max_value = member.max_mana
	_mp_bar.value = member.mana
	_mp_label.text = "MP %d / %d" % [member.mana, member.max_mana]
