class_name Item extends Resource

@export var item_id: String = ""
@export var item_name: String = ""
@export_multiline var beschreibung: String = ""
@export var icon: Texture2D
@export var max_stapel: int = 99
## Leer = nicht ausrüstbar. Sonst Slot-Key wie in Playable.equipment (z. B. "waffe").
@export var ausrüstungs_slot: String = ""
