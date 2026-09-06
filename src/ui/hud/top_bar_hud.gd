class_name TopBarHud extends PanelContainer

## Oberer Navigationsstreifen: Zugriff auf Inventar, Charakterbogen, Karte,
## Log, (Pause-)Menü und Debug. Das Rechtsklick-Aktionsmenü
## (state_action_menu.gd) bleibt dadurch auf reine Interaktionsaktionen
## beschränkt – alle "Fenster öffnen"-Funktionen leben hier.

signal inventory_pressed
signal character_pressed
signal map_pressed
signal log_pressed
signal menu_pressed
signal debug_pressed

@onready var _inventory_button: Button = %InventoryButton
@onready var _character_button: Button = %CharacterButton
@onready var _map_button: Button = %MapButton
@onready var _log_button: Button = %LogButton
@onready var _menu_button: Button = %MenuButton
@onready var _debug_button: Button = %DebugButton


func _ready() -> void:
	for button in [_inventory_button, _character_button, _map_button, _log_button, _menu_button, _debug_button]:
		(button as Button).custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
	_inventory_button.pressed.connect(func() -> void: inventory_pressed.emit())
	_character_button.pressed.connect(func() -> void: character_pressed.emit())
	_map_button.pressed.connect(func() -> void: map_pressed.emit())
	_log_button.pressed.connect(func() -> void: log_pressed.emit())
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	_debug_button.pressed.connect(func() -> void: debug_pressed.emit())
