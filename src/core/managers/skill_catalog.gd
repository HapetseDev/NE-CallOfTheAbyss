class_name SkillCatalog
extends Object

## Datenkatalog, kein Autoload und kein MainGame-System.
## CharacterResources können Definitionen laden, ohne dass eine Szene lebt.

const _TALENT_CATALOG := preload("res://src/resources/characters/attribute_talent_catalog.gd")

static var _definitions: Dictionary = {}
static var _loaded: bool = false


static func get_definition(skill_id: String) -> SkillDefinition:
	_ensure_loaded()
	return _definitions.get(skill_id)


static func get_all_definitions() -> Array[SkillDefinition]:
	_ensure_loaded()
	var result: Array[SkillDefinition] = []
	for definition in _definitions.values():
		if definition is SkillDefinition:
			result.append(definition)
	return result


static func get_definitions_for_attribute(attr: CharacterEnums.Attribute) -> Array[SkillDefinition]:
	_ensure_loaded()
	var result: Array[SkillDefinition] = []
	for definition in _definitions.values():
		if definition is SkillDefinition and definition.attribute == attr:
			result.append(definition)
	result.sort_custom(_sort_definitions_by_name)
	return result


static func get_talent_catalog_for_attribute(attr: CharacterEnums.Attribute) -> Array[SkillDefinition]:
	return get_definitions_for_attribute(attr)


static func _sort_definitions_by_name(a: SkillDefinition, b: SkillDefinition) -> bool:
	return a.skill_name.nocasecmp_to(b.skill_name) < 0


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_skill_resources()
	_load_attribute_talent_catalog()


static func _load_skill_resources() -> void:
	var dir := DirAccess.open("res://src/resources/characters/skills")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var definition := load("res://src/resources/characters/skills/%s" % file_name) as SkillDefinition
			if definition and not definition.skill_id.is_empty():
				_definitions[definition.skill_id] = definition
		file_name = dir.get_next()
	dir.list_dir_end()


static func _load_attribute_talent_catalog() -> void:
	for entry in _TALENT_CATALOG.ENTRIES:
		var skill_id: String = entry.get("skill_id", "")
		if skill_id.is_empty() or _definitions.has(skill_id):
			continue
		_definitions[skill_id] = _TALENT_CATALOG.create_definition(entry)
