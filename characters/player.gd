class_name Player extends Playable

## Linksklick halten → Richtung zum Maus-Zielpunkt; Loslassen = Stopp.
const CLICK_RAY_LENGTH := 2000.0

@export_group("Maus-Bewegung")
@export var mouse_speed_min: float = 0.35
@export var mouse_speed_max: float = 2.5
@export var mouse_dist_min: float = 0.5
@export var mouse_dist_max: float = 9.0

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hurt_box: HurtBox = %AttackHurtBox

var _inventory_layer: CanvasLayer
var _mouse_lmb_held: bool = false
var _mouse_target: Vector3 = Vector3.ZERO
var _mouse_locomotion_speed: float = 0.0


func clear_click_move() -> void:
	_mouse_lmb_held = false
	_mouse_locomotion_speed = 0.0


func uses_mouse_locomotion() -> bool:
	return _mouse_lmb_held and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func get_mouse_locomotion_speed() -> float:
	return _mouse_locomotion_speed


func _ready() -> void:
	footstep_player = $FootstepPlayer as FootstepPlayer
	state_machine.initialize(self)
	super._ready()
	_inventory_layer = CanvasLayer.new()
	_inventory_layer.layer = 25
	_inventory_layer.visible = false
	add_child(_inventory_layer)
	var ui := InventoryUI.new()
	ui.playable = self
	ui.party = _find_party()
	_inventory_layer.add_child(ui)
	if inventory.is_empty():
		add_item(load("res://Resources/Items/messer.tres") as Item)


func _process(delta: float) -> void:
	super._process(delta)
	if Input.is_action_just_pressed("Inventar"):
		_inventory_layer.visible = not _inventory_layer.visible
		_sync_hud_with_inventory()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_lmb_held = false
	elif _mouse_lmb_held:
		_update_mouse_locomotion()


func _unhandled_input(event: InputEvent) -> void:
	if GameDialogueBridge.is_player_input_locked():
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		var maybe_point: Variant = _ground_point_under_mouse()
		if maybe_point == null:
			return
		_mouse_target = maybe_point as Vector3
		_mouse_lmb_held = true
		_update_mouse_locomotion()
		get_viewport().set_input_as_handled()
	else:
		clear_click_move()
		get_viewport().set_input_as_handled()


func _update_mouse_locomotion() -> void:
	var maybe_point: Variant = _ground_point_under_mouse()
	if maybe_point is Vector3:
		_mouse_target = maybe_point
	var offset := _mouse_target - global_position
	offset.y = 0.0
	var dist := offset.length()
	var t := inverse_lerp(mouse_dist_min, mouse_dist_max, dist)
	_mouse_locomotion_speed = lerpf(mouse_speed_min, mouse_speed_max, clampf(t, 0.0, 1.0))


func _ground_point_under_mouse() -> Variant:
	var cam := $Camera3D as Camera3D
	if cam == null:
		return null
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var to := origin + dir * CLICK_RAY_LENGTH

	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return null

	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var pos: Vector3 = hit.position
	return Vector3(pos.x, 0.0, pos.z)


# Spielereingabe als Bewegungsrichtung
func get_move_direction() -> Vector3:
	if GameDialogueBridge.is_player_input_locked():
		return Vector3.ZERO
	var kx := Input.get_axis("Left", "Right")
	var kz := Input.get_axis("Up", "Down")
	var wasd := Vector3(kx, 0.0, kz)
	if wasd.length_squared() > 0.0001:
		clear_click_move()
		return wasd.normalized()
	if uses_mouse_locomotion():
		var to := _mouse_target - global_position
		to.y = 0.0
		if to.length_squared() < 0.0004:
			return Vector3.ZERO
		return to.normalized()
	return Vector3.ZERO


func _find_party() -> Party:
	var node: Node = self
	while node:
		if node is Party:
			return node as Party
		node = node.get_parent()
	return null


func _sync_hud_with_inventory() -> void:
	var found_party := _find_party()
	if found_party:
		found_party.set_game_hud_visible(not _inventory_layer.visible)
