class_name PartyTradeUI extends Control

## Kostenloses Tauschen zwischen zwei Partymitgliedern - kein Gold, kein
## Risiko (im Unterschied zu einem künftigen Stehlen). Programmatisch gebaut
## nach demselben Muster wie ShopUI, mit zwei Rucksack-Listen statt einer
## Angebots-/Verkaufsliste. Jeder Klick verschiebt genau 1 Stück (wie beim
## Verkaufen in ShopUI), geprüft gegen die Traggewicht-Grenze der Zielseite.

signal closed

var _left: Playable
var _right: Playable
var _panel: PanelContainer
var _left_label: Label
var _right_label: Label
var _left_list: ItemList
var _right_list: ItemList
var _info_label: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open(left: Playable, right: Playable) -> void:
	_left = left
	_right = right
	_refresh()
	show()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = NEColors.SCRIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 380)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", NEDimensions.PANEL_MARGIN)
	margin.add_theme_constant_override(&"margin_top", NEDimensions.PANEL_MARGIN)
	margin.add_theme_constant_override(&"margin_right", NEDimensions.PANEL_MARGIN)
	margin.add_theme_constant_override(&"margin_bottom", NEDimensions.PANEL_MARGIN)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", NEDimensions.SPACING_S)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Tauschen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", NETypography.SIZE_H2)
	root.add_child(title)

	var lists := HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists.add_theme_constant_override(&"separation", NEDimensions.SPACING_M)
	root.add_child(lists)

	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override(&"separation", NEDimensions.SPACING_XS)
	lists.add_child(left_box)
	_left_label = Label.new()
	_left_label.add_theme_font_size_override(&"font_size", NETypography.SIZE_SMALL)
	_left_label.add_theme_color_override(&"font_color", NEColors.TEXT_SECONDARY)
	left_box.add_child(_left_label)
	_left_list = ItemList.new()
	_left_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_list.item_selected.connect(_on_left_item_selected)
	left_box.add_child(_left_list)

	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override(&"separation", NEDimensions.SPACING_XS)
	lists.add_child(right_box)
	_right_label = Label.new()
	_right_label.add_theme_font_size_override(&"font_size", NETypography.SIZE_SMALL)
	_right_label.add_theme_color_override(&"font_color", NEColors.TEXT_SECONDARY)
	right_box.add_child(_right_label)
	_right_list = ItemList.new()
	_right_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_list.item_selected.connect(_on_right_item_selected)
	right_box.add_child(_right_list)

	var hint := Label.new()
	hint.text = "Klicken, um ein Stück zur jeweils anderen Seite zu geben."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override(&"font_size", NETypography.SIZE_SMALL)
	hint.add_theme_color_override(&"font_color", NEColors.TEXT_SECONDARY)
	root.add_child(hint)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override(&"font_size", NETypography.SIZE_SMALL)
	root.add_child(_info_label)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(NEDimensions.BUTTON_MIN_WIDTH, NEDimensions.BUTTON_HEIGHT)
	close_btn.text = "Schließen"
	close_btn.pressed.connect(close)
	buttons.add_child(close_btn)


func _refresh() -> void:
	if _left == null or _right == null:
		return
	_info_label.text = ""
	_left_label.text = "%s  (%.1f / %.1f kg)" % [
		_left.get_display_name(), _left.get_total_weight(), _left.get_max_carry_weight()
	]
	_right_label.text = "%s  (%.1f / %.1f kg)" % [
		_right.get_display_name(), _right.get_total_weight(), _right.get_max_carry_weight()
	]
	_fill_list(_left_list, _left)
	_fill_list(_right_list, _right)


func _fill_list(list: ItemList, owner_playable: Playable) -> void:
	list.clear()
	for i in owner_playable.inventory.size():
		var slot := owner_playable.inventory[i]
		if slot != null and slot.item is ItemData:
			var item: ItemData = slot.item
			list.add_item("%s x%d (%.1f kg)" % [item.item_name, slot.count, item.weight])
			list.set_item_metadata(list.item_count - 1, slot)


func _on_left_item_selected(index: int) -> void:
	_transfer(_left_list, _left, _right, index)


func _on_right_item_selected(index: int) -> void:
	_transfer(_right_list, _right, _left, index)


func _transfer(source_list: ItemList, source: Playable, dest: Playable, index: int) -> void:
	var slot = source_list.get_item_metadata(index)
	if not (slot is InventorySlot) or not (slot.item is ItemData):
		return
	var item: ItemData = slot.item
	if not dest.can_carry_additional(item.weight):
		_info_label.text = "%s kann %s nicht tragen (zu schwer)." % [dest.get_display_name(), item.item_name]
		return
	if not source.remove_item(item, 1):
		return
	dest.add_item(item, 1)
	EventLog.add("%s gibt %s an %s." % [source.get_display_name(), item.item_name, dest.get_display_name()])
	_refresh()
