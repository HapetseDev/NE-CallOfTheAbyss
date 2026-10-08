class_name MapUI extends Control

const Cartography = preload("res://src/ui/map/level_cartography.gd")
var cartography := Cartography.new()
var embedded := false
var _elapsed := 0.0
var _lock_owned := false
@onready var _window: Window = %Window
@onready var _level_label: Label = %LevelLabel
@onready var _map: Control = %MapCanvas

func _ready() -> void:
	_map.cartography = cartography
	_window.close_requested.connect(_on_close_requested)
	_window.window_input.connect(_on_window_input)
	visibility_changed.connect(_on_visibility_changed)
	%ResetView.pressed.connect(_map.reset_view)
	%CloseMap.pressed.connect(_on_close_requested)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.2:
		return
	_elapsed = 0.0
	cartography.update(MainGame.instance)
	if visible:
		_refresh()

func _exit_tree() -> void:
	if _lock_owned:
		GameState.release_input_lock()

func _on_visibility_changed() -> void:
	if not is_node_ready() or embedded:
		return
	if is_visible_in_tree():
		cartography.update(MainGame.instance)
		_refresh()
		_map.reset_view()
		var available := get_viewport_rect().size - Vector2.ONE * NEDimensions.SPACING_XL
		_window.size = Vector2i(Vector2(960, 680).min(available))
		_window.position = Vector2i((get_viewport_rect().size - Vector2(_window.size)) * 0.5)
		_window.visible = true
		_window.grab_focus()
		if not _lock_owned:
			GameState.acquire_input_lock()
			_lock_owned = true
	else:
		_window.hide()
		if _lock_owned:
			GameState.release_input_lock()
			_lock_owned = false

func _refresh() -> void:
	_level_label.text = "Karte · %s" % (str(cartography.level.name) if is_instance_valid(cartography.level) else "Unbekanntes Gebiet")
	_map.queue_redraw()

func _on_close_requested() -> void:
	visible = false

func _on_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_window.set_input_as_handled()
		_on_close_requested()
