class_name CombatActionResult extends RefCounted

var success: bool = true
var failed_reason: String = ""
## Ziele, die durch diese Aktion kampfunfähig wurden (playable.is_character_dead()).
## Der Aufrufer entscheidet, ob/wie CombatSession.mark_defeated() darauf reagiert.
var defeated_targets: Array[CombatParticipant] = []
## Pro-Ziel-Details (Schaden/Heilung/Ausweichen) für Anzeige-Zwecke, siehe
## CombatActionOutcome/CombatNarrator.
var outcomes: Array[CombatActionOutcome] = []
