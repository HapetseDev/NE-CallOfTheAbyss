class_name StealManager
extends Node

## Stehlen aus NPC-Inventaren unter MainGame/Systems. Kein Autoload. Struktur
## bewusst wie shop_manager.gd/party_trade_manager.gd (Singleton-Instanz,
## lazy erzeugte UI, GameState-Input-Lock während geöffnet).

static var instance: StealManager

signal steal_opened
signal steal_closed

var _steal_ui: StealUI
var _ui_parent: Node


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(ui_parent: Node) -> void:
	_ui_parent = ui_parent


static func open(thief: Playable, victim: Playable) -> void:
	if instance == null:
		push_error("StealManager: MainGame ist nicht aktiv.")
		return
	instance._open(thief, victim)


static func close() -> void:
	if instance:
		instance._close()


func _open(thief: Playable, victim: Playable) -> void:
	if thief == null or victim == null:
		return
	GameState.acquire_input_lock()
	_ensure_ui()
	_steal_ui.open(thief, victim)
	steal_opened.emit()


func _close() -> void:
	if _steal_ui and is_instance_valid(_steal_ui) and _steal_ui.visible:
		_steal_ui.close()
	else:
		_finalize_close()


func _finalize_close() -> void:
	GameState.release_input_lock()
	steal_closed.emit()


func _on_steal_ui_closed() -> void:
	if _steal_ui and is_instance_valid(_steal_ui):
		_steal_ui.hide()
	_finalize_close()


func _ensure_ui() -> void:
	if _steal_ui and is_instance_valid(_steal_ui):
		return
	_steal_ui = StealUI.new()
	if _ui_parent:
		_ui_parent.add_child(_steal_ui)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 30
		layer.name = "StealLayer"
		add_child(layer)
		layer.add_child(_steal_ui)
	_steal_ui.closed.connect(_on_steal_ui_closed)
