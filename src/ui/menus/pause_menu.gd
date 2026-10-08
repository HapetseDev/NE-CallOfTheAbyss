class_name PauseMenu extends Control

## Pause-/Spielmenü, aus TopBarHud verlinkt. Sperrt Spieler-Eingaben
## während es offen ist (wie Shop/Tausch/Stehlen/Debug-Editor).

@onready var _resume_button: Button = %ResumeButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	add_to_group("ui_sound_window")
	visible = false
	_resume_button.pressed.connect(close)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	var saves := Button.new()
	saves.text = "Speichern / Laden"
	saves.custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
	_resume_button.get_parent().add_child(saves)
	_resume_button.get_parent().move_child(saves, _resume_button.get_index() + 1)
	saves.pressed.connect(_open_saves)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	visible = true
	GameState.acquire_input_lock()


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.release_input_lock()


func _on_main_menu_pressed() -> void:
	close()
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_saves() -> void:
	close()
	if get_parent().get_node_or_null("SaveLoadMenu") != null:
		return
	var menu := preload("res://src/ui/menus/save_load_menu.gd").new()
	menu.name = "SaveLoadMenu"
	menu._can_save = true
	get_parent().add_child(menu)
