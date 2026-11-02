extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	var original_speed := DialogueSettings.speed_index
	var original_sound := DialogueSettings.sound_enabled
	var config := ConfigFile.new()
	for index in 4:
		config.set_value("dialogue", "speed", index)
		config.set_value("dialogue", "sound", true)
		DialogueSettings.load_preferences(config)
		check(is_equal_approx(DialogueSettings.seconds_per_character(), [0.06, 0.03, 0.015, 0.0][index]), "Tempo %d" % index)
		check(DialogueSettings.sound_enabled, "Tonoption geladen")
	config.set_value("dialogue", "speed", "invalid")
	config.set_value("dialogue", "sound", 12)
	DialogueSettings.load_preferences(config)
	check(DialogueSettings.speed_index == 1 and not DialogueSettings.sound_enabled, "Ungültige Einstellungen erhalten sichere Vorgaben")
	var path: String = DialogueSettings.SETTINGS_PATH
	var existed := FileAccess.file_exists(path)
	var original := FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	DialogueSettings.set_option("speed", 2)
	DialogueSettings.set_option("sound", true)
	var reloaded: Node = load("res://src/core/autoload/dialogue_settings.gd").new()
	reloaded._ready()
	check(reloaded.speed_index == 2 and reloaded.sound_enabled, "Einstellungen überstehen Neustart des Diensts")
	reloaded.free()
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else:
		DirAccess.remove_absolute(path)
	var character := CharacterResource.new()
	character.voice = 0.75
	var codec := WorldValueCodec.new()
	var encoded: Dictionary = codec.encode(character)
	var restored: CharacterResource = codec.decode(encoded)
	check(not codec.failed and restored.voice == 0.75, "Voice überlebt Speicherung und Laden")
	encoded.value.erase("voice")
	var old := WorldValueCodec.new()
	old.migrate_legacy_voice = true
	restored = old.decode(encoded)
	check(not old.failed and restored.voice == 1.0, "Alte Charakterdaten migrieren zu Standardstimme")
	for invalid in [0.0, -1.0, 5.0, "hoch", INF]:
		encoded.value.voice = invalid
		var invalid_codec := WorldValueCodec.new()
		invalid_codec.decode(encoded)
		check(invalid_codec.failed, "Ungültiger Voice-Wert abgewiesen: " + str(invalid))
	DialogueSettings.speed_index = original_speed
	DialogueSettings.sound_enabled = original_sound
	print("dialogue_settings: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
