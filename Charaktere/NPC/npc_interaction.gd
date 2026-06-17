class_name NPCInteraction extends Node3D

@export var data: NPCData

var _owner_npc: NPC


func _ready() -> void:
	add_to_group("interactable")
	_owner_npc = get_parent() as NPC


func is_defeated() -> bool:
	if data == null or data.defeated_flag.is_empty():
		return false
	return GameState.get_flag(data.defeated_flag, false)


func mark_defeated() -> void:
	if data != null and not data.defeated_flag.is_empty():
		GameState.set_flag(data.defeated_flag, true)


func get_actions(_player: Playable) -> Array[Dictionary]:
	if data == null:
		return []
	var actions: Array[Dictionary] = [{"label": "Reden", "action_id": "talk"}]
	if data.can_trade and not is_defeated():
		actions.append({"label": "Handeln", "action_id": "trade"})
	if data.can_fight and not is_defeated():
		actions.append({"label": "Angreifen", "action_id": "fight"})
	return actions


func perform_action(action_id: String, player: Playable) -> void:
	if data == null:
		return
	match action_id:
		"talk":
			GameDialogueBridge.start_npc_dialogue(data, player)
		"trade":
			if data.can_trade and not data.shop_id.is_empty():
				ShopManager.open(data.shop_id, player)
		"fight":
			if data.can_fight and not data.encounter_id.is_empty():
				BattleManager.start_encounter(data.encounter_id, player, self)
