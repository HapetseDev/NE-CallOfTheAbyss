extends Node

## Automatische Sounds für bestehende und künftig erzeugte Standard-Controls.
## Eigene Control-Fenster tragen die Gruppe ui_sound_window; Window automatisch.
signal cue_played(cue: StringName)
const STREAM_PATHS := {
	&"select": "res://assets/audio/sfx/ui/select.wav",
	&"ok": "res://assets/audio/sfx/ui/ok.wav",
	&"back": "res://assets/audio/sfx/ui/back.wav",
}
const PRIORITY := {&"select": 1, &"ok": 2, &"back": 3}
var _player: AudioStreamPlayer
var _streams: Dictionary = {}
var _pending: StringName = &""
var _selection := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(_player)
	for cue in STREAM_PATHS:
		_streams[cue] = load(STREAM_PATHS[cue])
	get_tree().node_added.connect(_schedule_wire)
	_scan(get_tree().root)

func _scan(node: Node) -> void:
	_schedule_wire(node)
	for child in node.get_children():
		_scan(child)

func _schedule_wire(node: Node) -> void:
	_wire.call_deferred(weakref(node))

func _wire(reference: WeakRef) -> void:
	var node: Node = reference.get_ref()
	if not is_instance_valid(node) or node.has_meta("ui_audio_wired"):
		return
	node.set_meta("ui_audio_wired", true)
	if node is BaseButton:
		node.mouse_entered.connect(_select_button.bind(node))
		node.focus_entered.connect(_select_button.bind(node))
		node.mouse_exited.connect(_clear_selection.bind(node))
		node.focus_exited.connect(_clear_selection.bind(node))
		node.pressed.connect(_activate.bind(node))
	elif node is ItemList:
		node.item_selected.connect(func(index: int): _select_item(node, index))
		node.multi_selected.connect(func(index: int, _selected: bool): _select_item(node, index))
		node.item_activated.connect(func(_index: int): request(&"ok"))
		node.gui_input.connect(_list_input.bind(node))
		node.mouse_exited.connect(_clear_selection.bind(node))
	elif node is TabBar:
		node.tab_hovered.connect(func(index: int): _select_tab(node, index))
		node.tab_changed.connect(func(index: int): _select_tab(node, index))
		node.tab_clicked.connect(func(_index: int): request(&"ok"))
		node.gui_input.connect(func(event: InputEvent):
			if event.is_action_pressed("ui_accept"): request(&"ok"))
		node.focus_entered.connect(func(): _select_tab(node, node.current_tab))
	elif node is Tree:
		node.item_selected.connect(func():
			var item: TreeItem = node.get_selected()
			if item: _select(node, item.get_instance_id()))
		node.item_activated.connect(func(): request(&"ok"))
	elif node is PopupMenu:
		node.id_focused.connect(func(id: int): _select(node, id))
		node.id_pressed.connect(func(_id: int): request(&"ok"))
	if (node is Window and node != get_tree().root and not node is Popup) or node.is_in_group("ui_sound_window"):
		watch_window(node)

func watch_window(node: Node) -> void:
	if node.has_meta("ui_audio_window"):
		return
	node.set_meta("ui_audio_window", true)
	node.set_meta("ui_audio_visible", _window_visible(node))
	node.tree_exiting.connect(func():
		# Direkte Freigabe eines geöffneten Fensters, aber kein Szenenabbau.
		if not node.is_queued_for_deletion() or not node.get_meta("ui_audio_visible", false):
			return
		var parent := node.get_parent()
		while parent:
			if parent.is_queued_for_deletion(): return
			parent = parent.get_parent()
		request(&"back"))
	node.visibility_changed.connect(func():
		var visible_now := _window_visible(node)
		if node.get_meta("ui_audio_visible", false) and not visible_now and node.is_inside_tree():
			request(&"back")
		node.set_meta("ui_audio_visible", visible_now))

func _window_visible(node: Node) -> bool:
	return node.visible if node is Window else (node as CanvasItem).is_visible_in_tree()

func _select_button(button: BaseButton) -> void:
	if not button.disabled and button.is_visible_in_tree():
		_select(button)

func _activate(button: BaseButton) -> void:
	if not button.disabled:
		request(&"ok")

func _select_item(list: ItemList, index: int) -> void:
	if index >= 0 and not list.is_item_disabled(index) and list.is_item_selectable(index):
		_select(list, index)

func _select_tab(tabs: TabBar, index: int) -> void:
	if index >= 0 and not tabs.is_tab_disabled(index):
		_select(tabs, index)

func _list_input(event: InputEvent, list: ItemList) -> void:
	if event is InputEventMouseMotion:
		_select_item(list, list.get_item_at_position(event.position, true))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := list.get_item_at_position(event.position, true)
		if index >= 0 and not list.is_item_disabled(index) and list.is_item_selectable(index):
			request(&"ok")

func _select(node: Node, index: int = -1) -> void:
	var key := "%d:%d" % [node.get_instance_id(), index]
	if _selection != key:
		_selection = key
		request(&"select")

func _clear_selection(node: Node) -> void:
	if _selection.begins_with(str(node.get_instance_id()) + ":"):
		_selection = ""

## Ein Schließen ersetzt den Bestätigungston desselben Klicks; kein Doppelsound.
func request(cue: StringName) -> void:
	if not PRIORITY.has(cue):
		return
	if _pending == &"":
		_flush.call_deferred()
	if PRIORITY[cue] > PRIORITY.get(_pending, 0):
		_pending = cue

func _flush() -> void:
	var cue := _pending
	_pending = &""
	_player.stream = _streams[cue]
	_player.play()
	cue_played.emit(cue)

func _exit_tree() -> void:
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	_streams.clear()
