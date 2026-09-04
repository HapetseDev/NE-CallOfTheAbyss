class_name CharacterSheetFactory

## Lädt CharacterResources aus src/resources/characters/sheets/{character_id}.tres
## oder erzeugt einen minimalen Standarddatensatz.

const SHEETS_DIR := "res://src/resources/characters/sheets/"

static var _generated_id_counter: int = 0


static func load_sheet(character_id: String) -> CharacterResource:
	if character_id.is_empty():
		return null
	var path := SHEETS_DIR + character_id + ".tres"
	if ResourceLoader.exists(path):
		var data := load(path) as CharacterResource
		if data and data.character_id.is_empty():
			data.character_id = character_id
		return data
	return null


static func create_default(character_name: String, overrides: Dictionary = {}) -> CharacterResource:
	var data := CharacterResource.new()
	data.character_id = str(overrides.get("character_id", _generate_character_id(character_name)))
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
	if overrides.has("faction_ids"):
		data.faction_ids = overrides["faction_ids"]
	data.ensure_initialized()
	return data


static func resolve_sheet(
	character_id: String,
	character_name: String,
	existing: CharacterResource = null
) -> CharacterResource:
	if existing != null:
		if existing.character_id.is_empty():
			existing.character_id = character_id if not character_id.is_empty() else _generate_character_id(character_name)
		return existing
	if not character_id.is_empty():
		var loaded := load_sheet(character_id)
		if loaded != null:
			return loaded
	if not character_name.is_empty():
		return create_default(character_name, {"character_id": character_id} if not character_id.is_empty() else {})
	return null


static func duplicate_for_runtime(data: CharacterResource) -> CharacterResource:
	if data == null:
		return null
	if data.resource_local_to_scene:
		return data
	return data.duplicate(true) as CharacterResource


static func _generate_character_id(character_name: String) -> String:
	_generated_id_counter += 1
	var slug := character_name.to_snake_case() if not character_name.is_empty() else "charakter"
	return "gen_%s_%d" % [slug, _generated_id_counter]
