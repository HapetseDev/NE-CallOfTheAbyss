class_name InventoryUI extends Control

var playable: Playable

const SLOT_SIZE := Vector2(64, 64)
const INV_COLS := 5
const INV_ROWS := 4

var _inv_slots: Array[Button] = []
var _equip_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if playable:
		playable.inventar_geaendert.connect(_refresh)
		_refresh()


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.set_script(load("res://UI/Inventory/inventory_drop_zone.gd"))
	overlay.set("inventory_ui", self)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -320.0
	panel.offset_top = -220.0
	panel.offset_right = 320.0
	panel.offset_bottom = 220.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Inventar"
	title.add_theme_font_size_override(&"font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", 20)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	var equip_col := VBoxContainer.new()
	equip_col.custom_minimum_size.x = 190.0
	hbox.add_child(equip_col)

	var equip_title := Label.new()
	equip_title.text = "Ausrüstung"
	equip_title.add_theme_font_size_override(&"font_size", 14)
	equip_col.add_child(equip_title)

	var equip_grid := GridContainer.new()
	equip_grid.columns = 2
	equip_grid.add_theme_constant_override(&"h_separation", 8)
	equip_grid.add_theme_constant_override(&"v_separation", 6)
	equip_col.add_child(equip_grid)

	const SLOT_LABELS := {
		"kopf": "Kopf",
		"rumpf": "Rumpf",
		"waffe": "Waffe",
		"nebenhand": "Nebenhand",
		"beine": "Beine",
		"füße": "Füße",
	}
	for slot_key in ["kopf", "rumpf", "waffe", "nebenhand", "beine", "füße"]:
		var lbl := Label.new()
		lbl.text = SLOT_LABELS[slot_key] + ":"
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		equip_grid.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = SLOT_SIZE
		btn.clip_text = true
		btn.pressed.connect(_on_equip_pressed.bind(slot_key))
		equip_grid.add_child(btn)
		_equip_buttons[slot_key] = btn

	var sep := VSeparator.new()
	hbox.add_child(sep)

	var inv_col := VBoxContainer.new()
	inv_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(inv_col)

	var inv_title := Label.new()
	inv_title.text = "Gegenstände"
	inv_title.add_theme_font_size_override(&"font_size", 14)
	inv_col.add_child(inv_title)

	var inv_grid := GridContainer.new()
	inv_grid.columns = INV_COLS
	inv_grid.add_theme_constant_override(&"h_separation", 4)
	inv_grid.add_theme_constant_override(&"v_separation", 4)
	inv_col.add_child(inv_grid)

	for i in INV_COLS * INV_ROWS:
		var btn := Button.new()
		btn.set_script(load("res://UI/Inventory/inventory_slot_button.gd"))
		btn.set("slot_index", i)
		btn.set("inventory_ui", self)
		btn.custom_minimum_size = SLOT_SIZE
		btn.clip_text = true
		btn.pressed.connect(_on_inv_slot_pressed.bind(i))
		inv_grid.add_child(btn)
		_inv_slots.append(btn)


func drop_item_from_slot(index: int) -> void:
	if playable == null or index < 0 or index >= playable.inventory.size():
		return
	var slot = playable.inventory[index]
	if not (slot is Dictionary and slot.get("item") is Item):
		return
	playable.drop_item_to_world(slot["item"] as Item)


func _on_close_pressed() -> void:
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.visible = false


func _refresh() -> void:
	if not playable:
		return

	for i in _inv_slots.size():
		var btn := _inv_slots[i]
		if i < playable.inventory.size():
			var slot = playable.inventory[i]
			if slot is Dictionary and slot.get("item") is Item:
				var item: Item = slot["item"]
				btn.text = "%s\nx%d" % [item.item_name, slot["count"]] if item.max_stapel > 1 else item.item_name
				btn.icon = item.icon
				var hint := item.beschreibung
				hint += "\n(Ziehen auf dunklen Bereich: Ablegen)"
				if item.verbrauchbar:
					hint += "\n(Klicken: Verwenden)"
				elif not item.ausrüstungs_slot.is_empty():
					hint += "\n(Klicken: Ausrüsten)"
				btn.tooltip_text = hint
			else:
				btn.text = str(slot)
				btn.icon = null
				btn.tooltip_text = ""
		else:
			btn.text = ""
			btn.icon = null
			btn.tooltip_text = ""

	for slot_key in _equip_buttons:
		var btn: Button = _equip_buttons[slot_key]
		var equipped = playable.equipment.get(slot_key)
		if equipped is Item:
			btn.text = equipped.item_name
			btn.icon = equipped.icon
			btn.tooltip_text = equipped.beschreibung
		elif equipped is String:
			btn.text = equipped
			btn.icon = null
			btn.tooltip_text = ""
		else:
			btn.text = "—"
			btn.icon = null
			btn.tooltip_text = ""


func _on_inv_slot_pressed(index: int) -> void:
	if not playable or index >= playable.inventory.size():
		return
	var slot = playable.inventory[index]
	if not (slot is Dictionary and slot.get("item") is Item):
		return
	var item: Item = slot["item"]
	if item.verbrauchbar:
		playable.consume_item(item)
		return
	if item.ausrüstungs_slot.is_empty():
		return
	playable.remove_item(item)
	var old = playable.unequip(item.ausrüstungs_slot)
	if old != null:
		playable.add_item(old)
	playable.equip(item.ausrüstungs_slot, item)


func _on_equip_pressed(slot_key: String) -> void:
	if not playable:
		return
	var item = playable.unequip(slot_key)
	if item != null:
		playable.add_item(item)
