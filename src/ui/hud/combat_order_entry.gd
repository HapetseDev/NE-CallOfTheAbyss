class_name CombatOrderEntry extends Control

const CARD_SCENE := preload("res://src/ui/hud/party_hud_entry.tscn")
const EXIT_SHADER := preload("res://src/ui/hud/combat_card_exit.gdshader")

var participant: CombatParticipant
var card: PanelContainer
var borrowed := false
var _motion: Tween
var _exit_tween: Tween
var _exit_material: ShaderMaterial
var _destination := Vector2.INF
var _destination_scale := -1.0

func bind(p: CombatParticipant, world_card: PanelContainer = null) -> void:
	participant = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	borrowed = world_card != null
	if borrowed:
		card = world_card
		var origin := card.global_position
		var original_scale := card.scale
		card.reparent(self)
		global_position = origin
		scale = original_scale
		card.position = Vector2.ZERO
		card.scale = Vector2.ONE
	else:
		card = PanelContainer.new()
		add_child(card)
		var entry := CARD_SCENE.instantiate() as PartyHudEntry
		card.add_child(entry)
		entry.bind(p.playable)
		scale = Vector2.ONE * NEDimensions.COMBAT_CARD_SCALE
		modulate.a = 0.0
	card.visible = true
	_ignore_mouse(card)
	card.size = card.get_combined_minimum_size()

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func card_size() -> Vector2:
	return card.get_combined_minimum_size() if is_instance_valid(card) else Vector2.ZERO

func refresh(active: bool, friendly: bool) -> void:
	if not is_instance_valid(card) or not is_instance_valid(participant.playable):
		return
	var view := card.get_child(0) as PartyHudEntry
	view.refresh()
	view.set_combat_presentation(active, NEColors.SUCCESS if friendly else NEColors.DANGER)
	card.size = card.get_combined_minimum_size()

func move_to(destination: Vector2, factor: float) -> void:
	if destination.is_equal_approx(_destination) and is_equal_approx(factor, _destination_scale):
		return
	var first := _destination == Vector2.INF
	_destination = destination
	_destination_scale = factor
	if _motion and _motion.is_valid():
		_motion.kill()
	var duration := NEDimensions.COMBAT_CARD_TRANSITION_SEC if first else NEDimensions.COMBAT_CARD_REORDER_SEC
	_motion = create_tween().set_parallel(true)
	_motion.tween_property(self, "position", destination, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "scale", Vector2.ONE * factor, duration)
	_motion.tween_property(self, "modulate:a", 1.0, duration)

func _set_parent_material(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.use_parent_material = enabled
		_set_parent_material(child, enabled)

func cancel_exit() -> void:
	if _exit_tween and _exit_tween.is_valid():
		_exit_tween.kill()
	_exit_tween = null
	if card:
		card.material = null
		_set_parent_material(card, false)
	_exit_material = null
	modulate = NEColors.HUD_CARD_NORMAL
	_destination = Vector2.INF

func animate_exit(finished: Callable) -> void:
	if _motion and _motion.is_valid():
		_motion.kill()
	_exit_material = ShaderMaterial.new()
	_exit_material.shader = EXIT_SHADER
	_exit_material.set_shader_parameter("desaturation", 0.0)
	card.material = _exit_material
	_set_parent_material(card, true)
	var duration := NEDimensions.COMBAT_CARD_TRANSITION_SEC
	_exit_tween = create_tween().set_parallel(true)
	_exit_tween.tween_method(_set_desaturation, 0.0, 1.0, duration * 0.45)
	_exit_tween.tween_property(self, "position:y", -card_size().y - NEDimensions.SPACING_XL, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_exit_tween.tween_property(self, "modulate:a", 0.0, duration * 0.75).set_delay(duration * 0.25)
	_exit_tween.finished.connect(finished, CONNECT_ONE_SHOT)

func _set_desaturation(amount: float) -> void:
	if _exit_material:
		_exit_material.set_shader_parameter("desaturation", amount)

func release_card() -> PanelContainer:
	cancel_exit()
	if _motion and _motion.is_valid():
		_motion.kill()
	var released := card
	var origin := card.global_position if card.is_inside_tree() else position + card.position
	var factor := card.get_global_transform().get_scale() if card.is_inside_tree() else scale * card.scale
	card.reparent(get_parent(), false)
	if card.is_inside_tree():
		card.global_position = origin
	else:
		card.position = origin
	card.scale = factor
	card = null
	return released
