extends Node

const EDITOR_SCENE := preload("res://UI/Debug/debug_character_sheet_editor.tscn")

var _layer: CanvasLayer
var _editor: Control


func open_character_editor(focus: Playable = null) -> void:
	_ensure_editor()
	_editor.call("open", focus)
	_layer.visible = true
	GameDialogueBridge.set_player_input_locked(true)


func close_character_editor() -> void:
	if _layer:
		_layer.visible = false
	GameDialogueBridge.set_player_input_locked(false)


func is_open() -> bool:
	return _layer != null and _layer.visible


func _ensure_editor() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.layer = 50
	get_tree().root.add_child(_layer)
	_editor = EDITOR_SCENE.instantiate() as Control
	_layer.add_child(_editor)
	_editor.closed.connect(close_character_editor)


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
