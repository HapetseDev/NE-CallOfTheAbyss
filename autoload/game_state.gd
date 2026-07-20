extends Node

var _flags: Dictionary = {}


func get_flag(key: String, default: Variant = false) -> Variant:
	return _flags.get(key, default)


func set_flag(key: String, value: Variant) -> void:
	_flags[key] = value


func has_flag(key: String) -> bool:
	return _flags.has(key)
