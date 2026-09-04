class_name CameraShotEvent
extends RefCounted

## Payload für CameraSystem.events. Nur das CameraSystem erzeugt diese Events.

const SOURCE_DIALOGUE := &"dialogue"
const SOURCE_RESTORE := &"restore"
const SOURCE_CINEMATIC := &"cinematic"

var source: StringName = SOURCE_DIALOGUE
var character: Node3D
var shot: CameraShot.Kind = CameraShot.Kind.MEDIUM
var look_target: Node3D
var look: CameraShot.Look = CameraShot.Look.AUTO
var shot_tags: PackedStringArray = PackedStringArray()
var duration: float = 0.0
var fov: float = 0.0


static func make(
	character: Node3D,
	shot: CameraShot.Kind,
	look_target: Node3D = null,
	duration: float = 0.0,
	look: CameraShot.Look = CameraShot.Look.AUTO,
	source: StringName = SOURCE_DIALOGUE
) -> RefCounted:
	var event := new()
	event.character = character
	event.shot = shot
	event.look_target = look_target
	event.duration = duration
	event.look = look
	event.source = source
	return event


static func make_restore(duration: float, fov: float = 0.0) -> RefCounted:
	var event := new()
	event.source = SOURCE_RESTORE
	event.duration = duration
	event.fov = fov
	return event


func is_restore() -> bool:
	return source == SOURCE_RESTORE
