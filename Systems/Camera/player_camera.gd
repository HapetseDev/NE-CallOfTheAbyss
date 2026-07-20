class_name PlayerCamera extends Camera3D

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

var target: Node3D
var current_offset: Vector3 = Vector3.ZERO
var target_look_offset: Vector3 = Vector3.ZERO
var _height_distance_ratio := 0.75


func _ready() -> void:
	target = get_parent()
	if follow_distance > 0.0:
		_height_distance_ratio = camera_height / follow_distance
	else:
		_height_distance_ratio = 0.75
	if target:
		_update_camera_position(1.0)
		if target.has_signal("direction_changed"):
			target.direction_changed.connect(_on_direction_changed)


func _unhandled_input(event: InputEvent) -> void:
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


func _on_direction_changed(new_direction: Vector3) -> void:
	target_look_offset = new_direction * look_ahead_distance * GOLDEN_RATIO


func _update_camera_position(delta: float) -> void:
	current_offset = current_offset.lerp(target_look_offset, smooth_speed * 0.5 * delta)
	var base_offset := Vector3(0, camera_height, follow_distance)
	var look_offset_3d := Vector3(current_offset.x, 0, current_offset.z)
	var target_position := target.global_position + base_offset + look_offset_3d
	global_position = global_position.lerp(target_position, smooth_speed * delta)
	rotation_degrees = Vector3(pitch_angle, 0, 0)
