class_name RelationshipService

## Zentrale Abfrage-API für Beziehungen (CharacterResource.beziehungen).
## Beziehungen sind gerichtet: get_disposition(A, B) und get_disposition(B, A)
## werden unabhängig aus den jeweils eigenen beziehungen-Arrays gelesen.
##
## Vorrangregel: ein Individual-Eintrag (target_type == CHARACTER, target_id ==
## target.character_id) schlägt immer Fraktions-Einträge. Ohne Individual-Eintrag
## gewinnt unter den passenden Fraktions-Einträgen der betragsmäßig stärkste Wert
## (ein einzelner starker Hass-Eintrag soll nicht durch einen schwachen
## Sympathie-Eintrag neutralisiert werden). Kein passender Eintrag -> 0 (neutral).

const ALLY_THRESHOLD_DEFAULT := 1
const HOSTILE_THRESHOLD_DEFAULT := -1


static func get_disposition(observer: CharacterResource, target: CharacterResource) -> int:
	if observer == null or target == null:
		return 0
	if observer == target:
		return CharacterEnums.BEZIEHUNG_MAX
	if target.character_id.is_empty():
		return _strongest_faction_value(observer, target)

	for entry in observer.beziehungen:
		if entry == null:
			continue
		if entry.target_type == RelationshipEntry.TargetType.CHARACTER \
				and entry.target_id == target.character_id:
			return clampi(entry.wertung, CharacterEnums.BEZIEHUNG_MIN, CharacterEnums.BEZIEHUNG_MAX)

	return _strongest_faction_value(observer, target)


static func is_ally(observer: CharacterResource, target: CharacterResource, threshold: int = ALLY_THRESHOLD_DEFAULT) -> bool:
	return get_disposition(observer, target) >= threshold


static func is_hostile(observer: CharacterResource, target: CharacterResource, threshold: int = HOSTILE_THRESHOLD_DEFAULT) -> bool:
	return get_disposition(observer, target) <= threshold


static func _strongest_faction_value(observer: CharacterResource, target: CharacterResource) -> int:
	if target.faction_ids.is_empty():
		return 0
	var strongest := 0
	var strongest_abs := -1
	for entry in observer.beziehungen:
		if entry == null:
			continue
		if entry.target_type != RelationshipEntry.TargetType.FACTION:
			continue
		if not target.faction_ids.has(entry.target_id):
			continue
		var value := clampi(entry.wertung, CharacterEnums.BEZIEHUNG_MIN, CharacterEnums.BEZIEHUNG_MAX)
		if absi(value) > strongest_abs:
			strongest_abs = absi(value)
			strongest = value
	return strongest


## Persönliche Änderung auf Basis der wirksamen Beziehung (inkl. Fraktionsfallback).
## Die Gegenrichtung bleibt unverändert. Der Aufrufer stellt eine Arbeitskopie bereit.
static func change_disposition(observer: CharacterResource, target: CharacterResource, amount: int) -> bool:
	if observer == null or target == null or observer.character_id == target.character_id or target.character_id.is_empty():
		return false
	if amount < -2147483647 or amount > 2147483647:
		return false
	if amount == 0:
		return true
	var value := clampi(get_disposition(observer, target) + amount, CharacterEnums.BEZIEHUNG_MIN, CharacterEnums.BEZIEHUNG_MAX)
	for entry in observer.beziehungen:
		if entry and entry.target_type == RelationshipEntry.TargetType.CHARACTER and entry.target_id == target.character_id:
			entry.wertung = value
			return true
	var entry := RelationshipEntry.new()
	entry.target_id = target.character_id
	entry.wertung = value
	observer.beziehungen.append(entry)
	return true
