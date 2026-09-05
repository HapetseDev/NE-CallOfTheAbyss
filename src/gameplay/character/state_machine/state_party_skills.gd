class_name StatePartySkills extends State

## Party-Fähigkeiten-Menü außerhalb des Kampfes (Taste "Faehigkeiten", nur am
## Leader, siehe state_idle.gd). Charakter wählen -> Fähigkeit wählen -> Ziel
## wählen. SELF/ALLY-Ziele werden sofort über PartyAbilityResolver angewendet
## (kein Kampf nötig). Ziele außerhalb der Party lösen CombatManager.trigger_attack
## aus – die Fähigkeit wird dann als erste Aktion des neu gestarteten/erweiterten
## Kampfes ganz regulär über CombatResolver aufgelöst (ein "Erstschlag", kein
## end_turn() nötig, da der Charakter nie regulär turn_started bekommen hat).
## Menü-Baumuster wie state_action_menu.gd/state_combat_turn.gd: programmatisch
## gebaute CanvasLayer/Control/VBoxContainer, kein eigenes .tscn.

@export var action_range: float = 1.5

@onready var idle: State = $"../Idle"

var _done: bool = false
var _canvas_layer: CanvasLayer
var _vbox: VBoxContainer
var _range_indicator: ActionRangeIndicator


func enter() -> void:
	if player is Player:
		(player as Player).clear_click_move()
	player.stop_horizontal_velocity()
	player.update_animation("idle")
	_done = false
	_build_menu()
	_render_character_menu()


func exit() -> void:
	_destroy_menu()
	_hide_range_indicator()


func process(_delta: float) -> State:
	if _done:
		return idle
	player.stop_horizontal_velocity()
	return null


func handle_input(_event: InputEvent) -> State:
	if _event.is_action_pressed("ui_cancel") or _event.is_action_pressed("Faehigkeiten"):
		_done = true
	return null


# --- Menü-Gerüst (wie state_combat_turn.gd) ---

func _build_menu() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	player.add_child(_canvas_layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(root_control)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root_control.add_child(panel)
	_vbox = VBoxContainer.new()
	_vbox.custom_minimum_size = Vector2(280, 0)
	panel.add_child(_vbox)


func _destroy_menu() -> void:
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null
	_vbox = null


func _clear_vbox() -> void:
	if _vbox == null:
		return
	for child in _vbox.get_children():
		child.queue_free()


func _add_label(text: String) -> void:
	if _vbox == null:
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(label)


func _add_button(text: String, callback: Callable, disabled: bool = false) -> void:
	if _vbox == null:
		return
	var btn := Button.new()
	btn.text = text
	btn.disabled = disabled
	btn.pressed.connect(callback)
	_vbox.add_child(btn)


# --- Charakter wählen ---

func _render_character_menu() -> void:
	_hide_range_indicator()
	_clear_vbox()
	_add_label("Wer soll eine Fähigkeit einsetzen?")
	var members := _party_members()
	if members.is_empty():
		_add_label("Keine Party gefunden.")
	for member in members:
		_add_button(member.get_display_name(), _render_ability_menu.bind(member))
	_add_button("Abbrechen", _on_cancel)


# --- Fähigkeit wählen ---

func _render_ability_menu(actor: Playable) -> void:
	_clear_vbox()
	_add_label("%s: Fähigkeit wählen" % actor.get_display_name())
	var abilities := AbilityCatalog.get_available_for(actor.character)
	if abilities.is_empty():
		_add_label("Keine Fähigkeit verfügbar.")
	for ability in abilities:
		var affordable := ability.mana_cost <= 0 or actor.can_spend_mana(ability.mana_cost)
		_add_button(
			"%s (%d MP)" % [ability.ability_name, ability.mana_cost],
			_on_ability_chosen.bind(actor, ability),
			not affordable
		)
	_add_button("Zurück", _render_character_menu)


func _on_ability_chosen(actor: Playable, ability: AbilityDefinition) -> void:
	match ability.target_type:
		AbilityDefinition.TargetType.SELF:
			_apply_ally_target(actor, ability, actor)
		AbilityDefinition.TargetType.ALL_ALLIES:
			for member in _party_members():
				_apply_ally_target(actor, ability, member, false)
			_finish()
		AbilityDefinition.TargetType.SINGLE_ALLY:
			_render_ally_target_menu(actor, ability)
		_:
			_render_world_target_menu(actor, ability)


# --- Ziel wählen: Party (SELF/SINGLE_ALLY/ALL_ALLIES) ---

func _render_ally_target_menu(actor: Playable, ability: AbilityDefinition) -> void:
	_clear_vbox()
	_add_label("Ziel wählen")
	for member in _party_members():
		_add_button(member.get_display_name(), _on_ally_target_chosen.bind(actor, ability, member))
	_add_button("Zurück", _render_ability_menu.bind(actor))


func _on_ally_target_chosen(actor: Playable, ability: AbilityDefinition, target: Playable) -> void:
	_apply_ally_target(actor, ability, target)


func _apply_ally_target(actor: Playable, ability: AbilityDefinition, target: Playable, finish: bool = true) -> void:
	PartyAbilityResolver.apply_non_combat(actor, ability, target)
	if finish:
		_finish()


# --- Ziel wählen: außerhalb der Party (DAMAGE -> löst Kampf aus) ---

func _render_world_target_menu(actor: Playable, ability: AbilityDefinition) -> void:
	_clear_vbox()
	_add_label("Ziel wählen")
	_show_range_indicator()
	var candidates := _nearby_attackable_targets()
	if candidates.is_empty():
		_add_label("Kein Ziel in Reichweite.")
	for candidate in candidates:
		_add_button(candidate.get_display_name(), _on_world_target_chosen.bind(actor, ability, candidate))
	_add_button("Zurück", _render_ability_menu.bind(actor))


func _on_world_target_chosen(actor: Playable, ability: AbilityDefinition, target: Playable) -> void:
	CombatManager.trigger_attack(actor, target)
	var session := CombatManager.instance.get_session_for(actor) if CombatManager.instance else null
	if session == null:
		_finish()
		return
	var actor_participant := session.get_participant(actor)
	if actor_participant == null:
		_finish()
		return
	var enemy_side := CombatParticipantResolver.SIDE_VICTIM
	if actor_participant.side == CombatParticipantResolver.SIDE_VICTIM:
		enemy_side = CombatParticipantResolver.SIDE_ATTACKER
	var targets: Array[CombatParticipant] = []
	if ability.target_type == AbilityDefinition.TargetType.ALL_ENEMIES:
		for participant in session.participants:
			if participant.side == enemy_side and not participant.is_out_of_combat():
				targets.append(participant)
	else:
		var target_participant := session.get_participant(target)
		if target_participant:
			targets.append(target_participant)
	var action := CombatAction.new()
	action.actor = actor_participant
	action.type = CombatAction.ActionType.ABILITY
	action.ability = ability
	action.targets = targets
	var result := CombatResolver.resolve_action(action)
	session.announce_action(actor_participant, action, result)
	for defeated in result.defeated_targets:
		session.mark_defeated(defeated)
	_finish()


# --- Hilfsfunktionen ---

func _party_members() -> Array[Playable]:
	var party := _find_party()
	if party == null:
		return []
	return party.get_all_members()


func _find_party() -> Party:
	var node: Node = player
	while node:
		if node is Party:
			return node as Party
		node = node.get_parent()
	return null


func _nearby_attackable_targets() -> Array[Playable]:
	var result: Array[Playable] = []
	for node in get_tree().get_nodes_in_group("interactable"):
		var node3d := node as Node3D
		if node3d == null or not node3d.has_method("get_actions"):
			continue
		if _horizontal_distance_to(node3d) > action_range:
			continue
		var can_fight := false
		for entry in node3d.get_actions(player):
			if entry.get("action_id") == "fight":
				can_fight = true
				break
		if not can_fight:
			continue
		var target := node3d.get_parent() as Playable
		if target and not result.has(target):
			result.append(target)
	return result


func _horizontal_distance_to(target: Node3D) -> float:
	var delta := target.global_position - player.global_position
	return Vector2(delta.x, delta.z).length()


func _show_range_indicator() -> void:
	if _range_indicator == null or not is_instance_valid(_range_indicator):
		_range_indicator = ActionRangeIndicator.new()
		_range_indicator.name = "ActionRangeIndicator"
		player.add_child(_range_indicator)
	_range_indicator.show_range(action_range)


func _hide_range_indicator() -> void:
	if is_instance_valid(_range_indicator):
		_range_indicator.hide_range()


func _on_cancel() -> void:
	_finish()


func _finish() -> void:
	_done = true
