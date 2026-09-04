class_name CombatParticipant extends RefCounted

## Ein Kampfteilnehmer innerhalb einer CombatSession. Kein eigener Node –
## playable ist weiterhin die echte Welt-Repräsentation (Player/NPC/PartyFollower),
## das Charakterblatt bleibt playable.character die einzige Stat-Quelle.

var playable: Playable
var side: StringName
var initiative_meter: float = 0.0
var is_defeated: bool = false


func _init(p_playable: Playable = null, p_side: StringName = &"neutral") -> void:
	playable = p_playable
	side = p_side


func get_character() -> CharacterResource:
	return playable.character if playable else null
