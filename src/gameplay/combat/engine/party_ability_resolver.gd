class_name PartyAbilityResolver
extends Object

## Wendet eine Fähigkeit außerhalb einer CombatSession an – nur für Ziele
## innerhalb der eigenen Party (Selbst/Verbündete: HEAL/BUFF/UTILITY). Ruft
## ausschließlich bestehende Playable-Methoden auf, keine zweite HP/MP-
## Buchhaltung. DAMAGE-Fähigkeiten laufen NICHT hier durch – ein Angriff auf
## jemanden außerhalb der Party löst stattdessen CombatManager.trigger_attack
## aus und wird ganz regulär über CombatResolver aufgelöst (siehe
## state_party_skills.gd), damit es nur einen Schadenscode-Pfad gibt.


static func apply_non_combat(actor: Playable, ability: AbilityDefinition, target: Playable) -> bool:
	if actor == null or ability == null or target == null:
		return false
	if ability.mana_cost > 0 and not actor.use_mana(ability.mana_cost):
		return false
	match ability.effect_type:
		AbilityDefinition.EffectType.HEAL:
			target.heal(ability.power)
			return true
		_:
			# Kein Status-/Buff-System vorhanden – ehrlich melden statt so tun,
			# als hätte die Fähigkeit gewirkt (analog CombatResolver).
			return false
