class_name AbilityDefinition extends Resource

## Eine im Kampf einsetzbare Fähigkeit (Magie, Gesang, Kampftechniken, …).
## Brücke zwischen dem RPG-Talentsystem (SkillDefinition/learned_skills) und
## dem Kampf: source_skill_id verweist auf ein bestehendes Talent, dessen
## gelernter Level (CharacterResource.get_skill_level) die Fähigkeit freischaltet.
## Siehe AbilityCatalog.get_available_for().

enum TargetType { SELF, SINGLE_ENEMY, SINGLE_ALLY, ALL_ENEMIES, ALL_ALLIES }
enum RangeType { MELEE, RANGED, SELF }
enum EffectType { DAMAGE, HEAL, BUFF, DEBUFF, UTILITY }

@export var ability_id: String = ""
@export var ability_name: String = ""
@export_multiline var beschreibung: String = ""

## Talent, das diese Fähigkeit gewährt (SkillDefinition.skill_id, z.B. "magiekunde").
@export var source_skill_id: String = ""
@export var min_skill_level: int = 1

@export var mana_cost: int = 0
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var range_type: RangeType = RangeType.RANGED
@export var effect_type: EffectType = EffectType.DAMAGE
@export var power: int = 0
@export var requires_line_of_sight: bool = true
@export_enum("blunt", "slash", "pierce", "magic") var damage_type: String = "magic"
## Reichweitenbegrenzung für Nahkampffähigkeiten einschließlich Fausthieb.
@export_range(0.01, 1000.0, 0.1, "suffix:m") var melee_range_meters: float = 1.5 * WorldUnits.METER

func is_in_range(origin: Node3D, target: Node3D) -> bool:
	if range_type != RangeType.MELEE:
		return true
	if not is_instance_valid(origin) or not is_instance_valid(target) or not is_finite(melee_range_meters) or melee_range_meters <= 0:
		return false
	var start := origin.global_position if origin.is_inside_tree() else origin.position
	var end := target.global_position if target.is_inside_tree() else target.position
	return start.distance_squared_to(end) <= melee_range_meters * melee_range_meters
