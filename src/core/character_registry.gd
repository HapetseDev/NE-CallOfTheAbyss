class_name CharacterRegistry
extends RefCounted

## Besitzt genau einen Laufzeitdatensatz pro stabiler Charakter-ID.
## Vorlagen bleiben unverändert; Welt-Nodes halten nur Referenzen auf die
## registrierten Daten. NPCs können über use_character_registry angebunden werden.
## IDs sind nach Registrierung unveränderlich. Leere Vorlagen-IDs erlauben
## mehrere Instanzen einer Vorlage, jeweils unter einer eigenen stabilen ID.

signal registration_rejected(character_id: String, reason: StringName)

var _characters: Dictionary[String, CharacterResource] = {}
var _templates: Dictionary[String, CharacterResource] = {}


func get_character(character_id: String) -> CharacterResource:
	return _characters.get(character_id)


func get_registered_ids() -> Array:
	return _characters.keys()


func get_template(character_id: String) -> CharacterResource:
	return _templates.get(character_id)


## Nur für einen separaten, validierten Ladekandidaten. Punkte bleiben exakt
## erhalten; ensure_initialized() würde gespeicherte 0/0-Werte überschreiben.
func restore_character(id: String, template: CharacterResource, data: CharacterResource) -> bool:
	if template == null or data == null or id.is_empty() or id != id.strip_edges() or _characters.has(id) or data.character_id != id or template.character_id != id:
		return false
	data.ensure_equipment_slots()
	_characters[id] = data
	_templates[id] = template
	return true


## Gleiche ID + gleiche Vorlage ist idempotent. Eine andere Vorlage darf
## vorhandenen Laufzeitzustand niemals stillschweigend überschreiben.
## Fehler: null und registration_rejected mit maschinenlesbarer Ursache.
func register_character(character_id: String, template: CharacterResource) -> CharacterResource:
	if character_id.is_empty() or character_id != character_id.strip_edges():
		return _reject(character_id, &"invalid_id")
	if template == null:
		return _reject(character_id, &"missing_template")
	if not template.character_id.is_empty() and template.character_id != character_id:
		return _reject(character_id, &"template_id_mismatch")
	if _characters.has(character_id):
		if _templates[character_id] != template:
			return _reject(character_id, &"conflicting_template")
		return _characters[character_id]

	# Auch externe und in Arrays/Dictionarys eingebettete Resources kopieren.
	# resource_local_to_scene ist kein Grund, eine Vorlage direkt zu verwenden.
	var character := template.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CharacterResource
	if character == null:
		return _reject(character_id, &"copy_failed")
	character.character_id = character_id
	# Nur beim erstmaligen Erzeugen initialisieren, nie beim erneuten Abruf.
	character.ensure_initialized()
	_characters[character_id] = character
	_templates[character_id] = template
	return character


## Nur an einer Sitzungsgrenze aufrufen, nachdem Welt-Nodes abgebaut wurden.
## Externe Referenzen auf alte Daten werden dadurch nicht verändert.
func clear() -> void:
	_characters.clear()
	_templates.clear()


func _reject(character_id: String, reason: StringName) -> CharacterResource:
	registration_rejected.emit(character_id, reason)
	return null
