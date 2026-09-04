class_name CameraEventHub
extends RefCounted

## Kamera-Events. Nur CameraSystem darf notify_* aufrufen.
## Listener verbinden sich über listen_* und trennen in _exit_tree.

signal shot_changed(event)
signal transition_finished(event)
signal control_returned()


func notify_shot_changed(event: Variant) -> void:
	if event == null:
		return
	shot_changed.emit(event)


func notify_transition_finished(event: Variant) -> void:
	if event == null:
		return
	transition_finished.emit(event)


func notify_control_returned() -> void:
	control_returned.emit()


func listen_shot_changed(callback: Callable) -> void:
	if callback.is_valid() and not shot_changed.is_connected(callback):
		shot_changed.connect(callback)


func unlisten_shot_changed(callback: Callable) -> void:
	if shot_changed.is_connected(callback):
		shot_changed.disconnect(callback)


func listen_transition_finished(callback: Callable) -> void:
	if callback.is_valid() and not transition_finished.is_connected(callback):
		transition_finished.connect(callback)


func unlisten_transition_finished(callback: Callable) -> void:
	if transition_finished.is_connected(callback):
		transition_finished.disconnect(callback)


func listen_control_returned(callback: Callable) -> void:
	if callback.is_valid() and not control_returned.is_connected(callback):
		control_returned.connect(callback)


func unlisten_control_returned(callback: Callable) -> void:
	if control_returned.is_connected(callback):
		control_returned.disconnect(callback)
