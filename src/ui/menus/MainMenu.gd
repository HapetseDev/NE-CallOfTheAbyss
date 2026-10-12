class_name MainMenu extends Control

@export_range(1.0, 120.0) var scene_duration := 24.0
@export_range(0.1, 10.0) var fade_duration := 3.0
@export var game_scene_path := "res://src/core/main_game/main_game.tscn"
## Optional Inspector override; otherwise load the agreed asset path.
@export var background_music: AudioStream
@export_file("*.mp3", "*.ogg", "*.wav") var music_path := "res://assets/audio/music/Main_Theme_Reprise.mp3"

const BACKGROUNDS: Array[PackedScene] = [
	preload("res://src/world/levels/title/pale_yellow_room.tscn"),
	preload("res://src/world/levels/title/red_room.tscn"),
	preload("res://src/world/levels/title/dark_blue_room.tscn"),
]
@onready var world: Node3D = $BackgroundViewport/Viewport/World
@onready var background_fade: ColorRect = $BackgroundFade
@onready var fade_rect: ColorRect = $FadeRect
@onready var start_button: Button = $MainMenuContainer/VBoxContainer/StartButton
@onready var load_button: Button = $MainMenuContainer/VBoxContainer/LoadButton
@onready var quit_button: Button = $MainMenuContainer/VBoxContainer/QuitButton
var background_index := 0
var room: Node3D
var camera: Camera3D
var elapsed := 0.0
var cycling := false
var busy := false
var cycle_tween: Tween

func _ready() -> void:
	background_fade.color = NEColors.TRANSITION_BLACK
	fade_rect.color = NEColors.TRANSITION_BLACK
	fade_rect.modulate.a = 0.0
	start_button.pressed.connect(_on_start_pressed)
	load_button.pressed.connect(_open_saves)
	quit_button.pressed.connect(_on_quit_pressed)
	_show_background()
	start_button.grab_focus()
	if background_music == null and ResourceLoader.exists(music_path):
		background_music = load(music_path) as AudioStream
	if background_music != null:
		$Music.stream = background_music
		$Music.finished.connect(func() -> void: $Music.play())
		$Music.play()

func _show_background() -> void:
	if is_instance_valid(room):
		world.remove_child(room)
		room.queue_free()
	room = BACKGROUNDS[background_index].instantiate()
	world.add_child(room)
	camera = room.get_node("Camera3D")
	elapsed = 0.0

func _process(delta: float) -> void:
	if busy:
		return
	elapsed += delta
	camera.position.y = lerpf(22.0, 8.0, minf(elapsed / (scene_duration + fade_duration), 1.0))
	if elapsed >= scene_duration and not cycling:
		_cycle_background()

func _cycle_background() -> void:
	cycling = true
	cycle_tween = create_tween()
	cycle_tween.tween_property(background_fade, "modulate:a", 1.0, fade_duration)
	cycle_tween.tween_callback(func() -> void:
		background_index = (background_index + 1) % BACKGROUNDS.size()
		_show_background())
	cycle_tween.tween_property(background_fade, "modulate:a", 0.0, fade_duration)
	cycle_tween.tween_callback(func() -> void: cycling = false)

func _unhandled_input(event: InputEvent) -> void:
	if busy or get_node_or_null("SaveLoadMenu") != null:
		return
	if event.is_action_pressed("Up") or event.is_action_pressed("Down"):
		var buttons := [start_button, load_button, quit_button]
		var index := buttons.find(get_viewport().gui_get_focus_owner())
		index = posmod(index + (-1 if event.is_action_pressed("Up") else 1), buttons.size())
		buttons[index].grab_focus()
		get_viewport().set_input_as_handled()

func _begin_transition() -> bool:
	if busy or get_node_or_null("SaveLoadMenu") != null:
		return false
	busy = true
	for button in [start_button, load_button, quit_button]:
		button.disabled = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return true

func _on_start_pressed() -> void:
	if not _begin_transition():
		return
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.0)
	await tween.finished
	if ResourceLoader.exists(game_scene_path):
		GameState.reset_session()
		var error := get_tree().change_scene_to_file(game_scene_path)
		if error == OK:
			return
	push_error("Spielszene konnte nicht geöffnet werden: " + game_scene_path)
	busy = false
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button in [start_button, load_button, quit_button]:
		button.disabled = false
	start_button.grab_focus()

func _on_quit_pressed() -> void:
	if not _begin_transition():
		return
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
	await tween.finished
	get_tree().quit()

func _open_saves() -> void:
	if busy or get_node_or_null("SaveLoadMenu") != null:
		return
	var menu := preload("res://src/ui/menus/save_load_menu.gd").new()
	menu.name = "SaveLoadMenu"
	menu.tree_exited.connect(func() -> void:
		if is_inside_tree() and not busy:
			load_button.grab_focus())
	add_child(menu)

func _exit_tree() -> void:
	if cycle_tween != null and cycle_tween.is_valid():
		cycle_tween.kill()
