class_name DialogueSystem
extends Node

## Spiel-Dialog unter MainGame/Systems.
## Das Addon-Autoload DialogueManager bleibt, weil das Plugin es braucht.

static var instance: DialogueSystem

signal dialogue_started
signal dialogue_ended

var _current_player: Playable
var _active_balloon: Node
var _active_npc: NPC


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func start_npc_dialogue(data: NPCData, player: Playable, source: NPCInteraction = null) -> void:
	if instance == null:
		push_error("DialogueSystem: MainGame ist nicht aktiv.")
		return
	instance._start_npc_dialogue(data, player, source)


func get_current_player() -> Playable:
	return _current_player


func open_shop(shop_id: String) -> void:
	var player := get_current_player()
	if player == null:
		return
	ShopManager.open(shop_id, player)


func start_encounter(encounter_id: String) -> void:
	var player := get_current_player()
	if player == null:
		return
	BattleManager.start_encounter(encounter_id, player)


func _start_npc_dialogue(data: NPCData, player: Playable, source: NPCInteraction = null) -> void:
	if data == null or player == null:
		return
	_current_player = player
	_restore_dialogue_npc_facing()
	_active_npc = _get_npc_from_interaction(source)
	if _active_npc:
		_active_npc.begin_dialogue_facing(player)
	GameState.acquire_input_lock()
	var start_cue := _resolve_start_cue(data)
	var resource := load(data.dialogue_file) as DialogueResource
	if resource == null:
		push_warning("DialogueSystem: Dialog '%s' konnte nicht geladen werden." % data.dialogue_file)
		_restore_dialogue_npc_facing()
		GameState.release_input_lock()
		return
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_active_balloon = DialogueManager.show_dialogue_balloon(resource, start_cue, [self, player, GameState])
	dialogue_started.emit()


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_active_balloon = null
	_restore_dialogue_npc_facing()
	GameState.release_input_lock()
	dialogue_ended.emit()


func _get_npc_from_interaction(source: NPCInteraction) -> NPC:
	if source == null:
		return null
	var parent := source.get_parent()
	return parent as NPC if parent is NPC else null


func _restore_dialogue_npc_facing() -> void:
	if _active_npc and is_instance_valid(_active_npc):
		_active_npc.end_dialogue_facing()
	_active_npc = null


func _resolve_start_cue(data: NPCData) -> String:
	var start_cue := data.dialogue_start if not data.dialogue_start.is_empty() else "start"
	if data.npc_id == "quest_giver_01":
		if GameState.get_flag("defeated_bandit", false) and not GameState.get_flag("quest_bandit_done", false):
			if _has_cue(data, "quest_done"):
				return "quest_done"
	if not data.defeated_flag.is_empty() and GameState.get_flag(data.defeated_flag, false):
		if _has_cue(data, "defeated"):
			return "defeated"
	return start_cue


func _has_cue(data: NPCData, cue: String) -> bool:
	var resource := load(data.dialogue_file) as DialogueResource
	if resource == null:
		return false
	return resource.titles.has(cue)
