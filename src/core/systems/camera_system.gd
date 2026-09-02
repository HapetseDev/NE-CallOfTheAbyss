class_name CameraSystem
extends Node

## Weltkamera unter MainGame. Das Level liefert Grenzen/Infos,
## dieses System entscheidet Target, Follow, Clamp und Cutscenes.

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

const GOLDEN_RATIO: float = 0.618

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


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
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
		if not LevelManager.instance.tilemap_bounds_changed.is_connected(_on_tilemap_bounds_changed):
			LevelManager.instance.tilemap_bounds_changed.connect(_on_tilemap_bounds_changed)


func get_camera() -> Camera3D:
	return camera


func set_enabled(enabled: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if camera:
		camera.current = enabled
	if enabled and target:
		_update_camera_position(1.0)


func set_target(new_target: Node3D, snap: bool = false) -> void:
	_disconnect_target_direction()
	target = new_target
	_connect_target_direction()
	if target and snap:
		_update_camera_position(1.0)


func begin_cutscene() -> void:
	_cutscene_active = true


func end_cutscene() -> void:
	_cutscene_active = false


func is_in_cutscene() -> bool:
	return _cutscene_active


func apply_level(level: BaseLevel) -> void:
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
	if target:
		_update_camera_position(1.0)


func _on_level_loaded(level: BaseLevel) -> void:
	apply_level(level)


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
	if _cutscene_active:
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
	if _cutscene_active:
		return
	target_look_offset = new_direction * look_ahead_distance * GOLDEN_RATIO


func _update_camera_position(delta: float) -> void:
	if target == null or camera == null:
		return
	current_offset = current_offset.lerp(target_look_offset, smooth_speed * 0.5 * delta)
	var focus := _clamp_focus(target.global_position)
	var base_offset := Vector3(0, camera_height, follow_distance)
	var look_offset_3d := Vector3(current_offset.x, 0, current_offset.z)
	var target_position := focus + base_offset + look_offset_3d
	if delta >= 1.0:
		camera.global_position = target_position
	else:
		camera.global_position = camera.global_position.lerp(target_position, smooth_speed * delta)
	camera.rotation_degrees = Vector3(pitch_angle, 0, 0)


func _clamp_focus(focus: Vector3) -> Vector3:
	if not _has_bounds:
		return focus
	focus.x = clampf(focus.x, _bounds.position.x, _bounds.end.x)
	focus.z = clampf(focus.z, _bounds.position.z, _bounds.end.z)
	return focus
