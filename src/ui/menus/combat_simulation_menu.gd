extends Control

const Simulation := preload("res://src/debug/simulation/combat_text_simulation.gd")
const ATTRIBUTE_KEYS := ["koerperkraft", "gewandheit", "robustheit", "willenskraft", "verstand", "bewusstsein", "praesenz"]
const ATTACKS := ["Schlag", "Messer – Stechen", "Messer – Werfen", "Stein – Schlagen", "Stein – Werfen", "Eigener Gegenstand", "Feuerstoß (Magiekunde nötig)"]
var fighters: Array[Dictionary] = []
var _definitions: Array[SkillDefinition] = []
var _seed: SpinBox
var _count: SpinBox
var _log: TextEdit
var _status: Label
var _simulation: CombatTextSimulation
var _generation := 0
var _running := false
var _run_button: Button
var _step_button: Button
var _series_button: Button

func _ready() -> void:
	add_to_group("ui_sound_window")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = NEColors.SCRIM
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, NEDimensions.PANEL_MARGIN)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", NEDimensions.SPACING_S)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := _label(header, "Charakter- und Kampfsimulation")
	heading.add_theme_font_size_override("font_size", NETypography.SIZE_H1)
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	_button(header, "Zurück zum Hauptmenü", _close)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var editor := ScrollContainer.new()
	editor.name = "Charaktere"
	editor.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(editor)
	var columns := BoxContainer.new()
	columns.size_flags_horizontal = SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", NEDimensions.SPACING_L)
	editor.add_child(columns)
	columns.resized.connect(func() -> void: columns.vertical = columns.size.x < NEDimensions.BUTTON_MIN_WIDTH * 6)
	_definitions = SkillCatalog.get_all_definitions()
	_definitions.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool: return a.skill_name < b.skill_name)
	_build_fighter(columns, "dannerman", 0)
	_build_fighter(columns, "shalka", 1)
	_log = TextEdit.new()
	_log.name = "Kampfprotokoll"
	_log.editable = false
	_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	tabs.add_child(_log)
	var controls := HFlowContainer.new()
	layout.add_child(controls)
	_label(controls, "Zufallsstart")
	_seed = _spin(controls, 1, 0, 1000000000)
	_label(controls, "Kämpfe")
	_count = _spin(controls, 100, 1, 500)
	_run_button = _button(controls, "Einzelkampf", _run_match.bind(tabs))
	_step_button = _button(controls, "Nächste Aktion", _step.bind(tabs))
	_series_button = _button(controls, "Serie vergleichen", _run_series.bind(tabs))
	_button(controls, "Zurücksetzen / Abbrechen", _reset)
	_status = _label(layout, "Charaktere einstellen, dann Einzelkampf oder Serie starten. Änderungen setzen den Schrittverlauf zurück.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var limits := _label(layout, "Aktuelle Spielregeln: Talentstufen erhöhen Attribute. Stärke 0 ist kein Tod. Freie Sicht; sofortige Züge; keine Bewegung, Flucht oder Heilstrategie. Talentstufen bis 30 sind Testwerte, kein neues Spiellimit. Bei gleicher Initiative handelt A zuerst.")
	limits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	limits.add_theme_color_override("font_color", NEColors.TEXT_SECONDARY)
	_seed.value_changed.connect(func(_v: float) -> void: _invalidate())
	for i in fighters.size():
		_refresh_fighter(i)
	_run_button.grab_focus()

func _label(parent: Node, text: String) -> Label:
	var result := Label.new()
	result.text = text
	parent.add_child(result)
	return result

func _button(parent: Node, text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func _spin(parent: Node, value: float, minimum: float, maximum: float) -> SpinBox:
	var result := SpinBox.new()
	result.min_value = minimum
	result.max_value = maximum
	result.value = value
	result.custom_minimum_size.x = NEDimensions.BUTTON_MIN_WIDTH
	parent.add_child(result)
	return result

func _build_fighter(parent: Node, template_id: String, index: int) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, NEDimensions.PANEL_MARGIN)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", NEDimensions.SPACING_S)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_label(header, "Figur %s" % ("A" if index == 0 else "B"))
	var name_edit := LineEdit.new()
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(name_edit)
	var templates := OptionButton.new()
	for title in ["Dannerman", "Shalka", "Leere Testfigur"]:
		templates.add_item(title)
	header.add_child(templates)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var attributes: Dictionary = {}
	for i in ATTRIBUTE_KEYS.size():
		_label(grid, CharacterEnums.attribute_name(i))
		attributes[ATTRIBUTE_KEYS[i]] = _spin(grid, 1, 0, 100)
	var talent_row := HBoxContainer.new()
	box.add_child(talent_row)
	var talent := OptionButton.new()
	talent.fit_to_longest_item = false
	talent.clip_text = true
	talent.size_flags_horizontal = SIZE_EXPAND_FILL
	for definition in _definitions:
		talent.add_item("%s (%s)" % [definition.skill_name, CharacterEnums.attribute_name(definition.attribute)])
	talent_row.add_child(talent)
	var level := _spin(talent_row, 1, 0, 30)
	_button(talent_row, "Talent setzen (0 entfernt)", _set_skill.bind(index))
	var learned := ItemList.new()
	learned.custom_minimum_size.y = NEDimensions.LIST_ROW_HEIGHT * 2
	box.add_child(learned)
	var row := HBoxContainer.new()
	box.add_child(row)
	_label(row, "Angriff")
	var attack := OptionButton.new()
	for title in ATTACKS:
		attack.add_item(title)
	row.add_child(attack)
	var item_grid := GridContainer.new()
	item_grid.columns = 2
	box.add_child(item_grid)
	_label(item_grid, "Kampfwert eigener Gegenstand")
	var power := _spin(item_grid, 1, 1, 100)
	_label(item_grid, "Passendes Talent eigener Gegenstand")
	var item_skill := OptionButton.new()
	item_skill.fit_to_longest_item = false
	item_skill.clip_text = true
	item_skill.add_item("Kein Talent")
	for definition in _definitions:
		item_skill.add_item(definition.skill_name)
	item_grid.add_child(item_skill)
	_label(item_grid, "Bruchchance (%)")
	var break_chance := _spin(item_grid, 0, 0, 100)
	var armored := CheckBox.new()
	armored.text = "Gerüstet (Übergangsregel: ganze Figur)"
	box.add_child(armored)
	armored.toggled.connect(func(_value: bool) -> void: _invalidate())
	var summary := _label(box, "")
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fighters.append({"name": name_edit, "attributes": attributes, "skills": {}, "talent": talent, "level": level, "learned": learned, "attack": attack, "power": power, "item_skill": item_skill, "break": break_chance, "summary": summary, "armored": armored})
	for spin: SpinBox in attributes.values():
		spin.value_changed.connect(func(_v: float) -> void: _refresh_fighter(index); _invalidate())
	for spin: SpinBox in [power, break_chance]:
		spin.value_changed.connect(func(_v: float) -> void: _invalidate())
	name_edit.text_changed.connect(func(_text: String) -> void: _invalidate())
	attack.item_selected.connect(func(_selected: int) -> void: _invalidate())
	item_skill.item_selected.connect(func(_selected: int) -> void: _invalidate())
	learned.item_selected.connect(func(selected: int) -> void:
		var id: String = learned.get_item_metadata(selected)
		for j in _definitions.size():
			if _definitions[j].skill_id == id:
				talent.select(j)
				level.value = fighters[index].skills[id])
	templates.item_selected.connect(func(selected: int) -> void:
		_load_template(index, ["dannerman", "shalka", ""][selected]))
	templates.select(index)
	_load_template(index, template_id)

func _load_template(index: int, id: String) -> void:
	var sheet := CharacterSheetFactory.load_sheet(id) if not id.is_empty() else CharacterResource.new()
	var fighter := fighters[index]
	fighter.name.text = sheet.character_name if not id.is_empty() else "Testfigur %s" % ("A" if index == 0 else "B")
	for key in ATTRIBUTE_KEYS:
		fighter.attributes[key].set_value_no_signal(sheet.get(key))
	fighter.skills.clear()
	for skill in sheet.learned_skills:
		fighter.skills[skill.skill_id] = skill.level
	fighter.attack.select(1 if id == "dannerman" else 0)
	fighter.armored.set_pressed_no_signal(false)
	_refresh_fighter(index)
	_invalidate()

func _set_skill(index: int) -> void:
	var fighter := fighters[index]
	var id := _definitions[fighter.talent.selected].skill_id
	if fighter.level.value == 0:
		fighter.skills.erase(id)
	else:
		fighter.skills[id] = int(fighter.level.value)
	_refresh_fighter(index)
	_invalidate()

func _sheet(index: int) -> CharacterResource:
	var fighter := fighters[index]
	var sheet := CharacterResource.new()
	sheet.character_name = fighter.name.text.strip_edges()
	if sheet.character_name.is_empty():
		sheet.character_name = "Figur %s" % ("A" if index == 0 else "B")
	for key in ATTRIBUTE_KEYS:
		sheet.set(key, int(fighter.attributes[key].value))
	for id in fighter.skills:
		var skill := LearnedSkill.new()
		skill.skill_id = id
		skill.level = fighter.skills[id]
		sheet.learned_skills.append(skill)
	return sheet

func _refresh_fighter(index: int) -> void:
	var fighter := fighters[index]
	var sheet := _sheet(index)
	fighter.learned.clear()
	for definition in _definitions:
		if fighter.skills.has(definition.skill_id):
			var position: int = fighter.learned.add_item("%s: %d" % [definition.skill_name, fighter.skills[definition.skill_id]])
			fighter.learned.set_item_metadata(position, definition.skill_id)
	fighter.summary.text = "Effektive KK %d · GW %d · RB %d · Stärke %d (Tod bei %d) · Konzentration %d · Tragkraft %.0f" % [sheet.get_effective_attribute(CharacterEnums.Attribute.KOERPERKRAFT), sheet.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT), sheet.get_effective_attribute(CharacterEnums.Attribute.ROBUSTHEIT), sheet.get_staerkepunkte_basis(), -sheet.get_staerkepunkte_basis(), sheet.get_konzentrationspunkte_basis(), sheet.get_max_carry_weight()]

func _options(index: int) -> Dictionary:
	var fighter := fighters[index]
	var choice: int = fighter.attack.selected
	var result := {"item_path": "", "ability_id": "fausthieb", "break_chance": fighter.break.value / 100.0, "armored": fighter.armored.button_pressed}
	if choice in [1, 2]:
		result.item_path = "res://src/resources/items/messer.tres"
		result.mode_index = choice - 1
	elif choice in [3, 4]:
		result.item_path = "res://src/resources/items/stein.tres"
		result.mode_index = choice - 3
	elif choice == 5:
		result.item_path = "custom"
		result.combat_value = int(fighter.power.value)
		result.skill_id = _definitions[fighter.item_skill.selected - 1].skill_id if fighter.item_skill.selected > 0 else ""
	elif choice == 6:
		result.ability_id = "magie_feuerstoss"
	return result

func _new_simulation(random_seed: int) -> CombatTextSimulation:
	var result := Simulation.new()
	result.setup([_sheet(0), _sheet(1)], [_options(0), _options(1)], random_seed)
	return result

func _invalidate() -> void:
	_generation += 1
	if _running:
		_set_running(false)
	if _simulation:
		_simulation.cleanup()
		_simulation = null

func _reset() -> void:
	_invalidate()
	_log.text = ""
	_status.text = "Zurückgesetzt. Charakterdefinitionen bleiben erhalten."
	_set_running(false)

func _set_running(value: bool) -> void:
	_running = value
	for button in [_run_button, _step_button, _series_button]:
		button.disabled = value

func _run_match(tabs: TabContainer) -> void:
	_invalidate()
	_simulation = _new_simulation(int(_seed.value))
	var result := _simulation.run()
	_log.text = result.log
	_status.text = "Einzelkampf: %d Aktionen, %.2f simulierte Sekunden. %s" % [result.turns, result.seconds, result.limit_reason]
	tabs.current_tab = 1

func _step(tabs: TabContainer) -> void:
	if _simulation == null:
		_simulation = _new_simulation(int(_seed.value))
	_simulation.step()
	_log.text = "\n".join(_simulation.lines)
	_status.text = "%d Aktionen · %.2f simulierte Sekunden%s" % [_simulation.turns, _simulation.elapsed, " · beendet" if _simulation.done else ""]
	tabs.current_tab = 1

func _run_series(tabs: TabContainer) -> void:
	_invalidate()
	var generation := _generation
	_set_running(true)
	tabs.current_tab = 1
	var wins := [0, 0]
	var draws := 0
	var total_turns := 0
	var total_seconds := 0.0
	var total_damage := [0, 0]
	var total_dodges := [0, 0]
	var count := int(_count.value)
	var base_seed := int(_seed.value)
	for i in count:
		if generation != _generation:
			return
		var simulation := _new_simulation(base_seed + i)
		var result := simulation.run()
		if result.winner < 0:
			draws += 1
		else:
			wins[result.winner] += 1
		total_turns += result.turns
		total_seconds += result.seconds
		for j in 2:
			total_damage[j] += result.damage[j]
			total_dodges[j] += result.dodges[j]
		_log.text = result.log
		simulation.cleanup()
		_status.text = "Serie: %d / %d" % [i + 1, count]
		if i % 5 == 0:
			await get_tree().process_frame
			if not is_inside_tree():
				return
	_set_running(false)
	_status.text = "%d Kämpfe: %s %d Siege (%.1f%%), %s %d Siege (%.1f%%), %d ohne Sieger. Ø %.1f Aktionen, %.2f Sekunden. Schaden A/B: %d/%d; Ausweichen A/B: %d/%d. Protokoll: letzter Kampf." % [count, _sheet(0).character_name, wins[0], 100.0 * wins[0] / count, _sheet(1).character_name, wins[1], 100.0 * wins[1] / count, draws, float(total_turns) / count, total_seconds / count, total_damage[0], total_damage[1], total_dodges[0], total_dodges[1]]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	_generation += 1
	queue_free()

func _exit_tree() -> void:
	_invalidate()
