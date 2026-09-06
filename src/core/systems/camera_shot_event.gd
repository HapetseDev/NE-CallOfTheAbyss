class_name CameraShotEvent
extends RefCounted

## Payload für CameraSystem.events. Nur das CameraSystem erzeugt diese Events.

const SOURCE_DIALOGUE := &"dialogue"
const SOURCE_RESTORE := &"restore"
const SOURCE_CINEMATIC := &"cinematic"
const SOURCE_COMBAT := &"combat"

var source: StringName = SOURCE_DIALOGUE
var character: Node3D
var shot: CameraShot.Kind = CameraShot.Kind.MEDIUM
var look_target: Node3D
var look: CameraShot.Look = CameraShot.Look.AUTO
var shot_tags: PackedStringArray = PackedStringArray()
var duration: float = 0.0
var fov: float = 0.0


static func make(
	p_character: Node3D,
	p_shot: CameraShot.Kind,
	p_look_target: Node3D = null,
	p_duration: float = 0.0,
	p_look: CameraShot.Look = CameraShot.Look.AUTO,
	p_source: StringName = SOURCE_DIALOGUE
) -> RefCounted:
	var event := new()
	event.character = p_character
	event.shot = p_shot
	event.look_target = p_look_target
	event.duration = p_duration
	event.look = p_look
	event.source = p_source
	return event


static func make_restore(p_duration: float, p_fov: float = 0.0) -> RefCounted:
	var event := new()
	event.source = SOURCE_RESTORE
	event.duration = p_duration
	event.fov = p_fov
	return event


func is_restore() -> bool:
	return source == SOURCE_RESTORE
