class_name StateCombatMove extends State

## "Bewegen"-Kampfzug: freie Positionierung statt festem Schritt. Beim Eintritt
## erscheint ein Kreis (ActionRangeIndicator, weltraumfest an der
## Ausgangsposition, nicht am Spieler) mit Radius = effektive Gewandheit *
## CombatBalance.STANDARD_LENGTH. Solange dieser State aktiv ist, läuft die
## Runde nicht weiter (wie bei jeder anderen Zugwahl auch) – der Spieler hat
## also Zeit, sich mit WASD frei innerhalb des Kreises zu positionieren.
## "Bewegung ausführen" beendet den Zug regulär über CombatResolver (wie
## Gegenstand/Fähigkeit/…). "Abbrechen" macht die Bewegung rückgängig und
## kehrt ohne Zugverbrauch ins Kampfmenü (CombatTurn) zurück.

@onready var combat_wait: State = $"../CombatWait"
@onready var combat_turn: State = $"../CombatTurn"

var _session: CombatSession = null
var _participant: CombatParticipant = null
var _origin_position: Vector3 = Vector3.ZERO
var _radius: float = CombatBalance.STANDARD_LENGTH
var _done: bool = false
var _next_state: State = null

var _canvas_layer: CanvasLayer
var _vbox: VBoxContainer
var _range_indicator: ActionRangeIndicator


func enter() -> void:
	_done = false
	_next_state = null
	_session = player.get_combat_session()
	_participant = _session.get_participant(player) if _session else null
	if _participant == null:
		_done = true
		_next_state = combat_wait
		return
	_origin_position = player.global_position
	player.stop_horizontal_velocity()
	var gewandheit := player.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)
	_radius = maxf(CombatBalance.STANDARD_LENGTH, gewandheit * CombatBalance.STANDARD_LENGTH)
	_show_range_indicator()
	_build_menu()
	_render_menu()


func exit() -> void:
	_destroy_menu()
	_destroy_range_indicator()


func process(_delta: float) -> State:
	if _done:
		return _next_state
	_update_movement()
	return null


func physics(_delta: float) -> State:
	_clamp_to_radius()
	return null


# --- Freie Bewegung im Kreis ---
# Bewusst direktes Input.get_axis() statt player.get_move_direction():
# Player und PartyFollower behandeln Bewegungseingabe unterschiedlich
# (Maus-Klick-Bewegung vs. hart auf ZERO gesetzt, siehe party_follower.gd) –
# hier soll aber jedes Partymitglied während des eigenen Kampfzugs gleich
# funktionieren, unabhängig davon, ob es der Leader oder ein Follower ist.

func _update_movement() -> void:
	if not player.is_on_floor():
		_update_airborne_animation()
	var kx := Input.get_axis("Left", "Right")
	var kz := Input.get_axis("Up", "Down")
	var move_dir := Vector3(kx, 0.0, kz)
	if move_dir.length_squared() > 0.0001:
		move_dir = move_dir.normalized()
		player.direction = move_dir
		player.set_horizontal_velocity(move_dir * CombatBalance.COMBAT_MOVE_SPEED)
		player.set_direction()
		player.update_animation("walk")
	else:
		player.direction = Vector3.ZERO
		player.stop_horizontal_velocity()
		player.update_animation("idle")


func _clamp_to_radius() -> void:
	var offset := player.global_position - _origin_position
	offset.y = 0.0
	if offset.length() <= _radius:
		return
	var clamped := offset.normalized() * _radius
	player.global_position = Vector3(
		_origin_position.x + clamped.x, player.global_position.y, _origin_position.z + clamped.z
	)


# --- Kreis-Anzeige ---
# Weltraumfest an der Ausgangsposition statt am Spieler befestigt (im
# Unterschied zu ActionRangeIndicator-Nutzung in state_action_menu.gd/
# state_party_skills.gd, wo der Spieler während der Menüwahl stehen bleibt) –
# hier bewegt sich der Spieler ja gerade innerhalb des Kreises.

func _show_range_indicator() -> void:
	if _range_indicator == null or not is_instance_valid(_range_indicator):
		_range_indicator = ActionRangeIndicator.new()
		_range_indicator.name = "CombatMoveRangeIndicator"
		player.get_parent().add_child(_range_indicator)
	# Nicht am Spieler befestigt (anders als _ready()s Y_OFFSET-Annahme in
	# ActionRangeIndicator, das sonst nur relativ zum Elternknoten "Spieler"
	# positioniert wird), daher hier explizit inklusive Y_OFFSET gesetzt.
	_range_indicator.global_position = _origin_position + Vector3(0.0, ActionRangeIndicator.Y_OFFSET, 0.0)
	_range_indicator.show_range(_radius)


func _destroy_range_indicator() -> void:
	if is_instance_valid(_range_indicator):
		_range_indicator.queue_free()
	_range_indicator = null


# --- Menü ---

func _build_menu() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	player.add_child(_canvas_layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(root_control)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_top -= 140.0
	panel.offset_bottom -= 40.0
	root_control.add_child(panel)
	_vbox = VBoxContainer.new()
	_vbox.custom_minimum_size = Vector2(280, 0)
	panel.add_child(_vbox)


func _destroy_menu() -> void:
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null
	_vbox = null


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(label)


func _add_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	_vbox.add_child(btn)


func _render_menu() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_add_label("Bewegen (Radius %.1f m) – WASD zum Positionieren" % _radius)
	_add_button("Bewegung ausführen", _on_confirm_pressed)
	_add_button("Abbrechen", _on_cancel_pressed)


func _on_confirm_pressed() -> void:
	var action := CombatAction.new()
	action.actor = _participant
	action.type = CombatAction.ActionType.MOVE
	action.move_target_position = player.global_position
	var result := CombatResolver.resolve_action(action)
	if is_instance_valid(_session):
		_session.announce_action(_participant, action, result)
		for target in result.defeated_targets:
			_session.mark_defeated(target)
		_session.end_turn(_participant)
	_next_state = combat_wait
	_done = true


func _on_cancel_pressed() -> void:
	player.global_position = _origin_position
	player.stop_horizontal_velocity()
	_next_state = combat_turn
	_done = true
