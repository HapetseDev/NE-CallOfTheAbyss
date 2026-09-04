class_name CombatActionOutcome extends RefCounted

## Pro-Ziel-Ergebnis einer aufgelösten CombatAction, für Anzeige-/Log-Zwecke
## (siehe CombatNarrator). CombatResolver befüllt das beim Auflösen, damit
## der tatsächliche Schadenswert nicht mehr verworfen wird.

var target: CombatParticipant
var damage: int = 0
var healed: int = 0
var evaded: bool = false
var defeated: bool = false
