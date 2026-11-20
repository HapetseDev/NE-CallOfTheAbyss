class_name ItemData
extends Resource

## Statische Item-Definition. Welt-Nodes und Inventar referenzieren diese Resource.

@export var item_id: String = ""
## Optionale stabile Instanz-ID für persistente Weltgegenstände; Vorlagen leer.
@export var world_object_id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D:
	get:
		if icon:
			return icon
		# Ältere Speicherstände enthalten noch icon=null. Ansicht anhand der
		# stabilen Item-ID ergänzen, ohne Zustands-/Save-Schemaänderung.
		if item_id in ["Messer", "Dolch", "Schwert", "Speer", "Bogen", "Pfeil"]:
			return load("res://assets/items/weapons/icons/" + item_id.to_lower() + ".png") as Texture2D
		return null
@export var world_texture: Texture2D
@export var weight: float = 0.3
@export var max_stack: int = 99
## Grundwert; Werte unter 1 werden auch bei alten/externen Daten begrenzt.
@export_range(1, 999) var combat_value: int = 1
## Zusätzlich zur Körperkraft auf den Schaden addiertes Talent.
@export var combat_skill_id: String = ""
## Kennzeichnung für örtlichen Schutz und die Mindestschadensregel.
@export var is_armor: bool = false
## Leer: Abdeckung über die Körperplätze des Profils; sonst explizite Zonen-IDs.
@export var armor_zones: Array[String] = []
## Schadensminderung je Typ: blunt, slash, pierce, magic.
@export var armor_protection: Dictionary = {}
## Optionale Richtungsfaktoren front/side/rear (0..2). Leer: Mensch 1/0,75/0,5,
## andere Körperprofile 1/1/1. 0 bedeutet aus dieser Richtung keine Abdeckung.
@export var armor_direction_factors: Dictionary = {}
## Bruch nach ausgeführtem Angriff, auch beim Ausweichen; 0 = unzerbrechlich.
@export_range(0.0, 1.0) var break_chance: float = 0.0
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
	improvised.power = get_combat_value()
	return [improvised]


func get_combat_value(mode: ItemUsageMode = null) -> int:
	# Bestehende Modi behalten ihre individuellen Werte, z.B. Messerwurf.
	return maxi(1, mode.power if mode != null and mode.power > 0 else combat_value)


func get_combat_skill_id(mode: ItemUsageMode = null) -> String:
	return combat_skill_id if not combat_skill_id.is_empty() else (mode.related_skill_id if mode != null else "")


func _validate_property(property: Dictionary) -> void:
	# Registry-Laufzeitkopien duplizieren auch externe Resources. Bildassets
	# bleiben geteilt, damit ihr stabiler Pfad für Speichern/Laden erhalten bleibt.
	if property.name in ["icon", "world_texture"]:
		property.usage |= PROPERTY_USAGE_NEVER_DUPLICATE
