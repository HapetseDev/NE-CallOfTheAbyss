class_name StateActionMenu extends State

# Radius um den Spieler, in dem Interaktionen gesucht werden (in Metern)
@export var action_range: float = 1.5

@onready var idle: State = $"../Idle"
@onready var walk: State = $"../Walk"

var _canvas_layer: CanvasLayer
var _action_done: bool = false
var _has_shown_menu: bool = false


func enter() -> void:
	if player is Player:
		(player as Player).clear_click_move()
	player.velocity = Vector3.ZERO
	player.update_animation("idle")
	_action_done = false
	_has_shown_menu = false
	var actions := _collect_actions()
	_build_menu(actions)
	_has_shown_menu = true


func exit() -> void:
	_destroy_menu()


func process(_delta: float) -> State:
	if _action_done:
		if player.direction != Vector3.ZERO:
			return walk
		return idle
	player.velocity = Vector3.ZERO
	return null


func handle_input(_event: InputEvent) -> State:
	if _event.is_action_pressed("ui_cancel"):
		return idle
	return null


# --- Interne Hilfsmethoden ---

func _collect_actions() -> Array:
	var result: Array = []
	var interactables := get_tree().get_nodes_in_group("interactable")
	for node in interactables:
		var node3d := node as Node3D
		if node3d == null:
			continue
		var dist: float = node3d.global_position.distance_to(player.global_position)
		if not node3d.has_method("get_actions"):
			continue
		if dist > action_range:
			continue
		var node_actions: Array = node3d.get_actions(player)
		for action in node_actions:
			result.append({
				"label": action["label"],
				"action_id": action["action_id"],
				"target": node3d
			})
	return result


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

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(180, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Aktion wählen:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
			btn.pressed.connect(_on_action_pressed.bind(action))
			vbox.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Abbrechen"
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
