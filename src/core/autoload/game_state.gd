extends Node

## Persistenter Weltzustand. Bleibt als Autoload, weil Flags und
## Input-Sperren szenenübergreifend gebraucht werden.
## Spielsysteme (Kampf, Shop, Dialog) leben unter MainGame/Systems.

var _flags: Dictionary = {}
var _input_lock_count: int = 0


func get_flag(key: String, default: Variant = false) -> Variant:
	return _flags.get(key, default)


func set_flag(key: String, value: Variant) -> void:
	_flags[key] = value


func has_flag(key: String) -> bool:
	return _flags.has(key)


func acquire_input_lock() -> void:
	_input_lock_count += 1


func release_input_lock() -> void:
	_input_lock_count = maxi(0, _input_lock_count - 1)


func is_player_input_locked() -> bool:
	return _input_lock_count > 0
