class_name ItemUsageMode extends Resource

## Eine mögliche Verwendungsart eines Gegenstands im Kampf, z.B. "stechen"
## oder "werfen" bei einem Dolch, "schlagen" oder "werfen" bei einem Stein.
## Ein ItemData kann mehrere ItemUsageMode-Einträge haben (ItemData.usage_modes).

enum RangeType { MELEE, THROWN, RANGED }

@export var mode_id: String = ""
@export var label: String = ""
@export var attribute: CharacterEnums.Attribute = CharacterEnums.Attribute.KOERPERKRAFT
## Optionaler Talent-Bonus (SkillDefinition.skill_id), z.B. "messerwerfen".
@export var related_skill_id: String = ""
@export var range_type: RangeType = RangeType.MELEE
@export var power: int = 0
## true bei "werfen" – der Gegenstand verlässt die Hand/den Gürtel.
@export var consumes_item: bool = false
@export var requires_line_of_sight: bool = true
## Maximale räumliche Entfernung zwischen den Actor-Ursprüngen, in Metern.
@export_range(0.01, 1000.0, 0.1, "suffix:m") var range_meters: float = 1.5 * WorldUnits.METER
## Munition aus dem Rucksack; leer für Angriffe ohne separate Munition.
@export var ammunition_item_id: String = ""
@export_enum("blunt", "slash", "pierce", "magic") var damage_type: String = "blunt"


func is_in_range(origin: Node3D, target: Node3D) -> bool:
	if not is_instance_valid(origin) or not is_instance_valid(target) or not is_finite(range_meters) or range_meters <= 0.0:
		return false
	# Die Textsimulation verwendet absichtlich Actors außerhalb des Szenenbaums.
	var start := origin.global_position if origin.is_inside_tree() else origin.position
	var end := target.global_position if target.is_inside_tree() else target.position
	return start.distance_squared_to(end) <= range_meters * range_meters
