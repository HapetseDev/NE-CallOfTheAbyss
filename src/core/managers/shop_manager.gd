class_name ShopManager
extends Node

## Shop-System unter MainGame/Systems. Kein Autoload.

static var instance: ShopManager

signal shop_opened
signal shop_closed

var _shop_ui: ShopUI
var _shops: Dictionary = {}
var _ui_parent: Node


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_load_shops()


func setup(ui_parent: Node) -> void:
	_ui_parent = ui_parent


static func open(shop_id: String, player: Playable) -> void:
	if instance == null:
		push_error("ShopManager: MainGame ist nicht aktiv.")
		return
	instance._open(shop_id, player)


static func close() -> void:
	if instance:
		instance._close()


func _open(shop_id: String, player: Playable) -> void:
	if player == null:
		return
	var shop := get_shop(shop_id)
	if shop == null:
		push_warning("ShopManager: Shop '%s' nicht gefunden." % shop_id)
		return
	GameState.acquire_input_lock()
	_ensure_ui()
	_shop_ui.open(shop, player)
	shop_opened.emit()


func _close() -> void:
	if _shop_ui and is_instance_valid(_shop_ui) and _shop_ui.visible:
		_shop_ui.close()
	else:
		_finalize_close()


func _finalize_close() -> void:
	GameState.release_input_lock()
	shop_closed.emit()


func _on_shop_ui_closed() -> void:
	if _shop_ui and is_instance_valid(_shop_ui):
		_shop_ui.hide()
	_finalize_close()


func get_shop(shop_id: String) -> ShopData:
	return _shops.get(shop_id)


func _ensure_ui() -> void:
	if _shop_ui and is_instance_valid(_shop_ui):
		return
	_shop_ui = ShopUI.new()
	if _ui_parent:
		_ui_parent.add_child(_shop_ui)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 30
		layer.name = "ShopLayer"
		add_child(layer)
		layer.add_child(_shop_ui)
	_shop_ui.closed.connect(_on_shop_ui_closed)


func _load_shops() -> void:
	var dir := DirAccess.open("res://src/resources/items/shop/shops")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var shop := load("res://src/resources/items/shop/shops/%s" % file_name) as ShopData
			if shop and not shop.shop_id.is_empty():
				_shops[shop.shop_id] = shop
		file_name = dir.get_next()
	dir.list_dir_end()
