class_name InventoryUI extends Control

var playable: Playable
var party: Party

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
		playable.inventar_geaendert.connect(_refresh)
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
