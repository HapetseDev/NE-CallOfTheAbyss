extends Node3D

const COMBATANT_SCENE := preload("res://src/gameplay/combat/battle_combatant.tscn")

@onready var turn_controller: TurnBasedController = $TurnBasedController

var _player_resources: Array[BattleCharacterResource] = []


func _ready() -> void:
	turn_controller.battle_finished.connect(_on_battle_finished)
	_setup_encounter()


func _setup_encounter() -> void:
	if BattleManager.instance == null:
		push_warning("BattleScene: BattleManager ist nicht aktiv.")
		return
	var encounter := BattleManager.instance.pending_encounter
	if encounter == null:
		push_warning("BattleScene: Kein Encounter gesetzt.")
		return
	var player_positions := [Vector3(-3, 0, 0), Vector3(-4, 0, 1.5), Vector3(-4, 0, -1.5)]
	var enemy_positions := [Vector3(3, 0, 0), Vector3(4, 0, 1.5), Vector3(4, 0, -1.5)]
	for i in BattleManager.instance.party_battle_resources.size():
		var res := BattleManager.instance.party_battle_resources[i].duplicate(true) as BattleCharacterResource
		if res == null:
			continue
		_player_resources.append(res)
		var pos: Vector3 = player_positions[i] if i < player_positions.size() else player_positions[0]
		_spawn_combatant(res, pos, TurnBasedAgent.Character_Type.PLAYER)
	for i in encounter.enemies.size():
		var enemy_res := encounter.enemies[i].duplicate(true) as BattleCharacterResource
		if enemy_res == null:
			continue
		var pos: Vector3 = enemy_positions[i] if i < enemy_positions.size() else enemy_positions[0]
		_spawn_combatant(enemy_res, pos, TurnBasedAgent.Character_Type.ENEMY)


func _spawn_combatant(
		resource: BattleCharacterResource,
		spawn_position: Vector3,
		agent_type: TurnBasedAgent.Character_Type
) -> void:
	var combatant: Node3D = COMBATANT_SCENE.instantiate()
	add_child(combatant)
	combatant.global_position = spawn_position
	if combatant.has_method("setup"):
		combatant.setup(resource, agent_type)


func _on_battle_finished(victory: bool) -> void:
	await get_tree().create_timer(0.5).timeout
	BattleManager.finish_battle(victory, _player_resources)
