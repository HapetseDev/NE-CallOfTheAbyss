class_name Player extends Playable

## Steuerbare Partyfigur mit umschaltbarer Anführer-/Begleiterrolle.
var is_player_controlled := true

@export var follow_distance: float = 1.35
@export var follow_speed: float = 2.475
@export var arrive_distance_sq: float = 0.14

var leader: Playable
var _was_moving: bool = false
var _follow_enabled: bool = true


## Linksklick halten → Richtung zum Maus-Zielpunkt; Loslassen = Stopp.
const GROUND_PICKER := preload("res://src/gameplay/character/player/mouse_ground_picker.gd")

@export_group("Maus-Bewegung")
@export var mouse_speed_min: float = 0.525
@export var mouse_speed_max: float = 3.75
@export var mouse_dist_min: float = 0.5
@export var mouse_dist_max: float = 9.0
@export_range(0.2, 3.0) var mouse_floor_height_range: float = 1.25
var _mouse_target_valid := false

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hurt_box: HurtBox = %AttackHurtBox
@onready var _inventory_layer: CanvasLayer = $InventoryLayer
@onready var _inventory_ui: InventoryUI = $InventoryLayer/InventoryUI
@onready var _character_sheet_layer: CanvasLayer = $CharacterSheetLayer
@onready var _character_sheet_ui: CharacterSheetUI = $CharacterSheetLayer/CharacterSheetUI

var _mouse_lmb_held: bool = false
var _mouse_target: Vector3 = Vector3.ZERO
var _mouse_locomotion_speed: float = 0.0


func clear_click_move() -> void:
	_mouse_lmb_held = false
	_mouse_target_valid = false
	_mouse_locomotion_speed = 0.0


func uses_mouse_locomotion() -> bool:
	return _mouse_lmb_held and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func get_mouse_locomotion_speed() -> float:
	return _mouse_locomotion_speed


func _init() -> void:
	floor_snap_length = 0.4
	step_height = 0.35


func _ready() -> void:
	footstep_player = $FootstepPlayer as FootstepPlayer
	state_machine.initialize(self)
	super._ready()
	set_player_controlled(is_player_controlled)
	_inventory_layer.visible = false
	_character_sheet_layer.visible = false
	_inventory_ui.bind_player(self, _find_party())
	_character_sheet_ui.bind_player(self)
	if character and not character.sheet_changed.is_connected(_on_character_sheet_changed):
		character.sheet_changed.connect(_on_character_sheet_changed)


func _process(delta: float) -> void:
	if not is_player_controlled:
		super._process(delta)
		return
	if not GameState.is_player_input_locked():
		if Input.is_action_just_pressed("Inventar"):
			toggle_inventory()
		if Input.is_action_just_pressed("Charakterbogen"):
			toggle_character_sheet()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_lmb_held = false
	elif _mouse_lmb_held:
		_update_mouse_locomotion()
	super._process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not is_player_controlled or GameState.is_player_input_locked():
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
	_mouse_target_valid = maybe_point is Vector3
	if not _mouse_target_valid:
		_mouse_locomotion_speed = 0.0
		return
	_mouse_target = maybe_point
	var offset := _mouse_target - global_position
	offset.y = 0.0
	var dist := offset.length()
	var t := inverse_lerp(mouse_dist_min, mouse_dist_max, dist)
	_mouse_locomotion_speed = lerpf(mouse_speed_min, mouse_speed_max, clampf(t, 0.0, 1.0))


func _ground_point_under_mouse() -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	return GROUND_PICKER.pick(self, origin, dir, mouse_floor_height_range)


# Spielereingabe als Bewegungsrichtung
func get_move_direction() -> Vector3:
	if not is_player_controlled or GameState.is_player_input_locked():
		return Vector3.ZERO
	var kx := Input.get_axis("Left", "Right")
	var kz := Input.get_axis("Up", "Down")
	var wasd := Vector3(kx, 0.0, kz)
	if wasd.length_squared() > 0.0001:
		clear_click_move()
		return wasd.normalized()
	if uses_mouse_locomotion() and _mouse_target_valid:
		var to := _mouse_target - global_position
		to.y = 0.0
		if to.length_squared() < 0.0004:
			return Vector3.ZERO
		return to.normalized()
	return Vector3.ZERO


func toggle_inventory() -> void:
	if MainGame.instance and MainGame.instance.game_windows:
		MainGame.instance.game_windows.open_page(2)
		return
	if not is_player_controlled:
		return
	_inventory_layer.visible = not _inventory_layer.visible
	_sync_hud_with_inventory()


func toggle_character_sheet() -> void:
	if MainGame.instance and MainGame.instance.game_windows:
		MainGame.instance.game_windows.open_page(1)
		return
	if not is_player_controlled:
		return
	_character_sheet_layer.visible = not _character_sheet_layer.visible
	if _character_sheet_layer.visible:
		_character_sheet_ui.refresh()
	_sync_hud_with_overlays()


func _find_party() -> Party:
	var node: Node = self
	while node:
		if node is Party:
			return node as Party
		node = node.get_parent()
	return null


func _sync_hud_with_inventory() -> void:
	_sync_hud_with_overlays()


func _sync_hud_with_overlays() -> void:
	var found_party := _find_party()
	if found_party:
		var hud_visible := not _inventory_layer.visible and not _character_sheet_layer.visible
		found_party.set_game_hud_visible(hud_visible)


func _on_character_sheet_changed() -> void:
	if _character_sheet_layer.visible:
		_character_sheet_ui.refresh()


func set_leader(p: Playable) -> void:
	leader = p


## Rollenwechsel behält Node, Position und CharacterResource unverändert.
func set_player_controlled(controlled: bool) -> void:
	is_player_controlled = controlled
	clear_click_move()
	_stop_follow_motion()
	if controlled:
		leader = null
		remove_from_group("interactable")
	else:
		add_to_group("interactable")
		_inventory_layer.hide()
		_character_sheet_layer.hide()
	set_follow_enabled(not controlled)
	state_machine.change_state(state_machine.get_node("Idle") as State)
	state_machine.process_mode = Node.PROCESS_MODE_INHERIT if controlled else Node.PROCESS_MODE_DISABLED


func enter_combat_mode(session: CombatSession) -> void:
	set_follow_enabled(false)
	super.enter_combat_mode(session)


func exit_combat_mode() -> void:
	super.exit_combat_mode()
	state_machine.process_mode = Node.PROCESS_MODE_INHERIT if is_player_controlled else Node.PROCESS_MODE_DISABLED
	set_follow_enabled(not is_player_controlled)


## Während aktiver Kampfteilnahme (nicht nur im eigenen Zug) soll ein Follower
## dem Leader nicht hinterherlaufen – sonst würde er sich mitten im Kampf
## umherbewegen, während Initiative-Uhr/Kampfmenü über ihn entscheiden.
func set_follow_enabled(enabled: bool) -> void:
	_follow_enabled = enabled
	if not enabled:
		_stop_follow_motion()


func _physics_process(delta: float) -> void:
	_update_follow(delta)
	super._physics_process(delta)


func _update_follow(_delta: float) -> void:
	if not _follow_enabled:
		return
	if GameState.is_player_input_locked():
		_stop_follow_motion()
		return
	if leader == null or not is_instance_valid(leader):
		_stop_follow_motion()
		return

	var target_pos := _get_follow_target_position()
	var to := target_pos - global_position
	to.y = 0.0
	var moving := to.length_squared() > arrive_distance_sq

	if moving:
		direction = to.normalized()
		set_direction()
		set_horizontal_velocity(direction * follow_speed)
		update_animation("walk")
		if footstep_player and not _was_moving:
			footstep_player.start_walking(false)
	else:
		direction = Vector3.ZERO
		stop_horizontal_velocity()
		update_animation("idle")
		if footstep_player and _was_moving:
			footstep_player.stop_walking()

	_was_moving = moving


func _stop_follow_motion() -> void:
	direction = Vector3.ZERO
	stop_horizontal_velocity()
	if footstep_player and _was_moving:
		footstep_player.stop_walking()
	_was_moving = false


func _get_follow_target_position() -> Vector3:
	var back := Vector3(-leader.facing_direction.x, 0.0, -leader.facing_direction.z)
	if back.length_squared() < 0.01:
		back = Vector3(0.0, 0.0, 1.0)
	return leader.global_position + back.normalized() * follow_distance


# --- E-Menü-Interaktion (state_action_menu.gd, "interactable"-Gruppe) ---
# Direkt auf dem Follower selbst statt über eine eigene Interaction-Node
# (wie bei NPCs) - der Follower ist bereits sein eigener Node3D-Wurzelknoten,
# eine zusätzliche Ebene wäre hier nur Overhead.

func get_actions(_player: Playable) -> Array[Dictionary]:
	if is_player_controlled or _player == self:
		return []
	return [{"label": "Tauschen", "action_id": "trade_party"}]


func perform_action(action_id: String, player: Playable) -> void:
	if action_id == "trade_party":
		PartyTradeManager.open(player, self)
