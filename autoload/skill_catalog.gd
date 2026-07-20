extends Node

const _TALENT_CATALOG := preload("res://Ressources/Character/attribute_talent_catalog.gd")

var _definitions: Dictionary = {}


func _ready() -> void:
	_load_definitions()


func get_definition(skill_id: String) -> SkillDefinition:
	return _definitions.get(skill_id)


func get_all_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for definition in _definitions.values():
		if definition is SkillDefinition:
			result.append(definition)
	return result


func get_definitions_for_attribute(attr: CharacterEnums.Attribute) -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for definition in _definitions.values():
		if definition is SkillDefinition and definition.attribute == attr:
			result.append(definition)
	result.sort_custom(_sort_definitions_by_name)
	return result


func get_talent_catalog_for_attribute(attr: CharacterEnums.Attribute) -> Array[SkillDefinition]:
	return get_definitions_for_attribute(attr)


func _sort_definitions_by_name(a: SkillDefinition, b: SkillDefinition) -> bool:
	return a.skill_name.nocasecmp_to(b.skill_name) < 0


func _load_definitions() -> void:
_load_skill_resources()
	_load_attribute_talent_catalog()

func _load_skill_resources() -> void:
	var dir := DirAccess.open("res://Resources/Character/skills")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var definition := load("res://Resources/Character/skills/%s" % file_name) as SkillDefinition
			if definition and not definition.skill_id.is_empty():
				_definitions[definition.skill_id] = definition
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_attribute_talent_catalog() -> void:
	for entry in _TALENT_CATALOG.ENTRIES:
		var skill_id: String = entry.get("skill_id", "")
		if skill_id.is_empty() or _definitions.has(skill_id):
			continue
		_definitions[skill_id] = _TALENT_CATALOG.create_definition(entry)
