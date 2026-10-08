extends RefCounted

## Erster migrierter Ablauf. Weitere Quests benötigen eigene definierte Übergänge.
const STATES := ["not_started", "active", "ready", "completed"]

static func from_flags(flags: Dictionary) -> String:
	if flags.get("quest_bandit_done", false) == true:
		return "completed"
	if flags.get("defeated_bandit", false) == true:
		return "ready"
	if flags.get("quest_bandit_started", false) == true:
		return "active"
	return "not_started"


## Kompatibilitätsbrücke für alte Schreiber. Keine Rückwärtsübergänge.
static func reconcile(states: Dictionary, flags: Dictionary) -> void:
	var current: String = states.get("bandit", "not_started")
	var inferred := from_flags(flags)
	if STATES.find(inferred) > STATES.find(current):
		current = inferred
	states["bandit"] = current
	match current:
		"active": flags["quest_bandit_started"] = true
		"ready": flags["defeated_bandit"] = true
		"completed": flags["quest_bandit_done"] = true


static func start(states: Dictionary, flags: Dictionary, id: String) -> bool:
	if id != "bandit":
		return false
	if states.get(id, "not_started") == "completed":
		return false
	flags["quest_bandit_started"] = true
	reconcile(states, flags)
	return true
