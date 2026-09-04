class_name CombatActionResult extends RefCounted

var success: bool = true
var failed_reason: String = ""
## Ziele, die durch diese Aktion kampfunfähig wurden (playable.is_character_dead()).
## Der Aufrufer entscheidet, ob/wie CombatSession.mark_defeated() darauf reagiert.
var defeated_targets: Array[CombatParticipant] = []
