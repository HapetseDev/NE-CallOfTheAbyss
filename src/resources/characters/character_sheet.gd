class_name CharacterResource
extends Resource

## Charakterdaten unabhängig vom Node. Player, NPC und Begleiter
## sind nur Repräsentanten dieser Resource in der Welt.

signal staerkepunkte_changed(current: int, basis: int)
signal konzentrationspunkte_changed(current: int, basis: int)
signal sheet_changed
signal inventory_changed

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

@export_group("Besitz")
@export var gold: int = 0
@export var inventory: Inventory


func ensure_initialized() -> void:
	_ensure_inventory()
	if staerkepunkte == 0 and konzentrationspunkte == 0:
		staerkepunkte = get_staerkepunkte_basis()
		konzentrationspunkte = get_konzentrationspunkte_basis()


func _ensure_inventory() -> void:
	if inventory == null:
		inventory = Inventory.new()
	inventory.ensure_equipment_slots()
	if not inventory.contents_changed.is_connected(_on_inventory_changed):
		inventory.contents_changed.connect(_on_inventory_changed)


func ensure_equipment_slots() -> void:
	_ensure_inventory()


func _on_inventory_changed() -> void:
	inventory_changed.emit()
	sheet_changed.emit()


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
	var base := get_base_attribute(attr)
	var from_skills := _get_skill_bonus_for_attribute(attr)
	return maxi(0, base + from_skills)


func get_base_attribute(attr: CharacterEnums.Attribute) -> int:
	return _get_base_attribute(attr)


func get_skill_level(skill_id: String) -> int:
	var learned := _find_learned_skill(skill_id)
	return learned.level if learned else 0


func get_learned_skills_for_attribute(attr: CharacterEnums.Attribute) -> Array[LearnedSkill]:
	var result: Array[LearnedSkill] = []
	for learned in learned_skills:
		if learned == null:
			continue
		var definition: SkillDefinition = SkillCatalog.get_definition(learned.skill_id)
		if definition and definition.attribute == attr:
			result.append(learned)
	result.sort_custom(_sort_learned_by_name)
	return result


func get_attribute_skill_slots(attr: CharacterEnums.Attribute) -> Array:
	var learned := get_learned_skills_for_attribute(attr)
	var slots: Array = []
	for i in CharacterEnums.FAEHIGKEITEN_PRO_ATTRIBUT:
		if i < learned.size():
			var entry := learned[i]
			var definition: SkillDefinition = SkillCatalog.get_definition(entry.skill_id)
			slots.append({
				"skill_id": entry.skill_id,
				"skill_name": definition.skill_name if definition else entry.skill_id,
				"level": entry.level,
			})
		else:
			slots.append(null)
	return slots


func get_available_talents_for_attribute(attr: CharacterEnums.Attribute) -> Array[SkillDefinition]:
	return SkillCatalog.get_talent_catalog_for_attribute(attr)


func get_attribute_sections() -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	for attr in CharacterEnums.ALL_ATTRIBUTES:
		sections.append({
			"attribute": attr,
			"attribute_name": CharacterEnums.attribute_name(attr),
			"attribute_value": get_effective_attribute(attr),
			"influence": CharacterEnums.attribute_influence(attr),
			"skill_slots": get_attribute_skill_slots(attr),
			"available_talents": get_available_talents_for_attribute(attr),
		})
	return sections


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


func add_item(item: ItemData, count: int = 1) -> void:
	_ensure_inventory()
	inventory.add_item(item, count)


func remove_item(item: ItemData, count: int = 1) -> bool:
	_ensure_inventory()
	return inventory.remove_item(item, count)


func has_item(item_id: String) -> bool:
	_ensure_inventory()
	return inventory.has_item(item_id)


func equip(slot_key: String, item: ItemData) -> void:
	_ensure_inventory()
	inventory.equip(slot_key, item)


func unequip(slot_key: String) -> ItemData:
	_ensure_inventory()
	return inventory.unequip(slot_key)


func debug_set_base_attribute(attr: CharacterEnums.Attribute, value: int) -> void:
	value = maxi(0, value)
	match attr:
		CharacterEnums.Attribute.KOERPERKRAFT: koerperkraft = value
		CharacterEnums.Attribute.GEWANDHEIT: gewandheit = value
		CharacterEnums.Attribute.ROBUSTHEIT: robustheit = value
		CharacterEnums.Attribute.WILLENSKRAFT: willenskraft = value
		CharacterEnums.Attribute.VERSTAND: verstand = value
		CharacterEnums.Attribute.BEWUSSTSEIN: bewusstsein = value
		CharacterEnums.Attribute.PRAESENZ: praesenz = value
	sheet_changed.emit()


func debug_set_skill_level(skill_id: String, level: int) -> void:
	if skill_id.is_empty():
		return
	var cap := get_skill_level_cap(skill_id)
	level = clampi(level, 0, cap)
	if level <= 0:
		debug_remove_skill(skill_id)
		return
	var learned := learn_or_get_skill(skill_id)
	learned.level = level
	learned.xp = 0
	sheet_changed.emit()


func debug_remove_skill(skill_id: String) -> void:
	var learned := _find_learned_skill(skill_id)
	if learned == null:
		return
	learned_skills.erase(learned)
	active_training_skill_ids.erase(skill_id)
	sheet_changed.emit()


func debug_add_skill(skill_id: String, level: int = 1) -> bool:
	if skill_id.is_empty():
		return false
	var definition: SkillDefinition = SkillCatalog.get_definition(skill_id)
	if definition == null:
		return false
	if _find_learned_skill(skill_id):
		debug_set_skill_level(skill_id, level)
		return true
	var learned_count := get_learned_skills_for_attribute(definition.attribute).size()
	if learned_count >= CharacterEnums.FAEHIGKEITEN_PRO_ATTRIBUT:
		return false
	debug_set_skill_level(skill_id, level)
	return true


func get_unlearned_talents_for_attribute(attr: CharacterEnums.Attribute) -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for definition in get_available_talents_for_attribute(attr):
		if get_skill_level(definition.skill_id) <= 0:
			result.append(definition)
	return result


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
		var definition: SkillDefinition = SkillCatalog.get_definition(learned.skill_id)
		if definition and definition.attribute == attr:
			total += learned.level
	return total


func _find_learned_skill(skill_id: String) -> LearnedSkill:
	for learned in learned_skills:
		if learned and learned.skill_id == skill_id:
			return learned
	return null


func _sort_learned_by_name(a: LearnedSkill, b: LearnedSkill) -> bool:
	var def_a: SkillDefinition = SkillCatalog.get_definition(a.skill_id)
	var def_b: SkillDefinition = SkillCatalog.get_definition(b.skill_id)
	var name_a: String = def_a.skill_name if def_a else a.skill_id
	var name_b: String = def_b.skill_name if def_b else b.skill_id
	return name_a.nocasecmp_to(name_b) < 0
