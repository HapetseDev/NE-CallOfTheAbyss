class_name CombatAction extends RefCounted

## Eine gewählte Handlung für einen Kampfzug. ITEM/ABILITY/MOVE werden von
## CombatResolver aufgelöst (reine Stat-/Positions-Mutation). COMMUNICATE und
## FLEE haben Szenen-Seiteneffekte (Dialog öffnen, Session verlassen) und
## werden direkt vom aufrufenden State (state_combat_turn.gd) behandelt.

enum ActionType { ITEM, ABILITY, MOVE, COMMUNICATE, FLEE }

var actor: CombatParticipant
var type: ActionType
var targets: Array[CombatParticipant] = []

## ActionType.ABILITY
var ability: AbilityDefinition = null
## ActionType.ITEM
var item: ItemData = null
var item_usage_mode: ItemUsageMode = null
## ActionType.MOVE
var move_target_position: Vector3 = Vector3.ZERO
