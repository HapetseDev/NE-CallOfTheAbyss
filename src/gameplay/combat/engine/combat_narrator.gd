class_name CombatNarrator
extends Object

## Baut deutsche Anzeige-Texte aus einer aufgelösten CombatAction für ein
## Aktions-Feedback-HUD (siehe CombatLogHud). Kennt nur CombatAction/
## CombatActionResult, keine Session/UI. Reden/Fliehen laufen nicht über
## CombatResolver und werden hier (noch) nicht behandelt.


static func describe(actor: CombatParticipant, action: CombatAction, result: CombatActionResult) -> Array[String]:
	var lines: Array[String] = []
	if actor == null or actor.playable == null or action == null or result == null:
		return lines
	if not result.success:
		lines.append("%s: %s" % [actor.playable.get_display_name(), _reason_text(result.failed_reason)])
		return lines
	match action.type:
		CombatAction.ActionType.ITEM:
			lines.append_array(_describe_item(actor, action, result))
		CombatAction.ActionType.ABILITY:
			lines.append_array(_describe_ability(actor, action, result))
		CombatAction.ActionType.MOVE:
			lines.append("%s bewegt sich." % actor.playable.get_display_name())
		_:
			pass
	return lines


static func _describe_item(actor: CombatParticipant, action: CombatAction, result: CombatActionResult) -> Array[String]:
	var verb := action.item_usage_mode.label if action.item_usage_mode else "Angriff"
	var item_name := action.item.item_name if action.item else "einem Gegenstand"
	var means := "%s (%s)" % [item_name, verb]
	var lines: Array[String] = []
	for outcome in result.outcomes:
		lines.append(_describe_outcome(actor, means, outcome))
	return lines


static func _describe_ability(actor: CombatParticipant, action: CombatAction, result: CombatActionResult) -> Array[String]:
	var means := action.ability.ability_name if action.ability else "einer Fähigkeit"
	var lines: Array[String] = []
	for outcome in result.outcomes:
		lines.append(_describe_outcome(actor, means, outcome))
	return lines


static func _describe_outcome(actor: CombatParticipant, means: String, outcome: CombatActionOutcome) -> String:
	var actor_name := actor.playable.get_display_name()
	var target_name := "?"
	if outcome.target and outcome.target.playable:
		target_name = outcome.target.playable.get_display_name()
	if outcome.healed > 0:
		return "%s heilt %s mit %s um %d Punkte" % [actor_name, target_name, means, outcome.healed]
	if outcome.evaded:
		return "%s weicht %s aus (%s)" % [target_name, actor_name, means]
	if outcome.damage > 0:
		var suffix := " – kampfunfähig!" if outcome.defeated else ""
		return "%s trifft %s mit %s – %d Schaden%s" % [actor_name, target_name, means, outcome.damage, suffix]
	return "%s verfehlt %s mit %s" % [actor_name, target_name, means]


static func _reason_text(reason: String) -> String:
	match reason:
		"not_enough_mana":
			return "nicht genug Konzentration."
		"no_line_of_sight":
			return "keine freie Sicht auf das Ziel."
		"effect_not_implemented":
			return "Fähigkeit wirkt (noch) nicht."
		"invalid_item", "invalid_ability", "invalid_actor":
			return "kann das nicht tun."
		_:
			return "Aktion schlägt fehl."
