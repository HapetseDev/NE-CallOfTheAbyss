class_name CombatResolver
extends Object

## Löst CombatAction (ITEM/ABILITY/MOVE) auf. Ruft ausschließlich die
## bereits vorhandenen Playable-Methoden auf (take_damage/heal/use_mana/…) –
## keine zweite HP/MP-Buchhaltung wie beim alten BattleCharacterResource.
## Kennt keine CombatSession (kein mark_defeated hier, siehe CombatActionResult).


static func resolve_action(action: CombatAction, rng: RandomNumberGenerator = null, log_item_break: bool = true) -> CombatActionResult:
	if action == null or action.actor == null or action.actor.playable == null:
		var invalid := CombatActionResult.new()
		invalid.success = false
		invalid.failed_reason = "invalid_actor"
		return invalid
	match action.type:
		CombatAction.ActionType.ITEM:
			return _resolve_item(action, rng, log_item_break)
		CombatAction.ActionType.ABILITY:
			return _resolve_ability(action, rng)
		CombatAction.ActionType.MOVE:
			return _resolve_move(action)
		_:
			var result := CombatActionResult.new()
			result.success = false
			result.failed_reason = "not_handled_by_resolver"
			return result


## Automatische Verteidigung: jeder Charakter weicht/mindert Schaden passiv
## über seine eigenen Attribute, ohne dass er dafür einen Zug braucht.
static func resolve_damage(actor: CombatParticipant, target: CombatParticipant, raw_power: int, attacker_attribute: CharacterEnums.Attribute, rng: RandomNumberGenerator = null, armored_hit: Variant = null, zone_id: String = "", damage_type: String = "blunt") -> int:
	return int(_roll_damage(actor, target, raw_power, attacker_attribute, rng, armored_hit, zone_id, damage_type)["damage"])


## Wie resolve_damage(), gibt zusätzlich zurück, ob das Ziel ausgewichen ist
## (für Anzeige-Zwecke, siehe CombatActionOutcome). Intern verwendet, damit
## resolve_damage() selbst öffentlich weiterhin nur den Schadenswert liefert.
static func _roll_damage(actor: CombatParticipant, target: CombatParticipant, raw_power: int, attacker_attribute: CharacterEnums.Attribute, rng: RandomNumberGenerator = null, armored_hit: Variant = null, zone_id: String = "", damage_type: String = "blunt") -> Dictionary:
	if target == null or target.playable == null or target.is_out_of_combat():
		return {"damage": 0, "evaded": false}
	var body := CombatAnatomy.profile(target.playable.character)
	var zone := body.get_zone(zone_id if not zone_id.is_empty() else body.default_zone_id)
	if zone == null or damage_type not in CombatAnatomy.DAMAGE_TYPES:
		return {"damage": 0, "evaded": false}
	var attacker: Playable = actor.playable if actor else null
	var accuracy := attacker.get_effective_attribute(attacker_attribute) if attacker else 0
	var evasion := target.playable.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)
	var factor := CombatAnatomy.evasion_factor(attacker, target.playable) if attacker else 1.0
	var evade_chance := clampf((evasion * factor - accuracy) * CombatBalance.EVADE_FACTOR * 0.01, 0.0, CombatBalance.EVADE_CAP)
	var roll := {"damage": 0, "evaded": false, "zone_id": zone.zone_id,
		"incoming_direction": CombatAnatomy.direction(attacker, target.playable), "damage_type": damage_type}
	if (rng.randf() if rng else randf()) < evade_chance:
		roll.evaded = true
		return roll
	var protection := CombatAnatomy.protection(target.playable.character, zone, damage_type)
	var mitigation := target.playable.get_effective_attribute(CharacterEnums.Attribute.ROBUSTHEIT) * CombatBalance.MITIGATION_FACTOR + float(protection.amount)
	var armored: bool = bool(protection.armored) if armored_hit == null else bool(armored_hit)
	var minimum := 1 if raw_power > 0 and not armored else 0
	var final_damage := maxi(minimum, roundi(raw_power * zone.damage_multiplier) - int(mitigation))
	if final_damage > 0:
		target.playable.take_damage(final_damage)
	roll.damage = final_damage
	return roll


## Gemeinsame Trefferermittlung für Vorschau und Auflösung. Nur bestehende
## Session-Teilnehmer verwenden; ausgeschiedene/unbeteiligte Körper blockieren.
static func get_item_attack_hit(actor: CombatParticipant, aimed: CombatParticipant, mode: ItemUsageMode, zone_id: String = "") -> Dictionary:
	if mode == null:
		return {}
	return CombatAnatomy.trace(actor, aimed, mode.requires_line_of_sight, zone_id)


static func get_item_attack_target(actor: CombatParticipant, aimed: CombatParticipant, mode: ItemUsageMode, zone_id: String = "") -> CombatParticipant:
	return get_item_attack_hit(actor, aimed, mode, zone_id).get("target") as CombatParticipant


static func _resolve_item(action: CombatAction, rng: RandomNumberGenerator = null, log_item_break: bool = true) -> CombatActionResult:
	var result := CombatActionResult.new()
	var mode := action.item_usage_mode
	if action.item != null and action.item.consumable and mode == null:
		return _resolve_consumable(action)
	if action.item == null or mode == null:
		result.success = false
		result.failed_reason = "invalid_item"
		return result
	if mode.damage_type not in CombatAnatomy.DAMAGE_TYPES:
		result.success = false
		result.failed_reason = "invalid_item"
		return result
	if not mode.ammunition_item_id.is_empty() and action.targets.size() != 1:
		result.success = false
		result.failed_reason = "invalid_target"
		return result
	# Vor Verbrauch auf gültiges Ziel, Reichweite und Sicht prüfen.
	var valid_targets: Array[CombatParticipant] = []
	var hits: Dictionary = {}
	for aimed in action.targets:
		if aimed != null and is_instance_valid(aimed.playable) and not mode.is_in_range(action.actor.playable, aimed.playable):
			result.failed_reason = "out_of_range"
			continue
		var hit := get_item_attack_hit(action.actor, aimed, mode, action.target_zone_id)
		var target := hit.get("target") as CombatParticipant
		if target == null:
			result.failed_reason = "no_line_of_sight"
			continue
		if not mode.is_in_range(action.actor.playable, target.playable):
			result.failed_reason = "out_of_range"
			continue
		if not valid_targets.has(target):
			valid_targets.append(target)
			hits[target] = hit
	if valid_targets.is_empty():
		result.success = false
		if result.failed_reason.is_empty():
			result.failed_reason = "invalid_target"
		return result
	var inventory := action.actor.playable.character.inventory
	if not mode.ammunition_item_id.is_empty() and not inventory.has_item(mode.ammunition_item_id):
		result.success = false
		result.failed_reason = "no_ammunition"
		return result
	if mode.consumes_item and not action.actor.playable.consume_combat_item(action.item):
		result.success = false
		result.failed_reason = "invalid_item"
		return result
	if not mode.ammunition_item_id.is_empty():
		inventory.consume_ammunition(mode.ammunition_item_id)
	for target in valid_targets:
		var sheet := action.actor.playable.character
		var power := sheet.get_effective_attribute(CharacterEnums.Attribute.KOERPERKRAFT) + action.item.get_combat_value(mode)
		power += get_damage_skill_bonus(sheet, action.item.get_combat_skill_id(mode))
		var roll := _roll_damage(action.actor, target, power, mode.attribute, rng, null, hits[target].zone_id, mode.damage_type)
		var outcome := _make_outcome(target, roll)
		result.outcomes.append(outcome)
		if outcome.defeated:
			result.defeated_targets.append(target)
	if not mode.consumes_item and not result.outcomes.is_empty() and (rng.randf() if rng else randf()) < action.item.break_chance:
		if action.actor.playable.consume_combat_item(action.item) and log_item_break:
			EventLog.add("%s zerbricht." % action.item.item_name)
	return result


static func _resolve_consumable(action: CombatAction) -> CombatActionResult:
	var result := CombatActionResult.new()
	if action.targets.size() != 1 or action.targets[0] == null:
		result.success = false
		result.failed_reason = "invalid_item"
		return result
	var target := action.targets[0]
	if target.playable == null or target.is_out_of_combat() or target.side != action.actor.side:
		result.success = false
		result.failed_reason = "invalid_item"
		return result
	if not action.actor.playable.consume_combat_item(action.item):
		result.success = false
		result.failed_reason = "invalid_item"
		return result
	var health_before := target.playable.health
	action.item.apply_effects(target.playable)
	var outcome := CombatActionOutcome.new()
	outcome.target = target
	outcome.healed = maxi(0, target.playable.health - health_before)
	result.outcomes.append(outcome)
	return result


static func _resolve_ability(action: CombatAction, rng: RandomNumberGenerator = null) -> CombatActionResult:
	var result := CombatActionResult.new()
	var ability := action.ability
	if ability == null:
		result.success = false
		result.failed_reason = "invalid_ability"
		return result
	if ability.effect_type == AbilityDefinition.EffectType.DAMAGE and not action.target_zone_id.is_empty():
		for target in action.targets:
			if target == null or not is_instance_valid(target.playable) or CombatAnatomy.profile(target.playable.character).get_zone(action.target_zone_id) == null:
				result.success = false
				result.failed_reason = "invalid_target"
				return result
	if ability.range_type == AbilityDefinition.RangeType.MELEE:
		for target in action.targets:
			if target != null and is_instance_valid(target.playable) and not ability.is_in_range(action.actor.playable, target.playable):
				result.success = false
				result.failed_reason = "out_of_range"
				return result
	if ability.mana_cost > 0 and not action.actor.playable.use_mana(ability.mana_cost):
		result.success = false
		result.failed_reason = "not_enough_mana"
		return result

	match ability.effect_type:
		AbilityDefinition.EffectType.DAMAGE:
			_apply_damage_to_targets(action, ability, result, rng)
		AbilityDefinition.EffectType.HEAL:
			_apply_heal_to_targets(action, ability, result)
		_:
			# Kein Status-/Buff-System vorhanden – ehrlich melden statt so tun,
			# als hätte die Fähigkeit gewirkt.
			result.success = false
			result.failed_reason = "effect_not_implemented"
	return result


static func _apply_damage_to_targets(action: CombatAction, ability: AbilityDefinition, result: CombatActionResult, rng: RandomNumberGenerator = null) -> void:
	var scaling_attribute := _primary_attribute_for(ability)
	for target in action.targets:
		if target == null or target.playable == null or target.is_out_of_combat():
			continue
		if ability.requires_line_of_sight and not CombatLineOfSight.has_clear_line(action.actor.playable, target.playable):
			result.failed_reason = "no_line_of_sight"
			continue
		var power := ability.power
		if ability.ability_id == "fausthieb":
			var sheet := action.actor.playable.character
			power = sheet.get_effective_attribute(CharacterEnums.Attribute.KOERPERKRAFT) + get_damage_skill_bonus(sheet, "waffenloser_kampf")
		var roll := _roll_damage(action.actor, target, power, scaling_attribute, rng, null, action.target_zone_id, "blunt" if ability.ability_id == "fausthieb" else ability.damage_type)
		var outcome := _make_outcome(target, roll)
		result.outcomes.append(outcome)
		if outcome.defeated:
			result.defeated_targets.append(target)


static func _apply_heal_to_targets(action: CombatAction, ability: AbilityDefinition, result: CombatActionResult) -> void:
	for target in action.targets:
		if target == null or target.playable == null or target.is_out_of_combat():
			continue
		target.playable.heal(ability.power)
		var outcome := CombatActionOutcome.new()
		outcome.target = target
		outcome.healed = ability.power
		result.outcomes.append(outcome)


static func _make_outcome(target: CombatParticipant, roll: Dictionary) -> CombatActionOutcome:
	var outcome := CombatActionOutcome.new()
	outcome.target = target
	outcome.damage = int(roll["damage"])
	outcome.evaded = bool(roll["evaded"])
	outcome.zone_id = roll.get("zone_id", "")
	outcome.incoming_direction = roll.get("incoming_direction", "front")
	outcome.damage_type = roll.get("damage_type", "blunt")
	outcome.defeated = outcome.damage > 0 and target.playable.is_character_dead()
	return outcome


static func _primary_attribute_for(ability: AbilityDefinition) -> CharacterEnums.Attribute:
	if ability.source_skill_id.is_empty():
		return CharacterEnums.Attribute.KOERPERKRAFT
	var definition: SkillDefinition = SkillCatalog.get_definition(ability.source_skill_id)
	if definition:
		return definition.attribute
	return CharacterEnums.Attribute.KOERPERKRAFT


static func _resolve_move(action: CombatAction) -> CombatActionResult:
	var result := CombatActionResult.new()
	action.actor.playable.global_position = action.move_target_position
	return result


static func get_damage_skill_bonus(sheet: CharacterResource, skill_id: String) -> int:
	return floori(maxi(0, sheet.get_skill_level(skill_id)) / 2.0)


static func has_worn_armor(sheet: CharacterResource) -> bool:
	if sheet == null or sheet.inventory == null:
		return false
	# Besitzabfrage für bestehende Aufrufer. Schadensberechnung verwendet dagegen
	# ausschließlich CombatAnatomy.protection() für die tatsächlich getroffene Zone.
	for slot in ["kopf", "rumpf", "beine", "fuesse", "schmuck"]:
		var item: Variant = sheet.inventory.equipment.get(slot)
		if item is ItemData and item.is_armor:
			return true
	return false
