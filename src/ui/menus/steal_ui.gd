class_name StealUI extends Control

## Stehlen aus dem Rucksack eines NPCs - im Unterschied zum kostenlosen
## Party-Tauschen mit echtem Risiko: Erfolgschance = Gewandheit (Dieb) vs.
## Bewusstsein (Opfer), siehe StealResolver. Fehlschlag beendet das Fenster
## sofort und löst einen Kampf aus (CombatManager.trigger_attack mit dem
## Opfer als Angreifer - die Reaktion eines Wachpostens/NPCs, der einen
## Diebstahl bemerkt). Programmatisch gebaut nach dem Muster von ShopUI/
## PartyTradeUI, aber nur eine Liste (das Opfer hat schließlich nichts von
## deinem Inventar zu sehen).

signal closed

var _thief: Playable
var _victim: Playable
var _panel: PanelContainer
var _victim_label: Label
var _item_list: ItemList
var _info_label: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open(thief: Playable, victim: Playable) -> void:
	_thief = thief
	_victim = victim
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
	_panel.custom_minimum_size = Vector2(380, 340)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(360, 320)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "Stehlen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_victim_label = Label.new()
	root.add_child(_victim_label)

	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	root.add_child(_item_list)

	var hint := Label.new()
	hint.text = "Klicken, um einen Gegenstand zu stehlen. Risiko: Entdeckung führt zum Kampf."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override(&"font_size", 11)
	root.add_child(hint)

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
	if _thief == null or _victim == null:
		return
	_info_label.text = ""
	_victim_label.text = "%s durchsuchen" % _victim.get_display_name()
	_item_list.clear()
	for i in _victim.inventory.size():
		var slot := _victim.inventory[i]
		if slot != null and slot.item is ItemData:
			var item: ItemData = slot.item
			_item_list.add_item("%s x%d (%.1f kg)" % [item.item_name, slot.count, item.weight])
			_item_list.set_item_metadata(_item_list.item_count - 1, slot)
	if _item_list.item_count == 0:
		_info_label.text = "Nichts zu stehlen."


func _on_item_selected(index: int) -> void:
	if _thief == null or _victim == null:
		return
	var slot = _item_list.get_item_metadata(index)
	if not (slot is InventorySlot) or not (slot.item is ItemData):
		return
	var item: ItemData = slot.item
	if not _thief.can_carry_additional(item.weight):
		_info_label.text = "Zu schwer, um es zu tragen."
		return

	if StealResolver.roll_success(_thief, _victim):
		if not _victim.remove_item(item, 1):
			return
		_thief.add_item(item, 1)
		EventLog.add("%s stiehlt unbemerkt %s von %s." % [
			_thief.get_display_name(), item.item_name, _victim.get_display_name()
		])
		_refresh()
		return

	EventLog.add("%s wird beim Diebstahl von %s erwischt!" % [
		_thief.get_display_name(), _victim.get_display_name()
	])
	var caught_thief := _thief
	var caught_victim := _victim
	close()
	CombatManager.trigger_attack(caught_victim, caught_thief)
