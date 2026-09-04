class_name EncounterData extends Resource

## Belohnungs-Metadaten für einen Kampf. Die Gegner-Zusammensetzung kommt
## nicht mehr von hier – CombatParticipantResolver ermittelt Teilnehmer
## dynamisch über Beziehungen. Verknüpfung zu einem konkreten Kampf/Sieg
## ist noch offen (siehe Plan, "Offene Punkte" zu Encounter-Belohnungen).
@export var encounter_id: String = ""
@export var reward_gold: int = 0
@export var reward_items: Array[ItemData] = []
@export var reward_item_counts: Array[int] = []
