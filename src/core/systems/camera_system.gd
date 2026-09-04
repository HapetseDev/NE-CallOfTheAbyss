class_name CameraSystem
extends Node

## Weltkamera unter MainGame. Das Level liefert Grenzen/Infos,
## dieses System entscheidet Target, Follow, Clamp, Cutscenes und Dialog-Shots.
## Listener: CameraSystem.instance.events.shot_changed.connect(...)

static var instance: CameraSystem

@export var follow_distance: float = 8.0
@export var camera_height: float = 6.0
@export var pitch_angle: float = -45.0
@export var smooth_speed: float = 5.0
@export var look_ahead_distance: float = 3.0

@export_group("Zoom")
@export var zoom_distance_min := 3.5
@export var zoom_distance_max := 18.0
@export var zoom_step_scroll := 0.65

@export_group("Dialogkamera")
@export var dialogue_transition_sec: float = 0.35

const GOLDEN_RATIO: float = 0.618
const DEFAULT_LOOK_HEIGHT: float = 1.4

@onready var camera: Camera3D = $Camera3D

var target: Node3D
var current_offset: Vector3 = Vector3.ZERO
var target_look_offset: Vector3 = Vector3.ZERO

var _height_distance_ratio := 0.75
var _bounds: AABB
var _has_bounds: bool = false
var _explicit_bounds: bool = false
var _cutscene_active: bool = false
var _direction_connected_target: Node3D

var _dialogue_active: bool = false
var _camera_tween: Tween
var _saved_gameplay_transform: Transform3D
var _saved_gameplay_fov: float = 50.0
var _has_saved_gameplay_transform: bool = false
var _pending_event: CameraShotEvent

var events: CameraEventHub = CameraEventHub.new()


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	_kill_camera_tween()
	if instance == self:
		instance = null


func _ready() -> void:
	if follow_distance > 0.0:
		_height_distance_ratio = camera_height / follow_distance
	else:
		_height_distance_ratio = 0.75
	camera.current = true
	if LevelManager.instance:
		if not LevelManager.instance.level_loaded.is_connected(_on_level_loaded):
			LevelManager.instance.level_loaded.connect(_on_level_loaded)
		if not LevelManager.instance.level_unloaded.is_connected(_on_level_unloaded):
			LevelManager.instance.level_unloaded.connect(_on_level_unloaded)
		if not LevelManager.instance.tilemap_bounds_changed.is_connected(_on_tilemap_bounds_changed):
			LevelManager.instance.tilemap_bounds_changed.connect(_on_tilemap_bounds_changed)
	_connect_dialogue_signals()


func get_camera() -> Camera3D:
	return camera


func set_enabled(enabled: bool) -> void:
	if not enabled:
		_release_dialogue_camera(true)
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if camera:
		camera.current = enabled
	if enabled and target and not _dialogue_active:
		_update_camera_position(1.0)


func set_target(new_target: Node3D, snap: bool = false) -> void:
	_disconnect_target_direction()
	target = new_target
	_connect_target_direction()
	if target and snap and not _dialogue_active:
		_update_camera_position(1.0)


func begin_cutscene() -> void:
	_cutscene_active = true


func end_cutscene() -> void:
	_cutscene_active = false


func is_in_cutscene() -> bool:
	return _cutscene_active


func apply_level(level: BaseLevel) -> void:
	_release_dialogue_camera(true)
	_explicit_bounds = false
	_has_bounds = false
	if level == null:
		return
	var bounds := level.get_camera_bounds()
	if bounds.size.length_squared() > 0.001:
		_bounds = bounds
		_has_bounds = true
		_explicit_bounds = true
	elif LevelManager.instance:
		_apply_tilemap_corners(LevelManager.instance.current_tilemap_bounds)
	_apply_settings(level.get_camera_settings())
	if target and not _dialogue_active:
		_update_camera_position(1.0)


func show_dialogue_shot(
	character: Node3D,
	shot: Variant,
	look_target: Node3D = null,
	look: Variant = CameraShot.Look.AUTO,
	shot_tags: PackedStringArray = PackedStringArray(),
	source: StringName = CameraShotEvent.SOURCE_DIALOGUE
) -> void:
	if camera == null:
		return
	if character == null or not is_instance_valid(character):
		return
	_ensure_dialogue_mode()
	var kind := CameraShot.coerce(shot)
	var points := DialogueCameraPoints.find_in(character)
	var marker: Marker3D = null
	if points:
		if CameraShot.is_concrete(kind):
			marker = points.resolve_marker(kind)
		else:
			marker = points.resolve_marker(CameraShot.Kind.RANDOM, shot_tags)
		if marker:
			kind = points.marker_kind(marker)
		elif kind == CameraShot.Kind.RANDOM:
			kind = CameraShot.Kind.MEDIUM
	elif kind == CameraShot.Kind.RANDOM:
		kind = CameraShot.Kind.MEDIUM
	var origin: Vector3
	if marker != null and is_instance_valid(marker):
		origin = marker.global_position
	else:
		origin = _computed_shot_origin(character, kind)
	var look_kind := CameraShot.coerce_look(look)
	if look_kind == CameraShot.Look.AUTO:
		look_kind = CameraShot.default_look(kind)
	var look_node := _resolve_look_node(character, kind, look_target)
	var look_pos := _resolve_look_position(look_node, look_kind, points)
	var requested_fov := CameraShot.INHERIT_FOV
	var requested_duration := CameraShot.DEFAULT_TRANSITION_SEC
	var requested_ease: CameraShot.TransitionEase = CameraShot.TransitionEase.DEFAULT
	if marker is DialogueCameraMarker:
		var shot_marker := marker as DialogueCameraMarker
		requested_fov = shot_marker.fov
		requested_duration = shot_marker.transition_sec
		requested_ease = shot_marker.transition_ease
	var duration := CameraShot.resolve_duration(requested_duration, dialogue_transition_sec)
	var target_fov := CameraShot.resolve_fov(requested_fov, camera.fov)
	var event: CameraShotEvent = CameraShotEvent.make(character, kind, look_node, duration, look_kind, source) as CameraShotEvent
	event.shot_tags = shot_tags
	event.fov = target_fov
	_pending_event = event
	events.notify_shot_changed(event)
	_tween_camera_to(
		_shot_transform(origin, look_pos),
		duration,
		target_fov,
		requested_ease,
		_on_shot_transition_finished
	)


func restore_gameplay_camera() -> void:
	if not _dialogue_active:
		return
	if camera == null:
		_leave_dialogue_mode()
		return
	var restore_xf := _saved_gameplay_transform if _has_saved_gameplay_transform else _gameplay_transform()
	var restore_fov := _saved_gameplay_fov if _has_saved_gameplay_transform else camera.fov
	_pending_event = CameraShotEvent.make_restore(dialogue_transition_sec, restore_fov) as CameraShotEvent
	_tween_camera_to(
		restore_xf,
		dialogue_transition_sec,
		restore_fov,
		CameraShot.TransitionEase.DEFAULT,
		_on_restore_transition_finished
	)


func _on_level_loaded(level: BaseLevel) -> void:
	apply_level(level)


func _on_level_unloaded(_path: String) -> void:
	_release_dialogue_camera(true)


func _on_tilemap_bounds_changed(corners: Array[Vector3]) -> void:
	if _explicit_bounds:
		return
	_apply_tilemap_corners(corners)


func _apply_tilemap_corners(corners: Array[Vector3]) -> void:
	if corners.size() < 2:
		return
	var a := corners[0]
	var b := corners[1]
	_bounds = AABB(a, b - a).abs()
	_has_bounds = _bounds.size.length_squared() > 0.001


func _apply_settings(settings: Dictionary) -> void:
	if settings.is_empty():
		return
	if settings.has("follow_distance"):
		follow_distance = float(settings["follow_distance"])
	if settings.has("camera_height"):
		camera_height = float(settings["camera_height"])
	if settings.has("pitch_angle"):
		pitch_angle = float(settings["pitch_angle"])
	if settings.has("smooth_speed"):
		smooth_speed = float(settings["smooth_speed"])
	if settings.has("look_ahead_distance"):
		look_ahead_distance = float(settings["look_ahead_distance"])
	if follow_distance > 0.0:
		_height_distance_ratio = camera_height / follow_distance


func _unhandled_input(event: InputEvent) -> void:
	if _cutscene_active or _dialogue_active:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(+zoom_step_scroll)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(-zoom_step_scroll)
				get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_KP_ADD, KEY_EQUAL:
				_apply_zoom(-zoom_step_scroll)
				get_viewport().set_input_as_handled()
			KEY_KP_SUBTRACT, KEY_MINUS:
				_apply_zoom(+zoom_step_scroll)
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _dialogue_active:
		return
	if target:
		_update_camera_position(delta)


func _apply_zoom(distance_delta_signed: float) -> void:
	var new_follow := clampf(follow_distance + distance_delta_signed, zoom_distance_min, zoom_distance_max)
	if is_equal_approx(new_follow, follow_distance):
		return
	follow_distance = new_follow
	camera_height = follow_distance * _height_distance_ratio


func _connect_target_direction() -> void:
	if target and target.has_signal("direction_changed"):
		if not target.direction_changed.is_connected(_on_direction_changed):
			target.direction_changed.connect(_on_direction_changed)
		_direction_connected_target = target


func _disconnect_target_direction() -> void:
	if _direction_connected_target and is_instance_valid(_direction_connected_target):
		if _direction_connected_target.has_signal("direction_changed"):
			if _direction_connected_target.direction_changed.is_connected(_on_direction_changed):
				_direction_connected_target.direction_changed.disconnect(_on_direction_changed)
	_direction_connected_target = null


func _on_direction_changed(new_direction: Vector3) -> void:
	if _cutscene_active or _dialogue_active:
		return
	target_look_offset = new_direction * look_ahead_distance * GOLDEN_RATIO


func _update_camera_position(delta: float) -> void:
	if target == null or camera == null:
		return
	current_offset = current_offset.lerp(target_look_offset, smooth_speed * 0.5 * delta)
	var xf := _gameplay_transform()
	if delta >= 1.0:
		camera.global_transform = xf
	else:
		camera.global_position = camera.global_position.lerp(xf.origin, smooth_speed * delta)
		camera.rotation_degrees = Vector3(pitch_angle, 0, 0)


func _gameplay_transform() -> Transform3D:
	var pos := camera.global_position if camera else Vector3.ZERO
	if target and is_instance_valid(target):
		var focus := _clamp_focus(target.global_position)
		var look_offset_3d := Vector3(current_offset.x, 0, current_offset.z)
		pos = focus + Vector3(0, camera_height, follow_distance) + look_offset_3d
	var xf := Transform3D.IDENTITY
	xf.origin = pos
	xf.basis = Basis.from_euler(Vector3(deg_to_rad(pitch_angle), 0.0, 0.0))
	return xf


func _clamp_focus(focus: Vector3) -> Vector3:
	if not _has_bounds:
		return focus
	focus.x = clampf(focus.x, _bounds.position.x, _bounds.end.x)
	focus.z = clampf(focus.z, _bounds.position.z, _bounds.end.z)
	return focus


func _connect_dialogue_signals() -> void:
	var ds := DialogueSystem.instance
	if ds == null:
		return
	if not ds.dialogue_started.is_connected(_on_dialogue_started):
		ds.dialogue_started.connect(_on_dialogue_started)
	if not ds.dialogue_line_changed.is_connected(_on_dialogue_line_changed):
		ds.dialogue_line_changed.connect(_on_dialogue_line_changed)
	if not ds.dialogue_ended.is_connected(_on_dialogue_ended):
		ds.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_started() -> void:
	_ensure_dialogue_mode()


func _on_dialogue_line_changed(
	subject: Node3D,
	shot: CameraShot.Kind,
	look_target: Node3D,
	look: CameraShot.Look = CameraShot.Look.AUTO,
	shot_tags: PackedStringArray = PackedStringArray()
) -> void:
	show_dialogue_shot(subject, shot, look_target, look, shot_tags)


func _on_dialogue_ended() -> void:
	restore_gameplay_camera()


func _ensure_dialogue_mode() -> void:
	if _dialogue_active:
		return
	_dialogue_active = true
	begin_cutscene()
	_saved_gameplay_transform = _gameplay_transform()
	_saved_gameplay_fov = camera.fov if camera else 50.0
	_has_saved_gameplay_transform = true


func _on_shot_transition_finished() -> void:
	if _pending_event and not _pending_event.is_restore():
		events.notify_transition_finished(_pending_event)


func _on_restore_transition_finished() -> void:
	if _pending_event:
		events.notify_transition_finished(_pending_event)
	_leave_dialogue_mode()


func _release_dialogue_camera(snap: bool) -> void:
	if not _dialogue_active:
		return
	_kill_camera_tween()
	if snap and camera and _has_saved_gameplay_transform:
		camera.global_transform = _saved_gameplay_transform
		camera.fov = _saved_gameplay_fov
	_leave_dialogue_mode()


func _leave_dialogue_mode() -> void:
	_kill_camera_tween()
	if camera and _has_saved_gameplay_transform:
		camera.fov = _saved_gameplay_fov
	var was_active := _dialogue_active
	_dialogue_active = false
	_has_saved_gameplay_transform = false
	_pending_event = null
	end_cutscene()
	if target and camera:
		_update_camera_position(1.0)
	if was_active:
		events.notify_control_returned()


func _resolve_look_node(character: Node3D, kind: CameraShot.Kind, look_target: Node3D) -> Node3D:
	if kind != CameraShot.Kind.OVER_SHOULDER:
		return character
	if look_target != null and is_instance_valid(look_target) and look_target != character:
		return look_target
	var ds := DialogueSystem.instance
	if ds == null:
		return character
	var npc := ds.get_active_npc()
	var player: Node3D = ds.get_current_player()
	if character == npc and player != null and is_instance_valid(player):
		return player
	if character == player and npc != null:
		return npc
	return character


func _computed_shot_origin(subject: Node3D, kind: CameraShot.Kind) -> Vector3:
	var focus := _focus_of(subject, null)
	var facing := Vector3(0.0, 0.0, 1.0)
	if subject != null and "facing_direction" in subject:
		var facing_value: Variant = subject.get("facing_direction")
		if facing_value is Vector3:
			facing = facing_value
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		facing = Vector3(0.0, 0.0, 1.0)
	else:
		facing = facing.normalized()
	var right := Vector3.UP.cross(facing)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	match kind:
		CameraShot.Kind.CLOSE:
			return focus + facing * 1.2 + right * 0.28
		CameraShot.Kind.WIDE:
			return focus + facing * 4.5 + right * 0.85 + Vector3.UP * 0.6
		CameraShot.Kind.PROFILE:
			return focus + right * 1.9 + facing * 0.3
		CameraShot.Kind.OVER_SHOULDER:
			return focus - facing * 1.15 - right * 0.5 + Vector3.UP * 0.15
		_:
			return focus + facing * 2.4 + right * 0.5 + Vector3.UP * 0.15


func _resolve_look_position(
	subject: Node3D,
	look: CameraShot.Look,
	fallback_points: DialogueCameraPoints
) -> Vector3:
	if subject == null or not is_instance_valid(subject):
		return camera.global_position + camera.global_basis * Vector3(0, 0, -2.0) if camera else Vector3.ZERO
	if look != CameraShot.Look.NONE:
		var looks := DialogueLookTargets.find_in(subject)
		if looks:
			var look_marker := looks.resolve_marker(look)
			if look_marker != null and is_instance_valid(look_marker):
				return look_marker.global_position
	var own_points := DialogueCameraPoints.find_in(subject)
	if own_points:
		return own_points.get_look_position(subject)
	if fallback_points:
		return fallback_points.get_look_position(subject)
	return subject.global_position + Vector3.UP * DEFAULT_LOOK_HEIGHT


func _focus_of(subject: Node3D, points: DialogueCameraPoints) -> Vector3:
	return _resolve_look_position(subject, CameraShot.Look.NONE, points)


func _shot_transform(origin: Vector3, look_pos: Vector3) -> Transform3D:
	if origin.distance_squared_to(look_pos) < 0.0004:
		origin += Vector3(0.0, 0.0, 0.25)
	return Transform3D(Basis.IDENTITY, origin).looking_at(look_pos, Vector3.UP)


func _tween_camera_to(
	xf: Transform3D,
	duration: float,
	target_fov: float = -1.0,
	transition_ease: CameraShot.TransitionEase = CameraShot.TransitionEase.DEFAULT,
	on_finished: Callable = Callable()
) -> void:
	_camera_tween = CameraShot.tween_camera(
		self,
		camera,
		xf,
		duration,
		target_fov,
		transition_ease,
		_camera_tween,
		on_finished
	)


func _kill_camera_tween() -> void:
	CameraShot.kill_tween(_camera_tween)
	_camera_tween = null
