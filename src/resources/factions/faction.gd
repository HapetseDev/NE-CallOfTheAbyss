class_name Faction extends Resource

## Gruppen-Identität für Beziehungen (RelationshipEntry.target_type == FACTION).
## Charaktere treten Fraktionen über CharacterResource.faction_ids bei (mehrere möglich).

@export var faction_id: String = ""
@export var faction_name: String = ""
@export_multiline var description: String = ""
