class_name ItemUsageMode extends Resource

## Eine mögliche Verwendungsart eines Gegenstands im Kampf, z.B. "stechen"
## oder "werfen" bei einem Dolch, "schlagen" oder "werfen" bei einem Stein.
## Ein ItemData kann mehrere ItemUsageMode-Einträge haben (ItemData.usage_modes).

enum RangeType { MELEE, THROWN }

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
