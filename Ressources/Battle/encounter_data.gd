class_name EncounterData extends Resource

@export var encounter_id: String = ""
@export var enemies: Array[BattleCharacterResource] = []
@export var reward_gold: int = 0
@export var reward_items: Array[Item] = []
@export var reward_item_counts: Array[int] = []
