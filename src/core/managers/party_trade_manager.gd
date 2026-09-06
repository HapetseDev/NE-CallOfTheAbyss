class_name PartyTradeManager
extends Node

## Kostenloses Tauschen zwischen Partymitgliedern unter MainGame/Systems.
## Kein Autoload. Struktur bewusst wie shop_manager.gd (Singleton-Instanz,
## lazy erzeugte UI, GameState-Input-Lock während geöffnet).

static var instance: PartyTradeManager

signal trade_opened
signal trade_closed

var _trade_ui: PartyTradeUI
var _ui_parent: Node


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(ui_parent: Node) -> void:
	_ui_parent = ui_parent


static func open(initiator: Playable, partner: Playable) -> void:
	if instance == null:
		push_error("PartyTradeManager: MainGame ist nicht aktiv.")
		return
	instance._open(initiator, partner)


static func close() -> void:
	if instance:
		instance._close()


func _open(initiator: Playable, partner: Playable) -> void:
	if initiator == null or partner == null:
		return
	GameState.acquire_input_lock()
	_ensure_ui()
	_trade_ui.open(initiator, partner)
	trade_opened.emit()


func _close() -> void:
	if _trade_ui and is_instance_valid(_trade_ui) and _trade_ui.visible:
		_trade_ui.close()
	else:
		_finalize_close()


func _finalize_close() -> void:
	GameState.release_input_lock()
	trade_closed.emit()


func _on_trade_ui_closed() -> void:
	if _trade_ui and is_instance_valid(_trade_ui):
		_trade_ui.hide()
	_finalize_close()


func _ensure_ui() -> void:
	if _trade_ui and is_instance_valid(_trade_ui):
		return
	_trade_ui = PartyTradeUI.new()
	if _ui_parent:
		_ui_parent.add_child(_trade_ui)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 30
		layer.name = "PartyTradeLayer"
		add_child(layer)
		layer.add_child(_trade_ui)
	_trade_ui.closed.connect(_on_trade_ui_closed)
