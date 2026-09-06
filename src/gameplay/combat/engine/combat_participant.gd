class_name CombatParticipant extends RefCounted

## Ein Kampfteilnehmer innerhalb einer CombatSession. Kein eigener Node –
## playable ist weiterhin die echte Welt-Repräsentation (Player/NPC/PartyFollower),
## das Charakterblatt bleibt playable.character die einzige Stat-Quelle.

var playable: Playable
var side: StringName
var initiative_meter: float = 0.0
var is_defeated: bool = false
## Erfolgreich geflohen (siehe CombatSession.mark_fled) – bleibt wie
## is_defeated Teil von participants (kein Ziel mehr, keine Züge mehr), bis
## die Session endet. So bekommt z.B. ein geflohener Party-Leader seine freie
## Steuerung erst zurück, wenn auch der Rest der eigenen Seite raus ist
## (besiegt oder ebenfalls geflohen) – nicht schon beim eigenen Fluchtversuch.
var has_fled: bool = false


func is_out_of_combat() -> bool:
	return is_defeated or has_fled


func _init(p_playable: Playable = null, p_side: StringName = &"neutral") -> void:
	playable = p_playable
	side = p_side


func get_character() -> CharacterResource:
	return playable.character if playable else null
