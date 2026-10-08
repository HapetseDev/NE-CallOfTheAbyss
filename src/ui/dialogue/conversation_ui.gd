extends Control

## Projektoberfläche für Dialogue Manager; ein END beendet nur den Gesprächszweig.
var system: DialogueSystem
var dialogue_resource: DialogueResource
var dialogue_line: DialogueLine
var temporary_game_states: Array = []
var entries: Array[Dictionary] = []
var left_speaker: Dictionary = {}
var right_speaker: Dictionary = {}
var busy := false
var _closed := false
var _history: VBoxContainer
var _scroll: ScrollContainer
var _option_scroll: ScrollContainer
var _options: HFlowContainer
var _end_button: Button
var _left: Dictionary
var _right: Dictionary

func _ready() -> void:
	add_to_group("ui_sound_window")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = NEColors.SCRIM
	scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scrim)
	var background := ColorRect.new()
	background.color = NEColors.BACKGROUND
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 0)
	add_child(columns)
	_left = _portrait_column(columns)
	var divider_left := ColorRect.new()
	divider_left.color = NEColors.BORDER
	divider_left.custom_minimum_size.x = NEDimensions.BORDER_WIDTH
	columns.add_child(divider_left)
	var middle := MarginContainer.new()
	middle.size_flags_horizontal = SIZE_EXPAND_FILL
	middle.size_flags_stretch_ratio = 3.0
	_margins(middle)
	columns.add_child(middle)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", NEDimensions.SPACING_M)
	middle.add_child(content)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll)
	_scroll.get_v_scroll_bar().changed.connect(_scroll_to_end)
	_history = VBoxContainer.new()
	_history.size_flags_horizontal = SIZE_EXPAND_FILL
	_history.add_theme_constant_override("separation", NEDimensions.SPACING_L)
	_scroll.add_child(_history)
	content.add_child(HSeparator.new())
	_option_scroll = ScrollContainer.new()
	_option_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_option_scroll.custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
	content.add_child(_option_scroll)
	_options = HFlowContainer.new()
	_options.size_flags_horizontal = SIZE_EXPAND_FILL
	_options.add_theme_constant_override("h_separation", NEDimensions.SPACING_S)
	_options.add_theme_constant_override("v_separation", NEDimensions.SPACING_S)
	_option_scroll.add_child(_options)
	_options.minimum_size_changed.connect(_update_options_height)
	_end_button = Button.new()
	_end_button.text = "Gespräch beenden"
	_end_button.custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
	_end_button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	_end_button.pressed.connect(close)
	content.add_child(_end_button)
	var divider_right := ColorRect.new()
	divider_right.color = NEColors.BORDER
	divider_right.custom_minimum_size.x = NEDimensions.BORDER_WIDTH
	columns.add_child(divider_right)
	_right = _portrait_column(columns)

func _margins(margin: MarginContainer) -> void:
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, NEDimensions.PANEL_MARGIN)

func _portrait_column(parent: Control) -> Dictionary:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 1.0
	_margins(margin)
	parent.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", NEDimensions.SPACING_S)
	margin.add_child(box)
	var frame := AspectRatioContainer.new()
	frame.ratio = 1.0
	frame.custom_minimum_size.y = NEDimensions.DIALOGUE_PORTRAIT_SIZE
	box.add_child(frame)
	var panel := PanelContainer.new()
	frame.add_child(panel)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(picture)
	var fallback := Label.new()
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.add_theme_font_size_override("font_size", NETypography.SIZE_DISPLAY)
	fallback.add_theme_color_override("font_color", NEColors.TEXT_SECONDARY)
	panel.add_child(fallback)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", NETypography.SIZE_H3)
	box.add_child(label)
	return {"picture": picture, "fallback": fallback, "name": label}

func start(resource: DialogueResource, title: String, context: Array) -> void:
	dialogue_resource = resource
	temporary_game_states = context.duplicate()
	_set_portrait(system.speaker_for("npc"), false)
	_set_portrait(system.speaker_for("player"), true)
	await next(title)

func next(next_id: String) -> void:
	if busy or _closed:
		return
	busy = true
	_end_button.disabled = true
	_clear_options()
	var line: DialogueLine = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)
	if _closed or not is_inside_tree():
		return
	dialogue_line = line
	if line:
		_append_line(line)
		for concurrent in line.concurrent_lines:
			_append_line(concurrent)
	busy = false
	_end_button.disabled = false
	if line == null:
		_show_topics()
	elif not line.responses.is_empty():
		for response: DialogueResponse in line.responses:
			if response.is_allowed:
				_button(response.text, _choose.bind(response))
	else:
		_button("Weiter", next.bind(line.next_id))
	_focus_first()
	_scroll_to_end.call_deferred()

func _append_line(line: DialogueLine) -> void:
	var key := line.get_tag_value("subject")
	var speaker := system.speaker_for(key if not key.is_empty() else line.character)
	_append_entry(speaker, line.text, line)

func _append_entry(speaker: Dictionary, text: String, line: DialogueLine = null) -> void:
	if not speaker.name.is_empty():
		_set_portrait(speaker, speaker.party)
	if not entries.is_empty() and entries[-1].speaker == speaker.name and entries[-1].text == text:
		return
	entries.append({"speaker": speaker.name, "party": speaker.party, "text": text})
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", NEDimensions.SPACING_S)
	_history.add_child(block)
	if not speaker.name.is_empty():
		var heading := Label.new()
		heading.text = speaker.name
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if speaker.party else HORIZONTAL_ALIGNMENT_LEFT
		heading.add_theme_font_size_override("font_size", NETypography.SIZE_H1)
		block.add_child(heading)
	var body := DialogueLabel.new() if line else RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_theme_font_size_override("normal_font_size", NETypography.SIZE_BODY)
	block.add_child(body)
	if line:
		body.dialogue_line = line
		body.skip_typing()
	body.text = ("[right]" + text + "[/right]") if speaker.party else text

func _set_portrait(speaker: Dictionary, party_side: bool) -> void:
	if party_side:
		right_speaker = speaker
	else:
		left_speaker = speaker
	var widgets := _right if party_side else _left
	widgets.picture.texture = speaker.portrait
	widgets.fallback.visible = speaker.portrait == null
	widgets.fallback.text = speaker.name.left(1).to_upper() if not speaker.name.is_empty() else "?"
	widgets.picture.tooltip_text = "Porträt von " + speaker.name if speaker.portrait else "Für %s ist noch kein Porträt hinterlegt." % speaker.name
	widgets.name.text = speaker.name

func _choose(response: DialogueResponse) -> void:
	if busy or _closed or not response.is_allowed:
		return
	_append_entry(system.speaker_for("player"), response.text)
	await next(response.next_id)

func _show_topics() -> void:
	for option: Dictionary in system.conversation_options(dialogue_resource):
		_button(option.label, _topic.bind(option))

func _topic(option: Dictionary) -> void:
	if busy or _closed:
		return
	# Revalidate knowledge/defeat conditions at click time.
	if not option in system.conversation_options(dialogue_resource):
		return
	if option.has("title"):
		_append_entry(system.speaker_for("player"), option.label)
		await next(option.title)
	elif option.action == "trade":
		system.open_shop(system.current_data.shop_id)
	elif option.action == "fight":
		system.start_encounter(system.current_data.encounter_id)

func _button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(NEDimensions.BUTTON_MIN_WIDTH, NEDimensions.BUTTON_HEIGHT)
	button.pressed.connect(callback)
	_options.add_child(button)

func _clear_options() -> void:
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()

func _focus_first() -> void:
	if _options.get_child_count() > 0:
		_options.get_child(0).grab_focus()
	else:
		_end_button.grab_focus()

func _scroll_to_end() -> void:
	if is_inside_tree():
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func close() -> void:
	if not busy and not _closed:
		system.finish_conversation()

func dismiss() -> void:
	_closed = true
	hide()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
	get_viewport().set_input_as_handled()


func _update_options_height() -> void:
	_option_scroll.custom_minimum_size.y = clampf(_options.get_combined_minimum_size().y, NEDimensions.BUTTON_HEIGHT, NEDimensions.BUTTON_HEIGHT * 3 + NEDimensions.SPACING_S * 2)
