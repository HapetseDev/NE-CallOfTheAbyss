class_name Item extends Resource

@export var item_id: String = ""
@export var item_name: String = ""
@export_multiline var beschreibung: String = ""
@export var icon: Texture2D
@export var world_texture: Texture2D
@export var max_stapel: int = 99
@export var masse: float = 0.3
## Leer = nicht ausrüstbar. Sonst Slot-Key wie in Playable.equipment (z. B. "waffe").
@export var ausrüstungs_slot: String = ""
@export var verbrauchbar: bool = false
@export var heal_amount: int = 0
@export var mana_amount: int = 0


func apply_effects(target: Playable) -> void:
	if heal_amount > 0:
		target.heal(heal_amount)
	if mana_amount > 0:
		target.restore_mana(mana_amount)


func duplicate_item() -> Item:
	return duplicate(true) as Item
