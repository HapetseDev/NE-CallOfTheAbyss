class_name NPCData extends Resource

@export var npc_id: String = ""
@export var display_name: String = ""
@export var character_sheet: CharacterSheet
@export_file("*.dialogue") var dialogue_file: String = ""
@export var dialogue_start: String = "start"
@export var shop_id: String = ""
@export var encounter_id: String = ""
@export var can_trade: bool = false
@export var can_fight: bool = false
@export var defeated_flag: String = ""
