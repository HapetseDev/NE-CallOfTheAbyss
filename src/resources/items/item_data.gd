class_name ItemData
extends Resource

## Statische Item-Definition. Welt-Nodes und Inventar referenzieren diese Resource.

@export var item_id: String = ""
## Optionale stabile Instanz-ID für persistente Weltgegenstände; Vorlagen leer.
@export var world_object_id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var world_texture: Texture2D
@export var weight: float = 0.3
@export var max_stack: int = 99
## Bevorzugter Körper-/Handplatz. Hände/Schnellausrüstung nehmen jedes Item auf.
@export var equipment_slot: String = ""
@export var consumable: bool = false
@export var heal_amount: int = 0
@export var mana_amount: int = 0
## Wie dieser Gegenstand im Kampf eingesetzt werden kann (stechen, schlagen,
## werfen, …). Ohne eigene Modi ist ein improvisierter Schlag möglich.
@export var usage_modes: Array[ItemUsageMode] = []


func apply_effects(target: Playable) -> void:
	if heal_amount > 0:
		target.heal(heal_amount)
	if mana_amount > 0:
		target.restore_mana(mana_amount)


func duplicate_item() -> ItemData:
	return duplicate(true) as ItemData


## Keine zusätzliche gespeicherte Resource: allgemeiner Angriff zur Laufzeit.
func get_combat_usage_modes() -> Array[ItemUsageMode]:
	if not usage_modes.is_empty():
		return usage_modes
	var improvised := ItemUsageMode.new()
	improvised.mode_id = "improvisiert_schlagen"
	improvised.label = "Schlagen (improvisiert)"
	improvised.power = CombatBalance.IMPROVISED_ITEM_POWER
	return [improvised]
