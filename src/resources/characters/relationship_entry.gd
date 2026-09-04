class_name RelationshipEntry extends Resource

## Eine gerichtete Beziehung: "Ich" (Inhaber dieses Eintrags) empfinde `wertung`
## gegenüber `target_id`. Nicht zwangsläufig symmetrisch – die Gegenseite hat
## ihren eigenen, unabhängigen Eintrag. Siehe RelationshipService für Abfragen.

enum TargetType { CHARACTER, FACTION }

@export var target_type: TargetType = TargetType.CHARACTER
## character_id (TargetType.CHARACTER) oder faction_id (TargetType.FACTION).
@export var target_id: String = ""
@export_range(CharacterEnums.BEZIEHUNG_MIN, CharacterEnums.BEZIEHUNG_MAX, 1) var wertung: int = 0
@export_multiline var details: String = ""
