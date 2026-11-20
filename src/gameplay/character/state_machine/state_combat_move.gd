class_name StateCombatMove extends State

## Nur im Kampf: Feld auswählen, dann den geprüften Rasterweg physisch ablaufen.
const GRID := preload("res://src/world/combat/combat_grid.gd")
@onready var combat_wait: State = $"../CombatWait"
@onready var combat_turn: State = $"../CombatTurn"
var _session: CombatSession
var _participant: CombatParticipant
var _fields: Dictionary = {}
var _selected := Vector2i.ZERO
var _done := false
var _moving := false
var _next_state: State
var _canvas_layer: CanvasLayer
var _vbox: VBoxContainer
var _camera_hold_id: int = 0

func enter() -> void:
	_done = false
	_moving = false
	_next_state = null
	_session = player.get_combat_session()
	_participant = _session.get_participant(player) if _session else null
	if _participant == null:
		_done = true
		_next_state = combat_wait
		return
	player.stop_horizontal_velocity()
	_fields = GRID.reachable(player, _session)
	_selected = GRID.cell(player.global_position)
	_camera_hold_id = get_instance_id()
	if CameraSystem.instance:
		CameraSystem.instance.hold_combat_camera(_camera_hold_id)
	_build_menu()
	_refresh()
	set_process_unhandled_input(true)

func exit() -> void:
	set_process_unhandled_input(false)
	if CameraSystem.instance:
		CameraSystem.instance.release_combat_camera(_camera_hold_id)
	_camera_hold_id = 0
	player.cancel_combat_path(get_instance_id())
	if is_instance_valid(_session) and is_instance_valid(_session.grid_display):
		_session.grid_display.show_fields({}, Vector2i.ZERO)
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null
	_vbox = null
	_fields.clear()

func process(_delta: float) -> State:
	if _done:
		return _next_state
	if not is_instance_valid(_session) or _session.state != CombatSession.SessionState.ACTIVE or _session.get_active_participant() != _participant or _participant.is_out_of_combat():
		return combat_wait
	return null

func handle_input(event: InputEvent) -> State:
	if _done or _moving or _canvas_layer == null:
		return null
	var step := Vector2i.ZERO
	if event.is_action_pressed("Left"):
		step.x -= 1
	if event.is_action_pressed("Right"):
		step.x += 1
	if event.is_action_pressed("Up"):
		step.y -= 1
	if event.is_action_pressed("Down"):
		step.y += 1
	if step != Vector2i.ZERO and _fields.has(_selected + step):
		_selected += step
		_refresh()
	return null

func _unhandled_input(event: InputEvent) -> void:
	if _canvas_layer == null or _done or _moving:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var camera := player.get_viewport().get_camera_3d()
		if camera == null:
			return
		var origin := camera.project_ray_origin(event.position)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(event.position) * 1000.0, player.collision_mask, GRID._exclusions(player))
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and _fields.has(GRID.cell(hit.position)):
			_selected = GRID.cell(hit.position)
			_refresh()
			player.get_viewport().set_input_as_handled()

func _build_menu() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	player.add_child(_canvas_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(root)
	var alignment := CenterContainer.new()
	alignment.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	alignment.offset_top = -NEDimensions.SPACING_XL * 7
	alignment.offset_bottom = -NEDimensions.SPACING_L
	alignment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(alignment)
	var panel := PanelContainer.new()
	alignment.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, NEDimensions.PANEL_MARGIN)
	panel.add_child(margin)
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", NEDimensions.SPACING_S)
	margin.add_child(_vbox)

func _refresh() -> void:
	for child in _vbox.get_children():
		_vbox.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = "Raster: 1 m · Weg %.2f / %.1f m\nFeld anklicken oder mit WASD wählen" % [float(_fields.get(_selected, {}).get("cost", 0.0)), GRID.budget(player)]
	if _moving:
		label.text = "Bewegung wird ausgeführt …"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(label)
	var confirm := Button.new()
	confirm.text = "Bewegung ausführen"
	confirm.disabled = _moving or not _fields.has(_selected) or float(_fields[_selected].cost) < GRID.EPSILON
	confirm.pressed.connect(_on_confirm_pressed)
	_vbox.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "Abbrechen"
	cancel.disabled = _moving
	cancel.pressed.connect(_on_cancel_pressed)
	_vbox.add_child(cancel)
	if is_instance_valid(_session.grid_display):
		_session.grid_display.show_fields(_fields, _selected)

func _on_confirm_pressed() -> void:
	if _moving or _done:
		return
	# Belegung und Weg vor dem Start erneut prüfen (z.B. neue Teilnehmer).
	_fields = GRID.reachable(player, _session)
	if not _fields.has(_selected) or float(_fields[_selected].cost) < GRID.EPSILON:
		_refresh()
		return
	_moving = player.begin_combat_path(get_instance_id(), _fields[_selected].path, CombatBalance.COMBAT_MOVE_SPEED, _on_arrived)
	_refresh()

func _on_arrived(arrived: bool) -> void:
	if _done or not is_instance_valid(_session):
		return
	if not arrived:
		GRID.place(player, _session)
	var action := CombatAction.new()
	action.actor = _participant
	action.type = CombatAction.ActionType.MOVE
	action.move_target_position = player.global_position
	var result := CombatResolver.resolve_action(action)
	if not arrived:
		result.success = false
		result.failed_reason = "movement_blocked"
	_session.announce_action(_participant, action, result)
	_session.end_turn(_participant)
	_next_state = combat_wait
	_done = true

func _on_cancel_pressed() -> void:
	if _moving:
		return
	_next_state = combat_turn
	_done = true
