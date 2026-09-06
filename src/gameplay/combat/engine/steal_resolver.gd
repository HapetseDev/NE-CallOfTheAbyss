class_name StealResolver extends Object

## Reiner Erfolgswürfel fürs Stehlen: Gewandheit des Diebs vs. Bewusstsein
## des Opfers. Trifft keine Entscheidung über Konsequenzen - Erfolg (stiller
## Transfer) und Fehlschlag (Kampf) werden von StealUI verdrahtet, analog zu
## CombatResolver, das ebenfalls nur auflöst statt Folgen zu verwalten.

static func roll_success(thief: Playable, victim: Playable) -> bool:
	if thief == null or victim == null:
		return false
	var gewandheit := thief.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)
	var bewusstsein := victim.get_effective_attribute(CharacterEnums.Attribute.BEWUSSTSEIN)
	var chance := clampf(
		CombatBalance.STEAL_BASE_CHANCE + (gewandheit - bewusstsein) * CombatBalance.STEAL_SKILL_FACTOR,
		CombatBalance.STEAL_CHANCE_MIN,
		CombatBalance.STEAL_CHANCE_MAX
	)
	return randf() < chance
