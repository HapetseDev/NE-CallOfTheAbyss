extends RefCounted

## Eine eigenständige Datei pro manuellem Spielstand, ohne feste Slot-Anzahl.
## Der Titel im Dateinamen ist nur Anzeige; Weltprüfung bleibt beim WorldSaveStore.
var directory: String = "user://saves"
var last_error: String = ""

func entries() -> Array[Dictionary]:
	last_error = ""
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(directory):
		return result
	var dir := DirAccess.open(directory)
	if dir == null:
		last_error = "Der Speicherordner kann nicht gelesen werden."
		return result
	for filename in dir.get_files():
		if not filename.ends_with(".json"):
			continue
		var path := directory.path_join(filename)
		var title := filename.get_basename()
		if title.length() > 34 and title.substr(32, 2) == "--":
			title = title.substr(34)
		result.append({"path": path, "title": title, "modified": FileAccess.get_modified_time(path)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.path < b.path if a.modified == b.modified else a.modified > b.modified)
	return result

func save_new(title: String, manager: LevelManager) -> Dictionary:
	last_error = ""
	if manager == null:
		return {"error": ERR_UNAVAILABLE, "path": ""}
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		last_error = "Der Speicherordner kann nicht angelegt werden."
		return {"error": error, "path": ""}
	var name := _safe_title(title)
	var path := directory.path_join(Crypto.new().generate_random_bytes(16).hex_encode() + "--" + name + ".json")
	while FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp"):
		path = directory.path_join(Crypto.new().generate_random_bytes(16).hex_encode() + "--" + name + ".json")
	error = manager.save_world(path)
	if error != OK:
		last_error = "Speichern ist während Kampf oder Interaktion gesperrt." if error == ERR_BUSY else "Spielstand konnte nicht gespeichert werden (Fehler %d)." % error
	return {"error": error, "path": path if error == OK else ""}

func _safe_title(title: String) -> String:
	var result := ""
	for character in title.strip_edges():
		var safe := "_" if character in '/\\:*?"<>|' or character.unicode_at(0) < 32 else character
		if (result + safe).to_utf8_buffer().size() > 80:
			break
		result += safe
	result = result.strip_edges().trim_suffix(".")
	return result if not result.is_empty() else "Spielstand"
