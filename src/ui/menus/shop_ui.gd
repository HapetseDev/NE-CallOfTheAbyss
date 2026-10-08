class_name ShopUI extends Control

signal closed

var _player: Playable
var _shop: ShopData
var _panel: PanelContainer
var _gold_label: Label
var _shop_list: ItemList
var _player_list: ItemList
var _info_label: Label


func _ready() -> void:
	add_to_group("ui_sound_window")
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open(shop: ShopData, player: Playable) -> void:
	_shop = shop
	_player = player
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
	_panel.custom_minimum_size = Vector2(520, 360)
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
	title.text = "Handel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", NETypography.SIZE_H2)
	root.add_child(title)

	_gold_label = Label.new()
	root.add_child(_gold_label)

	var lists := HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists.add_theme_constant_override(&"separation", NEDimensions.SPACING_M)
	root.add_child(lists)

	var shop_box := VBoxContainer.new()
	shop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_box.add_theme_constant_override(&"separation", NEDimensions.SPACING_XS)
	lists.add_child(shop_box)
	var shop_title := Label.new()
	shop_title.text = "Angebot"
	shop_title.add_theme_font_size_override(&"font_size", NETypography.SIZE_SMALL)
	shop_title.add_theme_color_override(&"font_color", NEColors.TEXT_SECONDARY)
	shop_box.add_child(shop_title)
	_shop_list = ItemList.new()
	_shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_list.item_selected.connect(_on_shop_item_selected)
	shop_box.add_child(_shop_list)

	var player_box := VBoxContainer.new()
	player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_box.add_theme_constant_override(&"separation", NEDimensions.SPACING_XS)
	lists.add_child(player_box)
	var player_title := Label.new()
	player_title.text = "Dein Inventar"
	player_title.add_theme_font_size_override(&"font_size", NETypography.SIZE_SMALL)
	player_title.add_theme_color_override(&"font_color", NEColors.TEXT_SECONDARY)
	player_box.add_child(player_title)
	_player_list = ItemList.new()
	_player_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_player_list.item_selected.connect(_on_player_item_selected)
	player_box.add_child(_player_list)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override(&"font_size", NETypography.SIZE_SMALL)
	_info_label.add_theme_color_override(&"font_color", NEColors.TEXT_SECONDARY)
	root.add_child(_info_label)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(NEDimensions.BUTTON_MIN_WIDTH, NEDimensions.BUTTON_HEIGHT)
	close_btn.text = "Schließen"
	close_btn.pressed.connect(close)
	buttons.add_child(close_btn)


func _refresh() -> void:
	if _player == null or _shop == null:
		return
	_gold_label.text = "Gold: %d  ·  Gewicht: %.1f / %.1f" % [
		_player.gold, _player.get_total_weight(), _player.get_max_carry_weight()
	]
	_shop_list.clear()
	for i in _shop.entries.size():
		var entry := _shop.entries[i]
		if entry == null or entry.item == null:
			continue
		var stock_text := ""
		if entry.stock >= 0:
			stock_text = " (x%d)" % entry.stock
		_shop_list.add_item("%s%s — %d G" % [entry.item.item_name, stock_text, entry.buy_price], null, false)
		_shop_list.set_item_metadata(_shop_list.item_count - 1, entry)
	_player_list.clear()
	for i in _player.inventory.size():
		var slot := _player.inventory[i]
		if slot != null and slot.item is ItemData:
			var item := slot.item
			var count: int = slot.count
			var sell_price := _get_sell_price(item)
			_player_list.add_item("%s x%d — %d G" % [item.item_name, count, sell_price], null, false)
			_player_list.set_item_metadata(_player_list.item_count - 1, slot)


func _get_sell_price(item: ItemData) -> int:
	return preload("res://src/core/world/shop_rules.gd").sell_price(_shop, item)


func _on_shop_item_selected(index: int) -> void:
	if not visible or not is_instance_valid(_player) or _shop == null or index < 0 or index >= _shop_list.item_count:
		return
	var entry := _shop_list.get_item_metadata(index) as ShopEntry
	if entry == null or entry.item == null:
		return
	if _player.gold < entry.buy_price:
		_info_label.text = "Nicht genug Gold."
		return
	if entry.stock == 0:
		_info_label.text = "Ausverkauft."
		return
	if not _player.can_carry_additional(entry.item.weight):
		_info_label.text = "Zu schwer, um es zu tragen."
		return
	if not _shop.entries.has(entry) or not _is_current_context() or not GameState.apply_effects([{"type": "shop_buy", "character_id": _player.character.character_id, "shop_id": _shop.shop_id, "item_id": entry.item.item_id, "count": 1}]):
		_info_label.text = "Kauf konnte nicht abgeschlossen werden."
		return
	_refresh()
	_info_label.text = "%s gekauft." % entry.item.item_name


func _on_player_item_selected(index: int) -> void:
	if not visible or not is_instance_valid(_player) or index < 0 or index >= _player_list.item_count or not _is_current_context():
		return
	var slot = _player_list.get_item_metadata(index)
	if not slot is InventorySlot or slot.item == null or not _player.inventory.has(slot):
		_refresh()
		return
	var item: ItemData = slot.item
	var price := _get_sell_price(item)
	var effect := {"type": "shop_sell", "character_id": _player.character.character_id, "shop_id": _shop.shop_id, "count": 1}
	if item.world_object_id.is_empty():
		effect.item_id = item.item_id
	else:
		effect.world_object_id = item.world_object_id
	if not GameState.apply_effects([effect]):
		_info_label.text = "Verkauf konnte nicht abgeschlossen werden."
		return
	_refresh()
	_info_label.text = "%s verkauft für %d G." % [item.item_name, price]


func _is_current_context() -> bool:
	return _shop != null and _player.character != null and GameState.world_state.shops.get(_shop.shop_id) == _shop and GameState.character_registry.get_character(_player.character.character_id) == _player.character
