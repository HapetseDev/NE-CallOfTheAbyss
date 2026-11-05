class_name CombatBodyZone extends Resource

## Modell-lokale Trefferbox in Metern: +Z vorne, +X rechts, +Y oben.
@export var zone_id: String = "torso"
@export var label: String = "Rumpf"
@export var center: Vector3 = Vector3(0, 0.55, 0)
@export var size: Vector3 = Vector3(0.4, 0.45, 0.3)
@export var damage_multiplier: float = 1.0
@export var natural_protection: Dictionary = {}
## Körperplätze, deren tatsächlich angelegte Rüstung diese Zone schützt.
@export var equipment_slots: Array[String] = []
