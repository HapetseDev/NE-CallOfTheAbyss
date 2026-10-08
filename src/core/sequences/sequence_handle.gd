class_name SequenceHandle extends RefCounted

signal completed(result: Dictionary)

var _terminal: bool = false
var _result: Dictionary = {}
var _remaining: float = -1.0

func finish(status: StringName = &"SUCCESS", code: StringName = &"", message: String = "", data: Dictionary = {}) -> void:
	if _terminal:
		return
	_terminal = true
	_result = {"status": status, "error_code": code, "message": message, "data": data.duplicate(true)}
	completed.emit(get_result())

func wait_for(seconds: float) -> void:
	_remaining = seconds

func tick(delta: float) -> void:
	if _terminal or _remaining < 0.0:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		finish()

func cancel(reason: StringName = &"cancelled") -> void:
	finish(&"CANCELLED", reason)

func is_terminal() -> bool:
	return _terminal

func get_result() -> Dictionary:
	return _result.duplicate(true)
