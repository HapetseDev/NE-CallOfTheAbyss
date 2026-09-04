class_name NPC extends Playable

@onready var state_machine: PlayerStateMachine = get_node_or_null("StateMachine") as PlayerStateMachine

# Zielposition für KI-Bewegung
var _target_direction: Vector3 = Vector3.ZERO
var _dialogue_facing_active: bool = false
var _saved_facing_direction: Vector3 = Vector3(0, 0, 1)
var _saved_cardinal_direction: Vector3 = Vector3(0, 0, 1)


func _ready() -> void:
	_resolve_character()
	if state_machine:
		state_machine.initialize(self)
	super._ready()
	update_animation("idle")


func _resolve_character() -> void:
	if character != null:
		return

	var interaction := get_node_or_null("Interaction") as NPCInteraction
	if interaction and interaction.data:
		var data := interaction.data
		character = _SheetFactory.resolve_sheet(
			data.npc_id,
			data.display_name,
			data.character
		)
		return

	if not name.is_empty():
		character = _SheetFactory.create_default(name)


func begin_dialogue_facing(target: Node3D) -> void:
	if target == null:
		return
	if not _dialogue_facing_active:
		_saved_facing_direction = facing_direction
		_saved_cardinal_direction = cardinal_direction
		_dialogue_facing_active = true
	face_world_position(target.global_position)


func end_dialogue_facing() -> void:
	if not _dialogue_facing_active:
		return
	facing_direction = _saved_facing_direction
	cardinal_direction = _saved_cardinal_direction
	_apply_facing()
	_dialogue_facing_active = false


# Wird von KI-Logik / States gesetzt, nicht von Input
func get_move_direction() -> Vector3:
	if is_in_combat_mode():
		return Vector3.ZERO
	return _target_direction


func set_target_direction(dir: Vector3) -> void:
	_target_direction = dir.normalized()
