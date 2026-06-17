extends Node

signal dialogue_started
signal dialogue_ended

var _current_player: Playable
var _input_locked: bool = false
var _active_balloon: Node


func set_player_input_locked(locked: bool) -> void:
	_input_locked = locked


func is_player_input_locked() -> bool:
	return _input_locked or _active_balloon != null


func get_current_player() -> Playable:
	return _current_player


func start_npc_dialogue(data: NPCData, player: Playable) -> void:
	if data == null or player == null:
		return
	_current_player = player
	set_player_input_locked(true)
	var start_cue := _resolve_start_cue(data)
	var resource := load(data.dialogue_file) as DialogueResource
	if resource == null:
		push_warning("GameDialogueBridge: Dialog '%s' konnte nicht geladen werden." % data.dialogue_file)
		set_player_input_locked(false)
		return
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_active_balloon = DialogueManager.show_dialogue_balloon(resource, start_cue, [self, player, GameState])
	dialogue_started.emit()


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


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_active_balloon = null
	set_player_input_locked(false)
	dialogue_ended.emit()

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
