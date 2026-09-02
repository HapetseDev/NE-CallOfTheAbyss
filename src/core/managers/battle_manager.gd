class_name BattleManager
extends Node

## Kampfsystem unter MainGame/Systems. Kein Autoload.

static var instance: BattleManager

var pending_encounter: EncounterData
var party_battle_resources: Array[BattleCharacterResource] = []
var pending_party_sync: Array[BattleCharacterResource] = []
var pending_defeated_flag: String = ""
var has_pending_sync: bool = false
var last_victory: bool = false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func start_encounter(encounter_id: String, player: Playable, source_npc: NPCInteraction = null) -> void:
	if instance == null:
		push_error("BattleManager: MainGame ist nicht aktiv.")
		return
	instance._start_encounter(encounter_id, player, source_npc)


static func finish_battle(victory: bool, synced_resources: Array[BattleCharacterResource]) -> void:
	if instance == null:
		push_error("BattleManager: MainGame ist nicht aktiv.")
		return
	instance._finish_battle(victory, synced_resources)


static func apply_pending_party_state(party: Party) -> void:
	if instance == null:
		return
	instance._apply_pending_party_state(party)


func _start_encounter(encounter_id: String, player: Playable, source_npc: NPCInteraction = null) -> void:
	var encounter := _load_encounter(encounter_id)
	if encounter == null:
		push_warning("BattleManager: Encounter '%s' nicht gefunden." % encounter_id)
		return
	if MainGame.instance == null:
		push_error("BattleManager: Kampf nur in MainGame möglich.")
		return
	pending_encounter = encounter
	party_battle_resources.clear()
	for playable in _collect_party(player):
		party_battle_resources.append(BattleCharacterFactory.from_playable(playable))
	pending_defeated_flag = ""
	if source_npc and source_npc.data and not source_npc.data.defeated_flag.is_empty():
		pending_defeated_flag = source_npc.data.defeated_flag
	GameState.acquire_input_lock()
	MainGame.instance.start_battle()


func _finish_battle(victory: bool, synced_resources: Array[BattleCharacterResource]) -> void:
	last_victory = victory
	pending_party_sync.clear()
	for res in synced_resources:
		if res is BattleCharacterResource:
			pending_party_sync.append(res.duplicate(true))
	has_pending_sync = not pending_party_sync.is_empty()
	if victory and not pending_defeated_flag.is_empty():
		GameState.set_flag(pending_defeated_flag, true)
	GameState.release_input_lock()
	if MainGame.instance:
		MainGame.instance.end_battle()


func _apply_pending_party_state(party: Party) -> void:
	if not has_pending_sync or party == null:
		return
	var members := party.get_all_members()
	for i in mini(pending_party_sync.size(), members.size()):
		var playable := members[i]
		var res := pending_party_sync[i]
		playable.health = res.currentHealth
		playable.mana = res.currentMana
	if last_victory:
		_apply_rewards(members)
	has_pending_sync = false
	pending_party_sync.clear()
	party_battle_resources.clear()
	pending_encounter = null
	pending_defeated_flag = ""


func _load_encounter(encounter_id: String) -> EncounterData:
	var path := "res://src/resources/combat/encounters/%s.tres" % encounter_id
	if ResourceLoader.exists(path):
		return load(path) as EncounterData
	return null


func _collect_party(player: Playable) -> Array[Playable]:
	var node: Node = player
	while node:
		if node is Party:
			return (node as Party).get_all_members()
		node = node.get_parent()
	return [player]


func _apply_rewards(members: Array[Playable]) -> void:
	if pending_encounter == null or members.is_empty():
		return
	var leader := members[0]
	if pending_encounter.reward_gold > 0:
		leader.gold += pending_encounter.reward_gold
	for i in pending_encounter.reward_items.size():
		var item := pending_encounter.reward_items[i]
		if item == null:
			continue
		var count := 1
		if i < pending_encounter.reward_item_counts.size():
			count = pending_encounter.reward_item_counts[i]
		leader.add_item(item.duplicate_item(), count)
