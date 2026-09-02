class_name MainMenu extends Control

enum MenuState { LOGOS, INTRO, MAIN_MENU }

var current_state : MenuState = MenuState.LOGOS
var current_logo_index : int = 0
var intro_finished : bool = false

@export var logo_display_time : float = 2.0
@export var logo_fade_time : float = 1.0
@export var intro_scroll_speed : float = 30.0
@export var game_scene_path : String = "res://src/core/main_game/main_game.tscn"

@onready var logos_container: Control = $LogosContainer
@onready var logo_1: TextureRect = $LogosContainer/Logo1
@onready var logo_2: TextureRect = $LogosContainer/Logo2
@onready var intro_container: Control = $IntroContainer
@onready var intro_text: Label = $IntroContainer/IntroText
@onready var main_menu_container: Control = $MainMenuContainer
@onready var start_button: Button = $MainMenuContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $MainMenuContainer/VBoxContainer/QuitButton
@onready var title_label: Label = $MainMenuContainer/TitleLabel
@onready var fade_rect: ColorRect = $FadeRect
@onready var skip_hint: Label = $SkipHint

var logo_textures : Array[Texture2D] = []
var intro_text_start_y : float = 0.0


func _ready() -> void:
	# Alle Container verstecken
	logos_container.visible = true
	intro_container.visible = false
	main_menu_container.visible = false

	# Logos unsichtbar machen
	logo_1.modulate.a = 0.0
	logo_2.modulate.a = 0.0

	# Fade Rect setup
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0

	# Button Signale verbinden
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Intro Text Position speichern
	intro_text_start_y = get_viewport().get_visible_rect().size.y

	# Skip Hint sichtbar machen
	skip_hint.visible = true
	skip_hint.modulate.a = 0.0

	# Starte mit Logo-Sequenz
	_start_logo_sequence()


func _process(delta: float) -> void:
	if current_state == MenuState.INTRO:
		_process_intro(delta)


func _input(event: InputEvent) -> void:
	# Skip mit beliebiger Taste während Logos oder Intro
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			match current_state:
				MenuState.LOGOS:
					_skip_to_intro()
				MenuState.INTRO:
					_skip_to_main_menu()


func _start_logo_sequence() -> void:
	current_state = MenuState.LOGOS

	# Fade aus Schwarz
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "modulate:a", 0.0, logo_fade_time)
	fade_tween.parallel().tween_property(skip_hint, "modulate:a", 1.0, logo_fade_time * 2)
	await fade_tween.finished

	# Logo 1 einblenden
	await _show_logo(logo_1)

	# Logo 2 einblenden
	await _show_logo(logo_2)

	# Weiter zum Intro
	_start_intro()


func _show_logo(logo: TextureRect) -> void:
	if current_state != MenuState.LOGOS:
		return

	# Einblenden
	var fade_in = create_tween()
	fade_in.tween_property(logo, "modulate:a", 1.0, logo_fade_time)
	await fade_in.finished

	if current_state != MenuState.LOGOS:
		return

	# Warten
	await get_tree().create_timer(logo_display_time).timeout

	if current_state != MenuState.LOGOS:
		return

	# Ausblenden
	var fade_out = create_tween()
	fade_out.tween_property(logo, "modulate:a", 0.0, logo_fade_time)
	await fade_out.finished


func _skip_to_intro() -> void:
	current_state = MenuState.INTRO

	# Alle laufenden Tweens stoppen
	logo_1.modulate.a = 0.0
	logo_2.modulate.a = 0.0
	fade_rect.modulate.a = 0.0

	_start_intro()


func _start_intro() -> void:
	current_state = MenuState.INTRO

	logos_container.visible = false
	intro_container.visible = true

	# Text nach unten positionieren (außerhalb des Bildschirms)
	intro_text.position.y = intro_text_start_y


func _process_intro(delta: float) -> void:
	# Text nach oben scrollen
	intro_text.position.y -= intro_scroll_speed * delta

	# Prüfen ob Text komplett durchgescrollt ist
	var text_end_y = intro_text.position.y + intro_text.size.y
	if text_end_y < 0:
		_start_main_menu()


func _skip_to_main_menu() -> void:
	_start_main_menu()


func _start_main_menu() -> void:
	current_state = MenuState.MAIN_MENU

	intro_container.visible = false
	main_menu_container.visible = true
	skip_hint.visible = false

	# Titel und Buttons einblenden
	title_label.modulate.a = 0.0
	start_button.modulate.a = 0.0
	quit_button.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 1.0)
	tween.tween_property(start_button, "modulate:a", 1.0, 0.5)
	tween.tween_property(quit_button, "modulate:a", 1.0, 0.5)

	# Focus auf Start Button
	start_button.grab_focus()


func _on_start_pressed() -> void:
	# Fade zu Schwarz und Spiel laden
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.0)
	await tween.finished

	get_tree().change_scene_to_file(game_scene_path)


func _on_quit_pressed() -> void:
	# Fade zu Schwarz und beenden
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
	await tween.finished

	get_tree().quit()
