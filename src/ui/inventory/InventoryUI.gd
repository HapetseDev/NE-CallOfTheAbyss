class_name InventoryUI extends Control

var playable: Playable
var party: Party

var _menu_hud: PartyHud
var _inv_slots: Array[Button] = []
var _equip_buttons: Dictionary = {}

var _inv: InventoryComponent  # neu hinzufügen

@onready var _overlay: ColorRect = %Overlay
@onready var _window: Window = %Window
@onready var _equip_grid: GridContainer = %EquipGrid
@onready var _inv_grid: GridContainer = %InvGrid
@onready var _weight_label: Label = %WeightLabel


func _ready() -> void:
	_menu_hud = %MenuHud as PartyHud
	_overlay.inventory_ui = self
	_window.close_requested.connect(_on_close_requested)
	_wire_equip_buttons()
	_wire_inventory_slots()
	visibility_changed.connect(_on_visibility_changed)


func bind_player(playable_ref: Playable, party_ref: Party) -> void:
	playable = playable_ref
	party = party_ref
	if party:
		_menu_hud.setup(party)
	if playable:
		_inv = playable.inventory_component
		_inv.changed.connect(_refresh)
		_refresh()


func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	if is_visible_in_tree():
		_window.visible = true
		_window.grab_focus()
	else:
		_window.visible = false


func _wire_equip_buttons() -> void:
	for child in _equip_grid.get_children():
		if child is Button:
			var slot_key: String = child.get_meta(&"slot_key", "")
			if slot_key.is_empty():
				continue
			_equip_buttons[slot_key] = child
			child.inventory_ui = self
			child.pressed.connect(_on_equip_pressed.bind(slot_key))


func _wire_inventory_slots() -> void:
	var index := 0
	for child in _inv_grid.get_children():
		if child is Button:
			child.inventory_ui = self
			child.slot_index = index
			child.pressed.connect(_on_inv_slot_pressed.bind(index))
			_inv_slots.append(child)
			index += 1


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

	_weight_label.text = "Gewicht: %.1f / %.1f" % [playable.get_total_weight(), playable.get_max_carry_weight()]

	for i in _inv_slots.size():
		var btn := _inv_slots[i]
		if i < playable.inventory.size():
			var slot := playable.inventory[i]
			if slot != null and slot.item is ItemData:
				var item: ItemData = slot.item
				var label := "%s\nx%d" % [item.item_name, slot.count] if item.max_stack > 1 else item.item_name
				var can_equip := not item.consumable and not item.equipment_slot.is_empty()
				if can_equip:
					label += "\n[Ausrüsten]"
				btn.text = label
				btn.icon = item.icon
				var hint := item.description
				hint += "\n(Ziehen auf dunklen Bereich: Ablegen)"
				if item.consumable:
					hint += "\n(Klicken: Verwenden)"
				elif can_equip:
					hint += "\n(Klicken: Ausrüsten)"
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
			btn.tooltip_text = "%s\n(Klicken: Ablegen)" % equipped.description
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
	var slot := playable.inventory[index]
	if slot == null or not (slot.item is ItemData):
		return
	var item: ItemData = slot.item
	if item.consumable:
		playable.consume_item(item)
		return
	equip_from_slot(index, item.equipment_slot)


func _on_equip_pressed(slot_key: String) -> void:
	unequip_to_backpack(slot_key)


## Von Klick (_on_inv_slot_pressed) und Drag&Drop (equip_slot_button.gd)
## gemeinsam genutzt. slot_key muss zum equipment_slot des Items passen –
## verhindert per Drag, dass z.B. ein Helm im Waffen-Slot landet.
func can_equip_from_slot(index: int, slot_key: String) -> bool:
	if playable == null or slot_key.is_empty():
		return false
	if index < 0 or index >= playable.inventory.size():
		return false
	var slot := playable.inventory[index]
	if slot == null or not (slot.item is ItemData):
		return false
	var item: ItemData = slot.item
	return not item.consumable and item.equipment_slot == slot_key


func equip_from_slot(index: int, slot_key: String) -> void:
	if not can_equip_from_slot(index, slot_key):
		return
	var item: ItemData = playable.inventory[index].item
	playable.remove_item(item)
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
