class_name CharacterSheetFactory

## Lädt CharacterResources aus src/resources/characters/sheets/{character_id}.tres
## oder erzeugt einen minimalen Standarddatensatz.

const SHEETS_DIR := "res://src/resources/characters/sheets/"


static func load_sheet(character_id: String) -> CharacterResource:
	if character_id.is_empty():
		return null
	var path := SHEETS_DIR + character_id + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as CharacterResource
	return null


static func create_default(character_name: String, overrides: Dictionary = {}) -> CharacterResource:
	var data := CharacterResource.new()
	data.character_name = character_name
	data.koerperkraft = int(overrides.get("koerperkraft", 2))
	data.gewandheit = int(overrides.get("gewandheit", 2))
	data.robustheit = int(overrides.get("robustheit", 2))
	data.willenskraft = int(overrides.get("willenskraft", 2))
	data.verstand = int(overrides.get("verstand", 2))
	data.bewusstsein = int(overrides.get("bewusstsein", 2))
	data.praesenz = int(overrides.get("praesenz", 2))
	data.gold = int(overrides.get("gold", 0))
	if overrides.has("ziel"):
		data.ziel = str(overrides["ziel"])
	if overrides.has("learned_skills"):
		data.learned_skills = overrides["learned_skills"]
	if overrides.has("active_training_skill_ids"):
		data.active_training_skill_ids = overrides["active_training_skill_ids"]
	data.ensure_initialized()
	return data


static func resolve_sheet(
	character_id: String,
	character_name: String,
	existing: CharacterResource = null
) -> CharacterResource:
	if existing != null:
		return existing
	if not character_id.is_empty():
		var loaded := load_sheet(character_id)
		if loaded != null:
			return loaded
	if not character_name.is_empty():
		return create_default(character_name)
	return null


static func duplicate_for_runtime(data: CharacterResource) -> CharacterResource:
	if data == null:
		return null
	if data.resource_local_to_scene:
		return data
	return data.duplicate(true) as CharacterResource
