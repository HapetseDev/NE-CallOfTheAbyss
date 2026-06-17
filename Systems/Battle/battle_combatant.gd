extends Node3D

@export var character_resource: BattleCharacterResource

@onready var turn_based_agent: TurnBasedAgent = $TurnBasedAgent


func _ready() -> void:
	if turn_based_agent:
		turn_based_agent.target_selected.connect(_on_target_selected)
		turn_based_agent.enemy_turn_started.connect(_on_enemy_turn_started)
		turn_based_agent.command_without_target_selected.connect(_on_command_without_target)
		turn_based_agent.characterResource = character_resource
		turn_based_agent.turnOrderValueName = "speed"


func setup(resource: BattleCharacterResource, agent_type: TurnBasedAgent.Character_Type) -> void:
	character_resource = resource
	if turn_based_agent:
		turn_based_agent.characterResource = resource
		turn_based_agent.character_type = agent_type


func take_damage(amount: int) -> void:
	if character_resource == null:
		return
	character_resource.take_damage(amount)
	if not character_resource.is_alive():
		turn_based_agent.isDisabled = true
		visible = false


func _on_target_selected(_main_target: TurnBasedAgent, targets: Array[TurnBasedAgent], command: Resource) -> void:
	var amount := _get_command_damage(command)
	for target in targets:
		var parent := target.get_parent()
		if parent == null or not parent.has_method("take_damage"):
			continue
		if command is CommandResource and command.commandType == CommandResource.Command_Type.HEAL:
			_heal_combatant(parent, -amount)
		else:
			parent.take_damage(amount)
	turn_based_agent.command_done()


func _heal_combatant(combatant: Node, amount: int) -> void:
	if combatant.get("character_resource") == null:
		return
	var res: BattleCharacterResource = combatant.character_resource
	res.currentHealth = mini(res.currentHealth + amount, res.maxHealth)


func _on_enemy_turn_started() -> void:
	var players := get_tree().get_nodes_in_group("turnBasedPlayer")
	var living: Array = players.filter(func(p): return p is TurnBasedAgent and not p.isDisabled)
	if living.is_empty():
		turn_based_agent.command_done()
		return
	var target_agent: TurnBasedAgent = living.pick_random()
	var target_parent := target_agent.get_parent()
	if target_parent and target_parent.has_method("take_damage"):
		target_parent.take_damage(_get_command_damage(character_resource.basic_attack))
	turn_based_agent.command_done()


func _on_command_without_target(_command: Resource) -> void:
	turn_based_agent.command_done()


func _get_command_damage(command: Resource) -> int:
	if command == null:
		return 10
	if command.get("damage") != null:
		return int(command.get("damage"))
	return 15
