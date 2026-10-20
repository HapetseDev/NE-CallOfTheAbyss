class_name InventoryUI extends Control

var embedded := false
var playable: Playable
var party: Party

var _inv_slots: Array[Button] = []
var _equip_buttons: Dictionary = {}

var _inv: InventoryComponent
var _actions: PopupMenu
var _action_index := -1
var _action_slot := ""
var _slot_candidates: Dictionary = {}
var _selected_item: ItemData
var _action_item: ItemData
var _recipients: Array[Playable] = []

@onready var _overlay: ColorRect = %Overlay
@onready var _window: Window = %Window
var _inv_grid: GridContainer
var _quick_grid: GridContainer
var _weight_label: Label
var _name_label: Label
var _portrait: TextureRect
var _paperdoll: TextureRect
var _paperdoll_hint: Label
var _stats: Label
var _more_info: Label
var _content: VBoxContainer
var _upper: BoxContainer
var _equipment: HBoxContainer

func _ready() -> void:
	_overlay.inventory_ui = self
	_window.close_requested.connect(_on_close_requested)
	_build_layout()
	visibility_changed.connect(_on_visibility_changed)

func _box(parent: Node, horizontal: bool = false) -> BoxContainer:
	var box: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	box.add_theme_constant_override("separation", NEDimensions.SPACING_M)
	parent.add_child(box)
	return box

func _label(parent: Node, text: String, font_size: int = NETypography.SIZE_BODY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _picture(parent: Node, minimum: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.custom_minimum_size = minimum
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func _section(parent: Node, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, NEDimensions.PANEL_MARGIN)
	panel.add_child(margin)
	var box := _box(margin)
	var heading := preload("res://src/ui/components/panels/ne_section_header.tscn").instantiate()
	heading.text = title
	box.add_child(heading)
	return box

func _build_layout() -> void:
	_content = $Window/MarginContainer/VBoxContainer
	var header := _box(_content, true)
	_portrait = _picture(header, Vector2.ONE * NEDimensions.INVENTORY_PORTRAIT_SIZE)
	var identity := _box(header)
	identity.size_flags_horizontal = SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_label = _label(identity, "", NETypography.SIZE_H1)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weight_label = _label(identity, "")
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upper = BoxContainer.new()
	_upper.add_theme_constant_override("separation", NEDimensions.SPACING_M)
	_content.add_child(_upper)
	_equipment = _box(_upper, true) as HBoxContainer
	_equipment.size_flags_horizontal = SIZE_EXPAND_FILL
	var left := _box(_equipment)
	left.size_flags_vertical = SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	_make_equipment_slot(left, "schmuck", "Schmuck")
	_make_equipment_slot(left, "primaer_hand", "Rechte Hand")
	_make_equipment_slot(left, "beine", "Beine")
	var center := _box(_equipment)
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	_make_equipment_slot(center, "kopf", "Kopf")
	_paperdoll = _picture(center, Vector2(NEDimensions.PAPERDOLL_WIDTH, NEDimensions.PAPERDOLL_HEIGHT))
	_paperdoll.size_flags_horizontal = SIZE_EXPAND_FILL
	_paperdoll_hint = _label(center, "Paperdoll noch nicht vorhanden", NETypography.SIZE_SMALL)
	_paperdoll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var right := _box(_equipment)
	right.size_flags_vertical = SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	_make_equipment_slot(right, "rumpf", "Brust")
	_make_equipment_slot(right, "nebenhand", "Linke Hand")
	_make_equipment_slot(right, "fuesse", "Füße")
	var details := _box(_upper)
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	details.custom_minimum_size.x = NEDimensions.INVENTORY_DETAILS_WIDTH
	var stats_scroll := ScrollContainer.new()
	stats_scroll.custom_minimum_size.y = NEDimensions.INVENTORY_SLOT_SIZE
	stats_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_section(details, "Stats des Gegenstands").add_child(stats_scroll)
	_stats = _label(stats_scroll, "Gegenstand auswählen.")
	_stats.size_flags_horizontal = SIZE_EXPAND_FILL
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.size_flags_vertical = SIZE_EXPAND_FILL
	_more_info = _label(_section(details, "Weitere Infos"), "")
	_more_info.custom_minimum_size.y = NEDimensions.INVENTORY_PORTRAIT_SIZE
	_label(_content, "Schnellausrüstung", NETypography.SIZE_H3)
	_quick_grid = GridContainer.new()
	_quick_grid.columns = Inventory.QUICK_EQUIPMENT_SLOTS.size()
	_quick_grid.add_theme_constant_override("h_separation", NEDimensions.SPACING_S)
	_quick_grid.add_theme_constant_override("v_separation", NEDimensions.SPACING_S)
	_content.add_child(_quick_grid)
	for i in Inventory.QUICK_EQUIPMENT_SLOTS.size():
		_make_equipment_slot(_quick_grid, Inventory.QUICK_EQUIPMENT_SLOTS[i], str(i + 1))
	_label(_content, "Rucksack", NETypography.SIZE_H3)
	_inv_grid = GridContainer.new()
	_inv_grid.columns = 9
	_inv_grid.add_theme_constant_override("h_separation", NEDimensions.SPACING_S)
	_inv_grid.add_theme_constant_override("v_separation", NEDimensions.SPACING_S)
	_content.add_child(_inv_grid)
	var hint := _label(_content, "Auswählen: Aktionen · Ziehen: ausrüsten, verstauen oder an ein Partymitglied geben", NETypography.SIZE_SMALL)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", NEColors.TEXT_SECONDARY)
	_content.resized.connect(_layout_inventory)
	_layout_inventory.call_deferred()

func _make_equipment_slot(parent: Node, key: String, title: String) -> void:
	var box := _box(parent)
	box.add_theme_constant_override("separation", NEDimensions.SPACING_XS)
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	var label := _label(box, title, NETypography.SIZE_SMALL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var button := Button.new()
	button.set_script(preload("res://src/ui/inventory/equip_slot_button.gd"))
	button.set_meta("slot_key", key)
	button.inventory_ui = self
	button.custom_minimum_size = Vector2.ONE * NEDimensions.INVENTORY_SLOT_SIZE
	button.size_flags_horizontal = SIZE_SHRINK_CENTER
	button.clip_text = true
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", NEDimensions.ICON_SIZE_L)
	button.add_theme_font_size_override("font_size", NETypography.SIZE_SMALL)
	button.pressed.connect(_on_equip_pressed.bind(key))
	button.mouse_entered.connect(_inspect_equipment.bind(key))
	button.focus_entered.connect(_inspect_equipment.bind(key))
	box.add_child(button)
	_equip_buttons[key] = button

func _layout_inventory() -> void:
	if not _content:
		return
	var width := _content.size.x
	if embedded and get_parent() is GameWindows:
		width = get_parent().get_content_width()
	var narrow := width < NEDimensions.PAPERDOLL_WIDTH + NEDimensions.INVENTORY_SLOT_SIZE * 2 + NEDimensions.INVENTORY_DETAILS_WIDTH + NEDimensions.SPACING_M * 4
	if _upper.vertical != narrow:
		_upper.vertical = narrow
		if embedded and get_parent() is GameWindows:
			get_parent()._layout.call_deferred()
	var columns := clampi(int((width + NEDimensions.SPACING_S) / (NEDimensions.INVENTORY_SLOT_SIZE + NEDimensions.SPACING_S)), 1, 9)
	_inv_grid.columns = columns
	_quick_grid.columns = columns

func _inspect_equipment(key: String) -> void:
	if playable:
		_inspect_item(playable.equipment.get(key) as ItemData)

func _inspect_inventory(index: int) -> void:
	if playable and index >= 0 and index < playable.inventory.size():
		_inspect_item(playable.inventory[index].item)

func _inspect_item(item: ItemData) -> void:
	_selected_item = item
	if item == null:
		_stats.text = "Gegenstand auswählen."
		return
	var lines: PackedStringArray = [item.item_name, "Gewicht: %.2f" % item.weight]
	if item.is_armor:
		lines.append("Rüstung")
	if item.get_combat_value() > 1:
		lines.append("Kampfwert: %d" % item.get_combat_value())
	if not item.description.is_empty():
		lines.append(item.description)
	if item.heal_amount != 0:
		lines.append("Stärkepunkte: %+d" % item.heal_amount)
	if item.mana_amount != 0:
		lines.append("Konzentrationspunkte: %+d" % item.mana_amount)
	for mode in item.usage_modes:
		if mode:
			var value_text := " · Kampfwert %d" % item.get_combat_value(mode) if item.get_combat_value(mode) > 1 else ""
			lines.append("%s%s · %s" % [mode.label, value_text, "Fernkampf" if mode.range_type == ItemUsageMode.RangeType.THROWN else "Nahkampf"])
	_stats.text = "\n".join(lines)


func bind_player(playable_ref: Playable, party_ref: Party) -> void:
	if is_instance_valid(_inv) and _inv.changed.is_connected(_refresh):
		_inv.changed.disconnect(_refresh)
	playable = playable_ref
	party = party_ref
	if embedded and get_parent() is GameWindows:
		var stage: Control = get_parent()._stage
		if not stage.resized.is_connected(_layout_inventory):
			stage.resized.connect(_layout_inventory)
	if playable:
		playable._ensure_inventory_component()
		_inv = playable.inventory_component
		_inv.changed.connect(_refresh)
		_refresh()


func _on_visibility_changed() -> void:
	if not is_node_ready() or embedded:
		return
	if is_visible_in_tree():
		_window.visible = true
		_window.grab_focus()
	else:
		_window.visible = false


func drop_item_from_slot(index: int) -> void:
	if playable == null or index < 0 or index >= playable.inventory.size():
		return
	var slot := playable.inventory[index]
	if slot == null or slot.item == null:
		return
	playable.drop_item_to_world(slot.item)


func _on_close_requested() -> void:
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.visible = false


func _refresh() -> void:
	if not playable:
		return

	while _inv_slots.size() < maxi(18, playable.inventory.size()):
		var button := preload("res://src/ui/inventory/inventory_slot_button.tscn").instantiate() as Button
		button.inventory_ui = self
		button.slot_index = _inv_slots.size()
		button.pressed.connect(_open_actions.bind(button.slot_index))
		button.gui_input.connect(_slot_input.bind(button.slot_index))
		button.mouse_entered.connect(_inspect_inventory.bind(button.slot_index))
		button.focus_entered.connect(_inspect_inventory.bind(button.slot_index))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", NEDimensions.ICON_SIZE_L)
		button.add_theme_font_size_override("font_size", NETypography.SIZE_SMALL)
		_inv_grid.add_child(button)
		_inv_slots.append(button)
	_weight_label.text = "Tragkraft: %.1f / %.1f" % [playable.get_total_weight(), playable.get_max_carry_weight()]

	_name_label.text = playable.get_display_name()
	if playable.character:
		_portrait.texture = playable.character.get_portrait()
		_paperdoll.texture = playable.character.get_paperdoll()
		_paperdoll_hint.visible = _paperdoll.texture == null

	for i in _inv_slots.size():
		var btn := _inv_slots[i]
		if i < playable.inventory.size():
			var slot := playable.inventory[i]
			if slot != null and slot.item is ItemData:
				var item: ItemData = slot.item
				var label := "%s\nx%d" % [item.item_name, slot.count] if item.max_stack > 1 else item.item_name
				var can_equip := not item.consumable and not item.equipment_slot.is_empty()
				if can_equip:
					label += ""
				btn.text = label
				btn.icon = item.icon
				var hint := item.description
				hint += "\n(Ziehen: ausrüsten oder übergeben)"
				if item.consumable:
					hint += "\n(Auswählen: Aktionsmenü)"
				elif can_equip:
					hint += "\n(Auswählen: Aktionsmenü)"
				btn.tooltip_text = hint
			else:
				btn.text = ""
				btn.icon = null
				btn.tooltip_text = ""
		else:
			btn.text = ""
			btn.icon = null
			btn.tooltip_text = ""

	for slot_key in _equip_buttons:
		var btn: Button = _equip_buttons[slot_key]
		var equipped = playable.equipment.get(slot_key)
		if equipped is ItemData:
			btn.text = equipped.item_name
			btn.icon = equipped.icon
			btn.tooltip_text = "%s\n(Auswählen: Aktionen)" % equipped.description
		elif equipped is String:
			btn.text = equipped
			btn.icon = null
			btn.tooltip_text = ""
		else:
			btn.text = "—"
			btn.icon = null
			btn.tooltip_text = ""

	if _selected_item != null:
		var still_owned := playable.equipment.values().has(_selected_item)
		for slot in playable.inventory:
			still_owned = still_owned or (slot != null and slot.item == _selected_item)
		_inspect_item(_selected_item if still_owned else null)


func _on_inv_slot_pressed(index: int) -> void:
	if not playable or index >= playable.inventory.size():
		return
	var slot := playable.inventory[index]
	if slot == null or not (slot.item is ItemData):
		return
	var item: ItemData = slot.item
	if item.consumable:
		playable.consume_item(item)
		return
	equip_from_slot(index, "primaer_hand" if item.equipment_slot == "waffe" else item.equipment_slot)


func _on_equip_pressed(slot_key: String) -> void:
	if not playable:
		return
	_inspect_equipment(slot_key)
	var item := playable.equipment.get(slot_key) as ItemData
	if item == null:
		_open_slot_picker(slot_key)
		return
	_ensure_actions()
	_action_slot = slot_key
	_slot_candidates.clear()
	_action_item = item
	_actions.clear()
	_actions.add_item("Im Rucksack verstauen", 1)
	_actions.position = Vector2i(_equip_buttons[slot_key].get_global_rect().end)
	_actions.popup()


## Hände und Schnellausrüstung nehmen jedes Item auf; Körperplätze bleiben passend.
func can_equip_from_slot(index: int, slot_key: String) -> bool:
	if playable == null or slot_key.is_empty():
		return false
	if index < 0 or index >= playable.inventory.size():
		return false
	var slot := playable.inventory[index]
	if slot == null or not (slot.item is ItemData):
		return false
	var item: ItemData = slot.item
	return Inventory.can_place_item(item, slot_key)


func equip_from_slot(index: int, slot_key: String) -> void:
	if not can_equip_from_slot(index, slot_key):
		return
	var item: ItemData = playable.inventory[index].item
	if not playable.remove_item(item):
		return
	var old = playable.unequip(slot_key)
	if old != null:
		playable.add_item(old)
	playable.equip(slot_key, item)


## Von Klick (_on_equip_pressed) und Drag&Drop (inventory_slot_button.gd,
## Ziehen aus der Ausrüstung zurück in den Rucksack) gemeinsam genutzt.
func unequip_to_backpack(slot_key: String) -> void:
	if playable == null:
		return
	var item = playable.unequip(slot_key)
	if item != null:
		playable.add_item(item)


func _slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_open_actions(index)
		get_viewport().set_input_as_handled()


func _open_actions(index: int) -> void:
	if not playable or index >= playable.inventory.size() or not playable.inventory[index].item:
		return
	_action_slot = ""
	_slot_candidates.clear()
	_inspect_inventory(index)
	_action_index = index
	_action_item = playable.inventory[index].item
	_ensure_actions()
	_actions.clear()
	var item: ItemData = playable.inventory[index].item
	if item.consumable:
		_actions.add_item("Verwenden", 0)
	elif item.equipment_slot in ["kopf", "rumpf", "schmuck", "beine", "fuesse"]:
		_actions.add_item("Anlegen", 0)
	_actions.add_item("In die rechte Hand nehmen", 200)
	_actions.add_item("In die linke Hand nehmen", 201)
	_actions.add_item("In der Welt ablegen", 1)
	for quick_index in Inventory.QUICK_EQUIPMENT_SLOTS.size():
		_actions.add_item("Schnellausrüstung %d" % (quick_index + 1), 100 + quick_index)
	_recipients.clear()
	if party:
		for member in party.get_all_members():
			if member != playable:
				_recipients.append(member)
				_actions.add_item("1 × an %s geben" % member.get_display_name(), _recipients.size() + 1)
	_actions.position = Vector2i(_inv_slots[index].get_global_rect().end)
	_actions.popup()


func _open_slot_picker(key: String) -> void:
	_ensure_actions()
	_action_slot = key
	_action_item = null
	_slot_candidates.clear()
	_actions.clear()
	for index in playable.inventory.size():
		var item: ItemData = playable.inventory[index].item
		if Inventory.can_place_item(item, key):
			var id := 1000 + index
			_slot_candidates[id] = item
			_actions.add_item(item.item_name, id)
	if _slot_candidates.is_empty():
		_actions.add_item("Kein passender Gegenstand im Rucksack", -1)
		_actions.set_item_disabled(0, true)
	_actions.position = Vector2i(_equip_buttons[key].get_global_rect().end)
	_actions.popup()


func can_drop_equipment(data: Variant, target: String) -> bool:
	if not data is Dictionary or data.get("source") != self or playable == null:
		return false
	if data.get("type") == "inventory_item":
		var index: int = data.get("index", -1)
		return can_equip_from_slot(index, target) and playable.inventory[index].item == data.get("item")
	if data.get("type") == "equipped_item":
		var source: String = data.get("slot_key", "")
		var item := data.get("item") as ItemData
		return source != target and Inventory.EQUIPMENT_SLOTS.has(source) and item != null and playable.equipment.get(source) == item and Inventory.can_place_item(item, target)
	return false


func drop_equipment(data: Variant, target: String) -> void:
	if not can_drop_equipment(data, target):
		return
	if data.type == "inventory_item":
		equip_from_slot(data.index, target)
		return
	var item: ItemData = playable.unequip(data.slot_key)
	var displaced: ItemData = playable.unequip(target)
	playable.equip(target, item)
	if displaced:
		if Inventory.can_place_item(displaced, data.slot_key):
			playable.equip(data.slot_key, displaced)
		else:
			playable.add_item(displaced)


func _ensure_actions() -> void:
	if not _actions:
		_actions = PopupMenu.new()
		add_child(_actions)
		_actions.id_pressed.connect(_perform_action)

func _perform_action(id: int) -> void:
	if not playable:
		return
	if not _action_slot.is_empty():
		if _slot_candidates.has(id):
			var selected: ItemData = _slot_candidates[id]
			for index in playable.inventory.size():
				if playable.inventory[index].item == selected:
					equip_from_slot(index, _action_slot)
					break
			return
		if id == 1 and playable.equipment.get(_action_slot) == _action_item:
			unequip_to_backpack(_action_slot)
		return
	if _action_index < 0 or _action_index >= playable.inventory.size() or playable.inventory[_action_index].item != _action_item:
		return
	if id == 0:
		_on_inv_slot_pressed(_action_index)
	elif id == 1:
		drop_item_from_slot(_action_index)
	elif id in [200, 201]:
		equip_from_slot(_action_index, "primaer_hand" if id == 200 else "nebenhand")
	elif id >= 100 and id < 100 + Inventory.QUICK_EQUIPMENT_SLOTS.size():
		equip_from_slot(_action_index, Inventory.QUICK_EQUIPMENT_SLOTS[id - 100])
	elif id >= 2 and id - 2 < _recipients.size():
		transfer_to(_action_index, _recipients[id - 2])


func transfer_to(index: int, target: Playable) -> bool:
	if not is_instance_valid(playable) or not is_instance_valid(target) or target == playable:
		return false
	if index < 0 or index >= playable.inventory.size():
		return false
	var item: ItemData = playable.inventory[index].item
	if party == null or target not in party.get_all_members():
		return false
	if not item or not target.can_carry_additional(item.weight):
		EventLog.add("Übergabe nicht möglich: Traglast überschritten.")
		return false
	var effect := {"type": "transfer_item", "character_id": playable.character.character_id,
		"target_id": target.character.character_id, "count": 1}
	if item.world_object_id.is_empty():
		effect.item_id = item.item_id
	else:
		effect.world_object_id = item.world_object_id
	var success := GameState.apply_effects([effect])
	EventLog.add("%s: %s an %s." % ["Übergabe" if success else "Übergabe fehlgeschlagen", item.item_name, target.get_display_name()])
	return success


func _exit_tree() -> void:
	if is_instance_valid(_inv) and _inv.changed.is_connected(_refresh):
		_inv.changed.disconnect(_refresh)


func accepts_transfer(data: Variant) -> bool:
	if not data is Dictionary or data.get("type") != "inventory_item":
		return false
	var source: InventoryUI = data.get("source")
	if not is_instance_valid(source) or source == self or not source.playable:
		return false
	var index: int = data.get("index", -1)
	return index >= 0 and index < source.playable.inventory.size() and source.playable.inventory[index].item == data.get("item")
