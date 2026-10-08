class_name PartyOrderUI extends Control

## Platz 1 steuert die Party; Pfeile ändern Reihenfolge und Anführer.

var _lock_owned := false
var _last_can_reorder := false
var _party: Party

@onready var _window: Window = %Window
@onready var _list: VBoxContainer = %List


func _ready() -> void:
	_window.close_requested.connect(_on_close_requested)
	_window.window_input.connect(_on_window_input)
	visibility_changed.connect(_on_visibility_changed)


func bind_party(party: Party) -> void:
	_party = party


func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	if is_visible_in_tree():
		_refresh()
		# Keine automatische Größenrückkopplung zwischen Window und Full-Rect-Inhalt.
		_window.size = Vector2i(480, 320)
		_window.visible = true
		_window.grab_focus()
		if not _lock_owned:
			GameState.acquire_input_lock()
			_lock_owned = true
	else:
		_window.visible = false
		_release_lock()


func _refresh() -> void:
	_last_can_reorder = _can_reorder()
	%HintLabel.text = "Mit ▲ / ▼ neu ordnen. Platz 1 übernimmt die Steuerung." if _last_can_reorder else "Während Kampf, Pause oder Interaktion ist der Wechsel gesperrt."
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _party == null:
		return
	var members := _party.get_all_members()
	for i in members.size():
		_list.add_child(_build_row(members[i], i))


func _build_row(member: Playable, index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", NEDimensions.SPACING_S)

	var label := Label.new()
	label.text = "%d. %s%s" % [index + 1, member.get_display_name(), " (Anführer)" if index == 0 else ""]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var movable := member as Player

	var up_button := Button.new()
	up_button.text = "▲"
	up_button.tooltip_text = "Nach vorn – Platz 1 übernimmt die Steuerung"
	up_button.custom_minimum_size = Vector2(NEDimensions.ICON_BUTTON_SIZE, NEDimensions.ICON_BUTTON_SIZE)
	up_button.disabled = movable == null or index == 0 or not _can_reorder()
	up_button.pressed.connect(_on_move_pressed.bind(movable, -1))
	row.add_child(up_button)

	var down_button := Button.new()
	down_button.text = "▼"
	down_button.tooltip_text = "Nach hinten"
	down_button.custom_minimum_size = Vector2(NEDimensions.ICON_BUTTON_SIZE, NEDimensions.ICON_BUTTON_SIZE)
	down_button.disabled = movable == null or index >= _party.get_all_members().size() - 1 or not _can_reorder()
	down_button.pressed.connect(_on_move_pressed.bind(movable, 1))
	row.add_child(down_button)

	return row


func _on_move_pressed(member: Player, delta: int) -> void:
	_release_lock()
	var moved := _party.move_member(member, delta)
	GameState.acquire_input_lock()
	_lock_owned = true
	_refresh()
	if not moved:
		%HintLabel.text = "Wechsel nicht möglich: Kampf, Interaktion oder kampfunfähiger Anführer."


func _on_close_requested() -> void:
	visible = false


func _on_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_window.set_input_as_handled()
		_on_close_requested()


func _can_reorder() -> bool:
	if not is_instance_valid(_party):
		return false
	# Nur die eigene Fenstersperre ausnehmen; fremde Sperren bleiben wirksam.
	if _lock_owned:
		GameState.release_input_lock()
	var allowed := _party.can_reorder()
	if _lock_owned:
		GameState.acquire_input_lock()
	return allowed


func _process(_delta: float) -> void:
	if visible and is_node_ready() and _last_can_reorder != _can_reorder():
		_refresh()


func _release_lock() -> void:
	if _lock_owned:
		GameState.release_input_lock()
		_lock_owned = false


func _exit_tree() -> void:
	_release_lock()
