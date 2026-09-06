class_name PauseMenu extends Control

## Pause-/Spielmenü, aus TopBarHud verlinkt. Sperrt Spieler-Eingaben
## während es offen ist (wie Shop/Tausch/Stehlen/Debug-Editor).

@onready var _resume_button: Button = %ResumeButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(close)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


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
