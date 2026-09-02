class_name ItemData
extends Resource

## Statische Item-Definition. Welt-Nodes und Inventar referenzieren diese Resource.

@export var item_id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var world_texture: Texture2D
@export var weight: float = 0.3
@export var max_stack: int = 99
## Leer = nicht ausrüstbar. Sonst Slot-Key wie "waffe".
@export var equipment_slot: String = ""
@export var consumable: bool = false
@export var heal_amount: int = 0
@export var mana_amount: int = 0


func apply_effects(target: Playable) -> void:
	if heal_amount > 0:
		target.heal(heal_amount)
	if mana_amount > 0:
		target.restore_mana(mana_amount)


func duplicate_item() -> ItemData:
	return duplicate(true) as ItemData
