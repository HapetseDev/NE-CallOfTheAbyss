class_name CharacterSheet extends Resource

signal staerkepunkte_changed(current: int, basis: int)
signal konzentrationspunkte_changed(current: int, basis: int)
signal sheet_changed

@export var character_name: String = ""
@export var ausbildung: CharacterEnums.Ausbildung = CharacterEnums.Ausbildung.KEINE
@export var spezies: CharacterEnums.Spezies = CharacterEnums.Spezies.MENSCH
@export var herkunft: CharacterEnums.Herkunft = CharacterEnums.Herkunft.KEINE
@export var ziel: String = ""
@export var besonderheiten: Array[CharacterEnums.Besonderheit] = []

@export_group("Attribute (Basis)")
@export var koerperkraft: int = 1
@export var gewandheit: int = 1
@export var robustheit: int = 1
@export var willenskraft: int = 1
@export var verstand: int = 1
@export var bewusstsein: int = 1
@export var praesenz: int = 1

@export_group("Punkte")
@export var staerkepunkte: int = 0
@export var konzentrationspunkte: int = 0

@export_group("Fähigkeiten")
@export var learned_skills: Array[LearnedSkill] = []
@export var active_training_skill_ids: Array[String] = []
@export var erfahrungspunkte: int = 0
@export var skill_level_cap_bonus: int = 0

@export_group("Soziales")
@export var begleiter: Array[CompanionEntry] = []
@export var beziehungen: Array[RelationshipEntry] = []


func ensure_initialized() -> void:
	if staerkepunkte == 0 and konzentrationspunkte == 0:
		staerkepunkte = get_staerkepunkte_basis()
		konzentrationspunkte = get_konzentrationspunkte_basis()


func get_staerkepunkte_basis() -> int:
	var kk := get_effective_attribute(CharacterEnums.Attribute.KOERPERKRAFT)
	var gw := get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)
	var rb := get_effective_attribute(CharacterEnums.Attribute.ROBUSTHEIT)
	return kk + gw + rb * 2


func get_konzentrationspunkte_basis() -> int:
	var vs := get_effective_attribute(CharacterEnums.Attribute.VERSTAND)
	var wk := get_effective_attribute(CharacterEnums.Attribute.WILLENSKRAFT)
	var bw := get_effective_attribute(CharacterEnums.Attribute.BEWUSSTSEIN)
	return vs + wk + bw * 2


func get_effective_attribute(attr: CharacterEnums.Attribute) -> int:
	var base := _get_base_attribute(attr)
	var from_skills := _get_skill_bonus_for_attribute(attr)
	return maxi(0, base + from_skills)


func get_skill_level(skill_id: String) -> int:
	var learned := _find_learned_skill(skill_id)
	return learned.level if learned else 0


func get_skill_level_cap(_skill_id: String = "") -> int:
	return CharacterEnums.STANDARD_FAEHIGKEITS_CAP + skill_level_cap_bonus


func is_dead() -> bool:
	return staerkepunkte <= -get_staerkepunkte_basis()


func can_use_konzentration(cost: int) -> bool:
	if is_konzentration_exhausted():
		return false
	return konzentrationspunkte >= cost


func is_konzentration_exhausted() -> bool:
	return konzentrationspunkte <= -get_konzentrationspunkte_basis()


func apply_staerkeschaden(amount: int) -> void:
	staerkepunkte -= amount
	staerkepunkte_changed.emit(staerkepunkte, get_staerkepunkte_basis())
	sheet_changed.emit()


func heal_staerke(amount: int) -> void:
	staerkepunkte += amount
	staerkepunkte_changed.emit(staerkepunkte, get_staerkepunkte_basis())
	sheet_changed.emit()


func spend_konzentration(amount: int) -> bool:
	if not can_use_konzentration(amount):
		return false
	konzentrationspunkte -= amount
	konzentrationspunkte_changed.emit(konzentrationspunkte, get_konzentrationspunkte_basis())
	sheet_changed.emit()
	return true


func restore_konzentration(amount: int) -> void:
	konzentrationspunkte += amount
	konzentrationspunkte_changed.emit(konzentrationspunkte, get_konzentrationspunkte_basis())
	sheet_changed.emit()


func learn_or_get_skill(skill_id: String) -> LearnedSkill:
	var learned := _find_learned_skill(skill_id)
	if learned:
		return learned
	learned = LearnedSkill.new()
	learned.skill_id = skill_id
	learned_skills.append(learned)
	sheet_changed.emit()
	return learned


func set_active_training(skill_id: String, active: bool) -> bool:
	if active:
		if active_training_skill_ids.has(skill_id):
			return true
		if active_training_skill_ids.size() >= CharacterEnums.MAX_AKTIVES_TRAINING:
			return false
		active_training_skill_ids.append(skill_id)
	else:
		active_training_skill_ids.erase(skill_id)
	sheet_changed.emit()
	return true


func allocate_erfahrung(skill_id: String, amount: int) -> int:
	if amount <= 0 or erfahrungspunkte <= 0:
		return 0
	var spent := mini(amount, erfahrungspunkte)
	if not CharacterSheetCalculator.apply_xp_to_skill(self, skill_id, spent):
		return 0
	erfahrungspunkte -= spent
	sheet_changed.emit()
	return spent


func gain_action_erfahrung(skill_id: String, amount: int) -> void:
	if amount <= 0 or not active_training_skill_ids.has(skill_id):
		return
	var overflow := CharacterSheetCalculator.apply_xp_to_skill(self, skill_id, amount)
	if overflow > 0:
		erfahrungspunkte += overflow
	sheet_changed.emit()


func add_beziehung(entry: RelationshipEntry) -> void:
	beziehungen.append(entry)
	sheet_changed.emit()


func add_begleiter(entry: CompanionEntry) -> void:
	begleiter.append(entry)
	sheet_changed.emit()


func _get_base_attribute(attr: CharacterEnums.Attribute) -> int:
	match attr:
		CharacterEnums.Attribute.KOERPERKRAFT: return koerperkraft
		CharacterEnums.Attribute.GEWANDHEIT: return gewandheit
		CharacterEnums.Attribute.ROBUSTHEIT: return robustheit
		CharacterEnums.Attribute.WILLENSKRAFT: return willenskraft
		CharacterEnums.Attribute.VERSTAND: return verstand
		CharacterEnums.Attribute.BEWUSSTSEIN: return bewusstsein
		CharacterEnums.Attribute.PRAESENZ: return praesenz
		_: return 0


func _get_skill_bonus_for_attribute(attr: CharacterEnums.Attribute) -> int:
	var total := 0
	for learned in learned_skills:
		if learned == null:
			continue
		var definition := SkillCatalog.get_definition(learned.skill_id)
		if definition and definition.attribute == attr:
			total += learned.level
	return total


func _find_learned_skill(skill_id: String) -> LearnedSkill:
	for learned in learned_skills:
		if learned and learned.skill_id == skill_id:
			return learned
	return null
