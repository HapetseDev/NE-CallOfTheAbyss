class_name CharacterSheetCalculator

## Stärkepunkte-Basis: Körperkraft + Gewandheit + Robustheit×2
## (Im Charakterbogen steht „Gewandheit“ doppelt; Robustheit ist laut Attributliste ×2.)
## Konzentrationspunkte-Basis: Verstand + Willenskraft + Bewusstsein×2


static func apply_xp_to_skill(sheet: CharacterSheet, skill_id: String, amount: int) -> int:
	if sheet == null or skill_id.is_empty() or amount <= 0:
		return 0
	var learned := sheet.learn_or_get_skill(skill_id)
	var cap := sheet.get_skill_level_cap(skill_id)
	var remaining := amount
	while remaining > 0 and learned.level < cap:
		var needed := CharacterEnums.XP_PRO_FAEHIGKEITSLEVEL - learned.xp
		if needed <= 0:
			needed = CharacterEnums.XP_PRO_FAEHIGKEITSLEVEL
		if remaining < needed:
			learned.xp += remaining
			return 0
		remaining -= needed
		learned.xp = 0
		learned.level += 1
		_on_skill_level_up(sheet)
	return remaining


static func _on_skill_level_up(sheet: CharacterSheet) -> void:
	var basis_sp := sheet.get_staerkepunkte_basis()
	var basis_kp := sheet.get_konzentrationspunkte_basis()
	if sheet.staerkepunkte > 0:
		sheet.staerkepunkte = mini(sheet.staerkepunkte + 1, basis_sp)
	if sheet.konzentrationspunkte > 0:
		sheet.konzentrationspunkte = mini(sheet.konzentrationspunkte + 1, basis_kp)


static func beziehung_bedeutung(wertung: int) -> String:
	if wertung >= 10:
		return "Liebe / absolute Loyalität"
	if wertung >= 5:
		return "Wohlgesonnen"
	if wertung <= -10:
		return "Feindselig"
	if wertung <= -5:
		return "Misstrauisch"
	return "Neutral"
