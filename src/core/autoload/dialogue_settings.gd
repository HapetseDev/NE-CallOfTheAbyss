extends Node

## Local conversation preferences, independent of game saves.
const SETTINGS_PATH := "user://dialogue.cfg"
const SPEED_LABELS := ["Langsam", "Normal", "Schnell", "Sofort"]
const STEP_SECONDS := [0.06, 0.03, 0.015, 0.0]
var speed_index := 1
var sound_enabled := false

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		load_preferences(config)

func load_preferences(config: ConfigFile) -> void:
	var speed: Variant = config.get_value("dialogue", "speed", 1)
	speed_index = clampi(speed, 0, 3) if speed is int else 1
	var sound: Variant = config.get_value("dialogue", "sound", false)
	sound_enabled = sound if sound is bool else false

func seconds_per_character() -> float:
	return STEP_SECONDS[speed_index]

func set_option(option: String, value: Variant) -> void:
	match option:
		"speed": speed_index = clampi(int(value), 0, 3)
		"sound": sound_enabled = bool(value)
		_: return
	var config := ConfigFile.new()
	config.set_value("dialogue", "speed", speed_index)
	config.set_value("dialogue", "sound", sound_enabled)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Gesprächseinstellungen konnten nicht gespeichert werden: " + error_string(error))
