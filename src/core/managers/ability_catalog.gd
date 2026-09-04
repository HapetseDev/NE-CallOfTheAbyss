class_name AbilityCatalog
extends Object

## Datenkatalog für AbilityDefinitions, analog zu SkillCatalog.
## Kein Autoload und kein MainGame-System – lädt alle .tres unter
## src/resources/abilities/definitions/ und bietet sie an, gefiltert
## nach den tatsächlich gelernten Talenten eines Charakters.

const DEFINITIONS_DIR := "res://src/resources/abilities/definitions"

static var _definitions: Dictionary = {}
static var _loaded: bool = false


static func get_definition(ability_id: String) -> AbilityDefinition:
	_ensure_loaded()
	return _definitions.get(ability_id)


static func get_all_definitions() -> Array[AbilityDefinition]:
	_ensure_loaded()
	var result: Array[AbilityDefinition] = []
	for definition in _definitions.values():
		if definition is AbilityDefinition:
			result.append(definition)
	return result


## Fähigkeiten, die character aktuell einsetzen kann – deren Quelltalent
## gelernt und mindestens auf dem geforderten Level ist.
static func get_available_for(character: CharacterResource) -> Array[AbilityDefinition]:
	_ensure_loaded()
	var result: Array[AbilityDefinition] = []
	if character == null:
		return result
	for definition in get_all_definitions():
		if definition.source_skill_id.is_empty():
			result.append(definition)
			continue
		if character.get_skill_level(definition.source_skill_id) >= definition.min_skill_level:
			result.append(definition)
	return result


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(DEFINITIONS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var definition := load("%s/%s" % [DEFINITIONS_DIR, file_name]) as AbilityDefinition
			if definition and not definition.ability_id.is_empty():
				_definitions[definition.ability_id] = definition
		file_name = dir.get_next()
	dir.list_dir_end()
