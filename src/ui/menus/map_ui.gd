class_name MapUI extends Control

## Kartenfenster, aus dem TopBarHud verlinkt. Zeigt aktuell nur den Namen
## des geladenen Levels – die eigentliche Kartendarstellung ist noch nicht
## umgesetzt und kommt in einer eigenen Aufgabe.

@onready var _window: Window = %Window
@onready var _level_label: Label = %LevelLabel


func _ready() -> void:
	_window.close_requested.connect(_on_close_requested)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	if is_visible_in_tree():
		_window.visible = true
		_window.grab_focus()
		_refresh()
	else:
		_window.visible = false


func _refresh() -> void:
	var level_name := "Unbekannt"
	if LevelManager.instance and LevelManager.instance.current_level:
		level_name = LevelManager.instance.current_level.name
	_level_label.text = "Aktuelles Gebiet: %s" % level_name


func _on_close_requested() -> void:
	visible = false
