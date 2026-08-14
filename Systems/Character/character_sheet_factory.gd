class_name CharacterSheetFactory

## Lädt Charakterbögen aus Resources/Character/sheets/{character_id}.tres
## oder erzeugt einen minimalen Standardbogen.

const SHEETS_DIR := "res://Resources/Character/sheets/"


static func load_sheet(character_id: String) -> CharacterSheet:
	if character_id.is_empty():
		return null
	var path := SHEETS_DIR + character_id + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as CharacterSheet
	return null


static func create_default(character_name: String, overrides: Dictionary = {}) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.character_name = character_name
	sheet.koerperkraft = int(overrides.get("koerperkraft", 2))
	sheet.gewandheit = int(overrides.get("gewandheit", 2))
	sheet.robustheit = int(overrides.get("robustheit", 2))
	sheet.willenskraft = int(overrides.get("willenskraft", 2))
	sheet.verstand = int(overrides.get("verstand", 2))
	sheet.bewusstsein = int(overrides.get("bewusstsein", 2))
	sheet.praesenz = int(overrides.get("praesenz", 2))
	if overrides.has("ziel"):
		sheet.ziel = str(overrides["ziel"])
	if overrides.has("learned_skills"):
		sheet.learned_skills = overrides["learned_skills"]
	if overrides.has("active_training_skill_ids"):
		sheet.active_training_skill_ids = overrides["active_training_skill_ids"]
	sheet.ensure_initialized()
	return sheet


static func resolve_sheet(
	character_id: String,
	character_name: String,
	existing: CharacterSheet = null
) -> CharacterSheet:
	if existing != null:
		return existing
	if not character_id.is_empty():
		var loaded := load_sheet(character_id)
		if loaded != null:
			return loaded
	if not character_name.is_empty():
		return create_default(character_name)
	return null


static func duplicate_for_runtime(sheet: CharacterSheet) -> CharacterSheet:
	if sheet == null:
		return null
	if sheet.resource_local_to_scene:
		return sheet
	return sheet.duplicate(true) as CharacterSheet
