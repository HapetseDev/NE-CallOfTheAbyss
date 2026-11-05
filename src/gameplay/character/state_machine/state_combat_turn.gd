class_name StateCombatTurn extends State

## Aktiver Kampfzug: Gegenstand / Fähigkeit / Bewegen / Reden / Fliehen.
## Menü-Baumuster aus state_action_menu.gd übernommen (programmatisch gebaute
## CanvasLayer/Control/VBoxContainer statt eigener .tscn). ITEM/ABILITY laufen
## direkt hier über CombatResolver; "Bewegen" wechselt in den eigenen State
## StateCombatMove (freie Positionierung im Kreis, siehe dort); COMMUNICATE/
## FLEE haben Szenen-Seiteneffekte und werden hier direkt behandelt (siehe
## combat_action.gd).

@onready var combat_wait: State = $"../CombatWait"
@onready var combat_move: State = $"../CombatMove"

var _session: CombatSession = null
var _participant: CombatParticipant = null
var _turn_over: bool = false
var _next_state: State = null

var _canvas_layer: CanvasLayer
var _vbox: VBoxContainer
var _attack_line: MeshInstance3D
var _preview_target: CombatParticipant
var _preview_mode: ItemUsageMode
var _preview_zone_id: String = ""


func enter() -> void:
	player.stop_horizontal_velocity()
	player.update_animation("idle")
	_turn_over = false
	_next_state = null
	_session = player.get_combat_session()
	_participant = _session.get_participant(player) if _session else null
	if _participant == null:
		_turn_over = true
		return
	_build_menu()
	_render_root()


func exit() -> void:
	_destroy_menu()


func _exit_tree() -> void:
	_clear_attack_line()


func process(_delta: float) -> State:
	_update_attack_line()
	if _turn_over:
		return combat_wait
	if _next_state:
		var target := _next_state
		_next_state = null
		return target
	return null


# --- Menü-Gerüst ---

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
	_clear_attack_line()
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null
	_vbox = null


func _clear_vbox() -> void:
	_clear_attack_line()
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


func _add_button(text: String, callback: Callable, disabled: bool = false) -> Button:
	if _vbox == null:
		return null
	var btn := Button.new()
	btn.text = text
	btn.disabled = disabled
	btn.pressed.connect(callback)
	_vbox.add_child(btn)
	return btn


# --- Wurzel ---

func _render_root() -> void:
	_clear_vbox()
	_add_label("%s ist am Zug" % player.get_display_name())
	if player.equipment.get("primaer_hand") == null or player.equipment.get("nebenhand") == null:
		_add_button("Schlag", _on_unarmed_pressed)
	_add_button("Gegenstand", _render_item_menu)
	_add_button("Fähigkeit", _render_ability_menu)
	_add_button("Bewegen", _on_move_pressed)
	_add_button("Reden", _render_communicate_menu)
	_add_button("Fliehen", _on_flee_pressed)


# --- Gegenstand ---

func _on_unarmed_pressed() -> void:
	_on_ability_chosen(AbilityCatalog.get_definition("fausthieb"))


func _render_item_menu() -> void:
	_clear_vbox()
	_add_label("Gegenstand wählen")
	var items := player.get_combat_usable_items()
	if items.is_empty():
		_add_label("Nichts in der Hand oder Schnellausrüstung.")
	for item in items:
		if item.consumable:
			_add_button("%s – Verwenden" % item.item_name, _render_consumable_targets.bind(item))
		for mode in item.get_combat_usage_modes():
			_add_button(
				"%s – %s" % [item.item_name, mode.label],
				_render_item_target_menu.bind(item, mode)
			)
	_add_button("Zurück", _render_root)


func _render_consumable_targets(item: ItemData) -> void:
	_clear_vbox()
	_add_label("Verwenden bei")
	for target in _targets_on_side(_participant.side):
		_add_button(target.playable.get_display_name(), _on_item_target_chosen.bind(item, null, target))
	_add_button("Zurück", _render_item_menu)


func _render_item_target_menu(item: ItemData, mode: ItemUsageMode) -> void:
	_clear_vbox()
	_add_label("Ziel wählen")
	var candidates := _targets_on_side(_enemy_side())
	if candidates.is_empty():
		_add_label("Kein Ziel verfügbar.")
	for target in candidates:
		var out_of_range := not mode.is_in_range(player, target.playable)
		var recipient := CombatResolver.get_item_attack_target(_participant, target, mode)
		var blocked := recipient == null
		var label := target.playable.get_display_name()
		if blocked:
			label += " (Angriffslinie blockiert)"
		elif recipient != target:
			label += " (trifft zuerst: %s)" % recipient.playable.get_display_name()
		if recipient != null and not mode.is_in_range(player, recipient.playable):
			blocked = true
			label += " (außer Reichweite: %.1f m)" % mode.range_meters
		if blocked and not out_of_range:
			# Hinter Deckung kann z.B. der Kopf statt des Rumpfs erreichbar sein.
			for zone in CombatAnatomy.profile(target.playable.character).zones:
				var alternative := CombatResolver.get_item_attack_target(_participant, target, mode, zone.zone_id)
				if alternative != null and mode.is_in_range(player, alternative.playable):
					blocked = false
					label += " (andere Trefferstelle möglich)"
					break
		if out_of_range:
			blocked = true
			label += " (Außerhalb der Reichweite von %s: max. %.1f m)" % [item.item_name, mode.range_meters]
		if not mode.ammunition_item_id.is_empty() and not player.character.inventory.has_item(mode.ammunition_item_id):
			blocked = true
			label += " (keine Munition)"
		var button := _add_button(label, _render_item_zone_menu.bind(item, mode, target), blocked)
		if button:
			if out_of_range:
				_mark_out_of_range(button)
			button.mouse_entered.connect(_preview_attack.bind(target, mode))
			button.focus_entered.connect(_preview_attack.bind(target, mode))
	_add_button("Zurück", _render_item_menu)
	if not candidates.is_empty():
		_preview_attack(candidates[0], mode)


func _render_item_zone_menu(item: ItemData, mode: ItemUsageMode, target: CombatParticipant) -> void:
	_clear_vbox()
	_add_label("Trefferstelle: %s" % target.playable.get_display_name())
	for zone in CombatAnatomy.profile(target.playable.character).zones:
		var hit := CombatResolver.get_item_attack_hit(_participant, target, mode, zone.zone_id)
		var recipient := hit.get("target") as CombatParticipant
		var blocked := recipient == null or (recipient != null and not mode.is_in_range(player, recipient.playable))
		var out_of_range := not mode.is_in_range(player, target.playable) or (recipient != null and not mode.is_in_range(player, recipient.playable))
		blocked = blocked or out_of_range
		var label := zone.label
		if recipient != null:
			var actual_zone := CombatAnatomy.profile(recipient.playable.character).get_zone(hit.zone_id)
			label += " → %s: %s" % [recipient.playable.get_display_name(), actual_zone.label]
		else:
			label += " (blockiert)"
		if out_of_range:
			label += " (Außerhalb der Reichweite von %s: max. %.1f m)" % [item.item_name, mode.range_meters]
		if not mode.ammunition_item_id.is_empty() and not player.character.inventory.has_item(mode.ammunition_item_id):
			blocked = true
		var button := _add_button(label, _on_item_target_chosen.bind(item, mode, target, zone.zone_id), blocked)
		if button:
			if out_of_range:
				_mark_out_of_range(button)
			button.mouse_entered.connect(_preview_attack.bind(target, mode, zone.zone_id))
			button.focus_entered.connect(_preview_attack.bind(target, mode, zone.zone_id))
	_add_button("Zurück", _render_item_target_menu.bind(item, mode))
	_preview_attack(target, mode)


func _mark_out_of_range(button: Button) -> void:
	# Semantischer Fehlerzustand, vorhandene globalen Button-StyleBoxen beibehalten.
	for property in ["font_color", "font_disabled_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(property, NEColors.DANGER)
	button.tooltip_text = button.text


func _preview_attack(target: CombatParticipant, mode: ItemUsageMode, zone_id: String = "") -> void:
	_preview_target = target
	_preview_mode = mode
	_preview_zone_id = zone_id
	_update_attack_line()


func _update_attack_line() -> void:
	if _preview_target == null or not is_instance_valid(_preview_target.playable):
		if is_instance_valid(_attack_line):
			_clear_attack_line()
		return
	if not is_instance_valid(_attack_line):
		_attack_line = MeshInstance3D.new()
		_attack_line.name = "AttackVectorPreview"
		_attack_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		player.get_parent().add_child(_attack_line)
		_attack_line.top_level = true
		_attack_line.global_transform = Transform3D.IDENTITY
	var recipient := CombatResolver.get_item_attack_target(_participant, _preview_target, _preview_mode, _preview_zone_id)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = NEColors.WARNING if recipient != _preview_target else NEColors.ACCENT
	if not _preview_mode.is_in_range(player, _preview_target.playable) or (recipient != null and not _preview_mode.is_in_range(player, recipient.playable)):
		material.albedo_color = NEColors.DANGER
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	mesh.surface_add_vertex(CombatAnatomy.aim_point(player))
	mesh.surface_add_vertex(CombatAnatomy.aim_point(_preview_target.playable, _preview_zone_id))
	mesh.surface_end()
	_attack_line.mesh = mesh


func _clear_attack_line() -> void:
	_preview_target = null
	_preview_mode = null
	_preview_zone_id = ""
	if is_instance_valid(_attack_line):
		_attack_line.queue_free()
	_attack_line = null


func _on_item_target_chosen(item: ItemData, mode: ItemUsageMode, target: CombatParticipant, zone_id: String = "") -> void:
	if _turn_over:
		return
	var action := CombatAction.new()
	action.actor = _participant
	action.type = CombatAction.ActionType.ITEM
	action.item = item
	action.item_usage_mode = mode
	action.target_zone_id = zone_id
	action.targets = [target]
	_apply_result(action, CombatResolver.resolve_action(action))


# --- Fähigkeit ---

func _render_ability_menu() -> void:
	_clear_vbox()
	_add_label("Fähigkeit wählen")
	var abilities := AbilityCatalog.get_available_for(player.character)
	if abilities.is_empty():
		_add_label("Keine Fähigkeit verfügbar.")
	for ability in abilities:
		var affordable := ability.mana_cost <= 0 or player.can_spend_mana(ability.mana_cost)
		_add_button(
			"%s (%d MP)" % [ability.ability_name, ability.mana_cost],
			_on_ability_chosen.bind(ability),
			not affordable
		)
	_add_button("Zurück", _render_root)


func _on_ability_chosen(ability: AbilityDefinition) -> void:
	match ability.target_type:
		AbilityDefinition.TargetType.SELF:
			_execute_ability(ability, [_participant])
		AbilityDefinition.TargetType.ALL_ENEMIES:
			_execute_ability(ability, _targets_on_side(_enemy_side()))
		AbilityDefinition.TargetType.ALL_ALLIES:
			_execute_ability(ability, _targets_on_side(_participant.side))
		AbilityDefinition.TargetType.SINGLE_ALLY:
			_render_ability_target_menu(ability, _participant.side)
		_:
			_render_ability_target_menu(ability, _enemy_side())


func _render_ability_target_menu(ability: AbilityDefinition, side: StringName) -> void:
	_clear_vbox()
	_add_label("Ziel wählen")
	var candidates := _targets_on_side(side)
	if candidates.is_empty():
		_add_label("Kein Ziel verfügbar.")
	for target in candidates:
		var blocked := ability.requires_line_of_sight and not CombatLineOfSight.has_clear_line(player, target.playable)
		var out_of_range := not ability.is_in_range(player, target.playable)
		var label := target.playable.get_display_name()
		if blocked:
			label += " (keine Sichtlinie)"
		if out_of_range:
			label += " (Außerhalb der Reichweite von %s: max. %.1f m)" % [ability.ability_name, ability.melee_range_meters]
		var button := _add_button(label, _on_ability_target_chosen.bind(ability, target), blocked or out_of_range)
		if button and out_of_range:
			_mark_out_of_range(button)
	_add_button("Zurück", _render_ability_menu)


func _on_ability_target_chosen(ability: AbilityDefinition, target: CombatParticipant) -> void:
	_execute_ability(ability, [target])


func _execute_ability(ability: AbilityDefinition, targets: Array[CombatParticipant]) -> void:
	var action := CombatAction.new()
	action.actor = _participant
	action.type = CombatAction.ActionType.ABILITY
	action.ability = ability
	action.targets = targets
	_apply_result(action, CombatResolver.resolve_action(action))


# --- Bewegen ---
# Freie Positionierung im Kreis statt fester Schritte – siehe state_combat_move.gd.
# Der eigentliche Zugwechsel läuft über process()/_next_state, da Kampfmenü-
# Buttons (anders als handle_input()) keinen State-Rückgabewert haben.

func _on_move_pressed() -> void:
	_next_state = combat_move


# --- Reden ---
# Öffnet den bestehenden Dialog des Ziels (falls vorhanden). Mechanische
# Wirkung auf den Kampf ist laut Plan noch offen – der Zug wird verbraucht.

func _render_communicate_menu() -> void:
	_clear_vbox()
	_add_label("Reden mit")
	var candidates := _targets_on_side(_enemy_side()) + _targets_on_side(_participant.side)
	var any := false
	for target in candidates:
		if target == _participant:
			continue
		var interaction := _find_interaction(target.playable)
		if interaction == null:
			continue
		any = true
		_add_button(target.playable.get_display_name(), _on_communicate_chosen.bind(interaction))
	if not any:
		_add_label("Niemand hier redet mit dir.")
	_add_button("Zurück", _render_root)


func _find_interaction(target_playable: Playable) -> NPCInteraction:
	if target_playable == null:
		return null
	return target_playable.get_node_or_null("Interaction") as NPCInteraction


func _on_communicate_chosen(interaction: NPCInteraction) -> void:
	interaction.perform_action("talk", player)
	_end_turn()


# --- Fliehen ---
# Erfolgschance aus eigener Gewandheit vs. Durchschnitt der Gegenseite. Bei
# Erfolg bewegt sich der Charakter physisch aus dem Kampfbereich (siehe
# CombatSession.mark_fled) und wird über mark_fled() (statt remove()) aus der aktiven
# Zugvergabe genommen: er bleibt Teil der Session, bis auch der Rest seiner
# Seite raus ist – erst dann (CombatManager._on_side_wiped) bekommt er seine
# freie Steuerung zurück. Vermeidet den Bug, dass ein einzeln geflohener
# Party-Leader sofort wieder frei steuerbar war, während der Rest der Party
# noch kämpft.

func _on_flee_pressed() -> void:
	if _turn_over or not is_instance_valid(_session) or _participant == null or _participant.is_out_of_combat():
		return
	var enemies := _targets_on_side(_enemy_side())
	var avg_enemy_speed := 0.0
	if not enemies.is_empty():
		var total := 0
		for enemy in enemies:
			total += enemy.playable.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)
		avg_enemy_speed = float(total) / enemies.size()
	var own_speed := player.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)
	var chance := clampf(
		CombatBalance.FLEE_BASE_CHANCE + (own_speed - avg_enemy_speed) * CombatBalance.FLEE_SPEED_FACTOR,
		CombatBalance.FLEE_CHANCE_MIN,
		CombatBalance.FLEE_CHANCE_MAX
	)
	if randf() < chance:
		_session.mark_fled(_participant)
		_end_turn()
	else:
		_end_turn()


# --- Gemeinsame Hilfsfunktionen ---

func _enemy_side() -> StringName:
	if _participant.side == CombatParticipantResolver.SIDE_ATTACKER:
		return CombatParticipantResolver.SIDE_VICTIM
	return CombatParticipantResolver.SIDE_ATTACKER


func _targets_on_side(side: StringName) -> Array[CombatParticipant]:
	var result: Array[CombatParticipant] = []
	if _session == null:
		return result
	for participant in _session.participants:
		if participant.side == side and not participant.is_out_of_combat():
			result.append(participant)
	return result


func _apply_result(action: CombatAction, result: CombatActionResult) -> void:
	if is_instance_valid(_session):
		_session.announce_action(_participant, action, result)
		for target in result.defeated_targets:
			_session.mark_defeated(target)
	_end_turn()


func _end_turn() -> void:
	_turn_over = true
	if is_instance_valid(_session) and _participant:
		_session.end_turn(_participant)
