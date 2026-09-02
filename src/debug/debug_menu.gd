class_name DebugMenu
extends Node

## Debug-Overlay unter MainGame/Systems. Kein Autoload.

static var instance: DebugMenu

var _layer: CanvasLayer
var _editor: Control


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func open_character_editor(focus: Playable = null) -> void:
	if instance == null:
		push_error("DebugMenu: MainGame ist nicht aktiv.")
		return
	instance._open_character_editor(focus)


static func close_character_editor() -> void:
	if instance:
		instance._close_character_editor()


static func is_open() -> bool:
	return instance != null and instance._is_open()


func _open_character_editor(focus: Playable = null) -> void:
	_ensure_editor()
	_editor.call("open", focus)
	_layer.visible = true
	GameState.acquire_input_lock()


func _close_character_editor() -> void:
	if _layer:
		_layer.visible = false
	GameState.release_input_lock()


func _is_open() -> bool:
	return _layer != null and _layer.visible


func _ensure_editor() -> void:
	if _layer != null:
		return
	var packed := load("res://src/debug/debug_character_sheet_editor.tscn") as PackedScene
	if packed == null:
		push_error("DebugMenu: Debug-Editor-Szene nicht gefunden.")
		return
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_editor = packed.instantiate() as Control
	_layer.add_child(_editor)
	_editor.closed.connect(_close_character_editor)


static func find_all_playables(root: Node) -> Array[Playable]:
	var result: Array[Playable] = []
	_collect_playables(root, result)
	result.sort_custom(func(a: Playable, b: Playable) -> bool:
		return a.get_display_name().nocasecmp_to(b.get_display_name()) < 0
	)
	return result


static func _collect_playables(node: Node, result: Array[Playable]) -> void:
	if node is Playable:
		result.append(node as Playable)
	for child in node.get_children():
		_collect_playables(child, result)
