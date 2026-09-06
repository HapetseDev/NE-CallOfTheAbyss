class_name StateActionMenu extends State

# Radius um den Spieler, in dem Interaktionen gesucht werden (in Metern)
@export var action_range: float = 1.5

@onready var idle: State = $"../Idle"
@onready var walk: State = $"../Walk"

var _canvas_layer: CanvasLayer
var _range_indicator: ActionRangeIndicator
var _highlights: Array[InteractableHighlightFx] = []
var _action_done: bool = false
var _has_shown_menu: bool = false


func enter() -> void:
	if player is Player:
		(player as Player).clear_click_move()
	player.stop_horizontal_velocity()
	player.update_animation("idle")
	_action_done = false
	_has_shown_menu = false
	_show_range_indicator()
	var actions := _collect_actions()
	_highlight_actionable_targets(actions)
	_build_menu(actions)
	_has_shown_menu = true
	set_process_input(true)


func exit() -> void:
	set_process_input(false)
	_clear_highlights()
	_hide_range_indicator()
	_destroy_menu()


func process(_delta: float) -> State:
	if _action_done:
		if player.direction != Vector3.ZERO:
			return walk
		return idle
	player.stop_horizontal_velocity()
	return null


func handle_input(_event: InputEvent) -> State:
	if _wants_close_menu(_event):
		return idle
	return null


func _input(event: InputEvent) -> void:
	# Vor der GUI: zweiter Rechtsklick/E schließt auch über dem Menü-Panel.
	if not _has_shown_menu or _action_done:
		return
	if _wants_close_menu(event):
		_action_done = true
		get_viewport().set_input_as_handled()


func _wants_close_menu(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or event.is_action_pressed("Interact")


# --- Interne Hilfsmethoden ---

func _horizontal_distance_to(target: Node3D) -> float:
	var delta := target.global_position - player.global_position
	return Vector2(delta.x, delta.z).length()


func _collect_actions() -> Array:
	var result: Array = []
	var interactables := get_tree().get_nodes_in_group("interactable")
	for node in interactables:
		var node3d := node as Node3D
		if node3d == null:
			continue
		if not node3d.has_method("get_actions"):
			continue
		if _horizontal_distance_to(node3d) > action_range:
			continue
		var node_actions: Array = node3d.get_actions(player)
		for action in node_actions:
			result.append({
				"label": action["label"],
				"action_id": action["action_id"],
				"target": node3d
			})
	return result


func _resolve_visual_root(target: Node3D) -> Node3D:
	# NPCInteraction sits on the character root; visuals live on the parent.
	var parent := target.get_parent()
	if parent is Node3D and (target is NPCInteraction or target.name == "Interaction"):
		return parent as Node3D
	return target


func _highlight_actionable_targets(actions: Array) -> void:
	_clear_highlights()
	var seen: Dictionary = {}
	for action in actions:
		var target: Variant = action.get("target")
		if target == null or not is_instance_valid(target):
			continue
		var target_node := target as Node3D
		if target_node == null or seen.has(target_node):
			continue
		seen[target_node] = true
		var visual_root := _resolve_visual_root(target_node)
		var fx := InteractableHighlightFx.new()
		fx.name = "InteractableHighlightFx"
		visual_root.add_child(fx)
		fx.setup(visual_root)
		_highlights.append(fx)


func _clear_highlights() -> void:
	for fx in _highlights:
		if is_instance_valid(fx):
			fx.queue_free()
	_highlights.clear()


func _show_range_indicator() -> void:
	if _range_indicator == null or not is_instance_valid(_range_indicator):
		_range_indicator = ActionRangeIndicator.new()
		_range_indicator.name = "ActionRangeIndicator"
		player.add_child(_range_indicator)
	_range_indicator.show_range(action_range)


func _hide_range_indicator() -> void:
	if is_instance_valid(_range_indicator):
		_range_indicator.hide_range()


func _build_menu(actions: Array) -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	player.add_child(_canvas_layer)

	# Vollbild-Control als Anker-Basis
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(root_control)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", NEDimensions.PANEL_MARGIN)
	margin.add_theme_constant_override(&"margin_top", NEDimensions.PANEL_MARGIN)
	margin.add_theme_constant_override(&"margin_right", NEDimensions.PANEL_MARGIN)
	margin.add_theme_constant_override(&"margin_bottom", NEDimensions.PANEL_MARGIN)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(240, 0)
	vbox.add_theme_constant_override(&"separation", NEDimensions.SPACING_S)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Aktion wählen:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", NETypography.SIZE_H3)
	vbox.add_child(title)

	if actions.is_empty():
		var info := Label.new()
		info.text = "Keine Aktion möglich."
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(info)
	else:
		for action in actions:
			var btn := Button.new()
			btn.text = action["label"]
			btn.custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
			btn.pressed.connect(_on_action_pressed.bind(action))
			vbox.add_child(btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var cancel_btn := Button.new()
	cancel_btn.text = "Abbrechen"
	cancel_btn.custom_minimum_size.y = NEDimensions.BUTTON_HEIGHT
	cancel_btn.pressed.connect(_on_cancel_pressed)
	vbox.add_child(cancel_btn)


func _destroy_menu() -> void:
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null


func _on_action_pressed(action_data: Dictionary) -> void:
	var target = action_data["target"]
	if is_instance_valid(target) and target.has_method("perform_action"):
		target.perform_action(action_data["action_id"], player)
	_action_done = true


func _on_cancel_pressed() -> void:
	_action_done = true
