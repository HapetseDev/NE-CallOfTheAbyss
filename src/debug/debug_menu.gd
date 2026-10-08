class_name DebugMenu
extends Node

## Debug-Overlay unter MainGame/Systems. Kein Autoload.

static var instance: DebugMenu

var _layer: CanvasLayer
var _editor: Control
var _sequence_demo_button: Button
var _editor_lock_owned := false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if _editor_lock_owned:
		GameState.release_input_lock()
		_editor_lock_owned = false
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
	if _is_open() or GameState.is_player_input_locked():
		return
	_ensure_editor()
	if _editor == null:
		return
	_editor.call("open", focus)
	_layer.visible = true
	GameState.acquire_input_lock()
	_editor_lock_owned = true


func _close_character_editor() -> void:
	if _layer:
		_layer.visible = false
	if _editor_lock_owned:
		GameState.release_input_lock()
		_editor_lock_owned = false


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
	_sequence_demo_button = Button.new()
	_sequence_demo_button.text = "Sequence-Demo starten (2 Sekunden)"
	_sequence_demo_button.custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
	_sequence_demo_button.pressed.connect(_start_sequence_demo)
	var close_button := _editor.get_node("%CloseButton")
	close_button.get_parent().add_child(_sequence_demo_button)
	close_button.get_parent().move_child(_sequence_demo_button, close_button.get_index())
	var manager := MainGame.instance.sequence_manager
	manager.sequence_finished.connect(_on_sequence_demo_finished)


func _start_sequence_demo() -> void:
	_close_character_editor()
	var started := MainGame.instance.sequence_manager.start(&"sequence_mvp", {}, &"debug_menu")
	if started.accepted:
		EventLog.add("Sequence-Demo: gestartet, Eingaben für zwei Sekunden gesperrt.")
	else:
		EventLog.add("Sequence-Demo: " + started.message)


func _on_sequence_demo_finished(_run_id: String, result: Dictionary) -> void:
	if result.sequence_id != &"sequence_mvp":
		return
	EventLog.add("Sequence-Demo: %s; Flag sequence_mvp_done = %s." % [result.status, GameState.get_flag("sequence_mvp_done", false)])


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
