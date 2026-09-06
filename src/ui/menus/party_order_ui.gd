class_name PartyOrderUI extends Control

## Fenster aus TopBarHud ("Party"): organisiert fürs Erste nur die
## Marschreihenfolge der Follower (Anführer bleibt fix an Position 1).
## Wirkt sich direkt auf die Reihenfolge in PartyHud sowie auf Listen wie
## das Fähigkeiten-Zielmenü aus, da beide über Party.get_all_members() gehen.

var _party: Party

@onready var _window: Window = %Window
@onready var _list: VBoxContainer = %List


func _ready() -> void:
	_window.close_requested.connect(_on_close_requested)
	visibility_changed.connect(_on_visibility_changed)


func bind_party(party: Party) -> void:
	_party = party


func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	if is_visible_in_tree():
		_window.visible = true
		_window.grab_focus()
		_refresh()
	else:
		_window.visible = false


func _refresh() -> void:
	for child in _list.get_children():
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

	var follower := member as PartyFollower

	var up_button := Button.new()
	up_button.text = "▲"
	up_button.custom_minimum_size = Vector2(NEDimensions.ICON_BUTTON_SIZE, NEDimensions.ICON_BUTTON_SIZE)
	up_button.disabled = follower == null or _party.followers.find(follower) <= 0
	up_button.pressed.connect(_on_move_pressed.bind(follower, -1))
	row.add_child(up_button)

	var down_button := Button.new()
	down_button.text = "▼"
	down_button.custom_minimum_size = Vector2(NEDimensions.ICON_BUTTON_SIZE, NEDimensions.ICON_BUTTON_SIZE)
	down_button.disabled = follower == null or _party.followers.find(follower) >= _party.followers.size() - 1
	down_button.pressed.connect(_on_move_pressed.bind(follower, 1))
	row.add_child(down_button)

	return row


func _on_move_pressed(follower: PartyFollower, delta: int) -> void:
	_party.move_follower(follower, delta)
	_refresh()


func _on_close_requested() -> void:
	visible = false
