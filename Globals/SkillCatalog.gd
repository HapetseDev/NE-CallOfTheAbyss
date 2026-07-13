extends Node

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
	return result


func _load_definitions() -> void:
	var dir := DirAccess.open("res://Ressources/Character/skills")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var definition := load("res://Ressources/Character/skills/%s" % file_name) as SkillDefinition
			if definition and not definition.skill_id.is_empty():
				_definitions[definition.skill_id] = definition
		file_name = dir.get_next()
	dir.list_dir_end()
