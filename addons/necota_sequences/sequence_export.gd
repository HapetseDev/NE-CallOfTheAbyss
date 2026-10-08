@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "NecotaSequenceText"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_add_directory("res://src/resources/sequences")

func _add_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.ends_with(".sequence"):
			var source_path := path.path_join(filename)
			add_file(source_path, FileAccess.get_file_as_bytes(source_path), false)
	for child in directory.get_directories():
		_add_directory(path.path_join(child))
