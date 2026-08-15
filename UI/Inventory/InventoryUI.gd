class_name InventoryUI extends Control

var playable: Playable
var party: Party
var _inventory: Inventory

var _menu_hud: PartyHud
var _inv_slots: Array[Button] = []
var _equip_buttons: Dictionary = {}

@onready var _overlay: ColorRect = %Overlay
@onready var _close_button: Button = %CloseButton
@onready var _equip_grid: GridContainer = %EquipGrid
@onready var _inv_grid: GridContainer = %InvGrid


func _ready() -> void:
	_menu_hud = %MenuHud as PartyHud
	_overlay.inventory_ui = self
	_close_button.pressed.connect(_on_close_pressed)
	_wire_equip_buttons()
	_wire_inventory_slots()


func bind_player(playable_ref: Playable, party_ref: Party) -> void:
	playable = playable_ref
	party = party_ref
	if party:
		_menu_hud.setup(party)
	if playable:
		_inventory = playable.inventory
		_inventory.changed.connect(_refresh)
		_refresh()


func _wire_equip_buttons() -> void:
	for child in _equip_grid.get_children():
		if child is Button:
			var slot_key: String = child.get_meta(&"slot_key", "")
			if slot_key.is_empty():
				continue
			_equip_buttons[slot_key] = child
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
	if _inventory == null or playable == null:
		return
	var slot := _inventory.get_slot(index)
	if slot == null or slot.is_empty():
		return
	playable.drop_item_to_world(slot.item)


func _on_close_pressed() -> void:
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.visible = false


func _refresh() -> void:
	if _inventory == null:
		return
	var slots := _inventory.get_slots()
	for i in _inv_slots.size():
		_update_slot_button(_inv_slots[i], slots[i] if i < slots.size() else null)
	_refresh_equip()


func _update_slot_button(btn: Button, slot: InventorySlot) -> void:
	if slot == null or slot.is_empty():
		btn.text = ""
		btn.icon = null
		btn.tooltip_text = ""
		return
	var item := slot.item
	btn.text = item.item_name if slot.count <= 1 else "%s\nx%d" % [item.item_name, slot.count]
	btn.icon = item.icon
	var hint := item.beschreibung
	hint += "\n(Ziehen auf dunklen Bereich: Ablegen)"
	match item.type:
		Item.ItemType.VERBRAUCHBAR:
			hint += "\n(Klicken: Verwenden)"
		Item.ItemType.WAFFE, Item.ItemType.RÜSTUNG, Item.ItemType.ACCESSOIRE:
			if not item.ausrüstungs_slot.is_empty():
				hint += "\n(Klicken: Ausrüsten)"
	btn.tooltip_text = hint


func _refresh_equip() -> void:
	if playable == null:
		return
	for slot_key in _equip_buttons:
		var btn: Button = _equip_buttons[slot_key]
		var equipped: Variant = playable.equipment.get(slot_key)
		if equipped is Item:
			btn.text = (equipped as Item).item_name
			btn.icon = (equipped as Item).icon
			btn.tooltip_text = (equipped as Item).beschreibung
		else:
			btn.text = "—"
			btn.icon = null
			btn.tooltip_text = ""


func _on_inv_slot_pressed(index: int) -> void:
	if _inventory == null:
		return
	var slot := _inventory.get_slot(index)
	if slot == null or slot.is_empty():
		return
	var item := slot.item
	match item.type:
		Item.ItemType.VERBRAUCHBAR:
			if _inventory.remove_item(item.item_id):
				item.apply_effects(playable)
		Item.ItemType.WAFFE, Item.ItemType.RÜSTUNG, Item.ItemType.ACCESSOIRE:
			if playable and not item.ausrüstungs_slot.is_empty():
				_inventory.remove_item(item.item_id)
				var old: Variant = playable.unequip(item.ausrüstungs_slot)
				if old is Item:
					_inventory.add_item(old as Item)
				playable.equip(item.ausrüstungs_slot, item)


func _on_equip_pressed(slot_key: String) -> void:
	if playable == null or _inventory == null:
		return
	var item: Variant = playable.unequip(slot_key)
	if item is Item:
		_inventory.add_item(item as Item)
