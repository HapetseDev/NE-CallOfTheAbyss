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
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 360)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(500, 340)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "Handel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_gold_label = Label.new()
	root.add_child(_gold_label)

	var lists := HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(lists)

	var shop_box := VBoxContainer.new()
	shop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_child(shop_box)
	var shop_title := Label.new()
	shop_title.text = "Angebot"
	shop_box.add_child(shop_title)
	_shop_list = ItemList.new()
	_shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_list.item_selected.connect(_on_shop_item_selected)
	shop_box.add_child(_shop_list)

	var player_box := VBoxContainer.new()
	player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_child(player_box)
	var player_title := Label.new()
	player_title.text = "Dein Inventar"
	player_box.add_child(player_title)
	_player_list = ItemList.new()
	_player_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_player_list.item_selected.connect(_on_player_item_selected)
	player_box.add_child(_player_list)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info_label)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	var close_btn := Button.new()
	close_btn.text = "Schließen"
	close_btn.pressed.connect(close)
	buttons.add_child(close_btn)


func _refresh() -> void:
	if _player == null or _shop == null:
		return
	_gold_label.text = "Gold: %d" % _player.gold
	_shop_list.clear()
	for i in _shop.entries.size():
		var entry := _shop.entries[i]
		if entry == null or entry.item == null:
			continue
		var stock_text := ""
		if entry.stock >= 0:
			stock_text = " (x%d)" % entry.stock
		_shop_list.add_item("%s%s — %d G" % [entry.item.item_name, stock_text, entry.buy_price], null, false)
		_shop_list.set_item_metadata(i, entry)
	_player_list.clear()
	for i in _player.inventory.size():
		var slot = _player.inventory[i]
		if slot is Dictionary and slot.get("item") is Item:
			var item := slot["item"] as Item
			var count: int = slot.get("count", 1)
			var sell_price := _get_sell_price(item)
			_player_list.add_item("%s x%d — %d G" % [item.item_name, count, sell_price], null, false)
			_player_list.set_item_metadata(i, slot)


func _get_sell_price(item: Item) -> int:
	for entry in _shop.entries:
		if entry and entry.item and entry.item.item_id == item.item_id:
			return entry.sell_price
	return maxi(1, int(item.masse * 10))


func _on_shop_item_selected(index: int) -> void:
	if _player == null or _shop == null:
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
	_player.gold -= entry.buy_price
	_player.add_item(entry.item.duplicate_item(), 1)
	if entry.stock > 0:
		entry.stock -= 1
	_info_label.text = "%s gekauft." % entry.item.item_name
	_refresh()


func _on_player_item_selected(index: int) -> void:
	if _player == null:
		return
	var slot = _player_list.get_item_metadata(index)
	if slot is Dictionary and slot.get("item") is Item:
		var item := slot["item"] as Item
		var sell_price := _get_sell_price(item)
		if _player.remove_item(item, 1):
			_player.gold += sell_price
			_info_label.text = "%s verkauft für %d G." % [item.item_name, sell_price]
			_refresh()
