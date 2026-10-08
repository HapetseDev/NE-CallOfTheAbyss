class_name NPC extends Playable

## Alle vorhandenen NPCs verwenden persistente Charakterdaten.
## Benötigt NPCData.npc_id und eine explizite CharacterResource-Vorlage.
@export var use_character_registry: bool = true

@onready var state_machine: PlayerStateMachine = get_node_or_null("StateMachine") as PlayerStateMachine

# Zielposition für KI-Bewegung
var _target_direction: Vector3 = Vector3.ZERO
var _dialogue_facing_active: bool = false
var _saved_facing_direction: Vector3 = Vector3(0, 0, 1)
var _saved_cardinal_direction: Vector3 = Vector3(0, 0, 1)


func _ready() -> void:
	if not _resolve_character():
		push_error("NPC: Charakterregistrierung für '%s' fehlgeschlagen." % name)
		queue_free()
		return
	if state_machine:
		state_machine.initialize(self)
	super._ready()
	update_animation("idle")
	var interaction := get_node_or_null("Interaction") as NPCInteraction
	# Kompatibilität: vorhandene Sieg-Flags beim ersten Szenenaufbau übernehmen.
	if interaction and interaction.data and not interaction.data.defeated_flag.is_empty():
		if GameState.get_flag(interaction.data.defeated_flag, false):
			character.is_defeated = true
		elif character.is_defeated:
			interaction.mark_defeated()
	refresh_defeated_state()


func _resolve_character() -> bool:
	var interaction := get_node_or_null("Interaction") as NPCInteraction
	if use_character_registry:
		if interaction == null or interaction.data == null:
			return false
		var data := interaction.data
		var template := character if character != null else data.character
		character = GameState.character_registry.register_character(data.npc_id, template)
		return character != null

	if character != null:
		return true

	if interaction and interaction.data:
		var data := interaction.data
		character = _SheetFactory.resolve_sheet(
			data.npc_id,
			data.display_name,
			data.character
		)
		return true

	if not name.is_empty():
		character = _SheetFactory.create_default(name)
	return true


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
	if character and character.is_defeated or is_in_combat_mode():
		return Vector3.ZERO
	return _target_direction


func set_target_direction(dir: Vector3) -> void:
	_target_direction = dir.normalized()


## Keine Todesdarstellung: besiegte Figuren bleiben sichtbar und ansprechbar.
func refresh_defeated_state() -> void:
	if character == null or not character.is_defeated:
		return
	_target_direction = Vector3.ZERO
	stop_horizontal_velocity()
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	update_animation("idle")


func exit_combat_mode() -> void:
	super.exit_combat_mode()
	refresh_defeated_state()
