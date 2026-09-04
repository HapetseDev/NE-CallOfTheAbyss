class_name CombatOrderHud extends PanelContainer

## Zeigt die Kampf-Zugreihenfolge: aktiver Teilnehmer zuerst, dann wer als
## nächstes bereit ist (turn_queue), dann der Rest nach initiative_meter
## sortiert (Schätzung – die tatsächliche Reihenfolge hängt von der
## Geschwindigkeit ab, die sich laufend ändert). Einträge bleiben pro
## Teilnehmer bestehen (nur neu einsortiert), damit sie nicht bei jedem
## Frame neu erzeugt werden.

const ENTRY_SCENE := preload("res://src/ui/hud/combat_order_entry.tscn")

var _manager: CombatManager
var _session: CombatSession
var _entries: Dictionary = {}  # CombatParticipant -> CombatOrderEntry

@onready var _row: VBoxContainer = %Row


func _ready() -> void:
	visible = false


func bind(manager: CombatManager) -> void:
	_manager = manager
	if _manager == null:
		return
	if not _manager.combat_started.is_connected(_on_combat_started):
		_manager.combat_started.connect(_on_combat_started)
	if not _manager.combat_ended.is_connected(_on_combat_ended):
		_manager.combat_ended.connect(_on_combat_ended)


func _on_combat_started(session: CombatSession) -> void:
	_session = session
	visible = true
	_sync_entries()


func _on_combat_ended(_session: CombatSession, _outcome: Dictionary) -> void:
	_session = null
	visible = false
	_clear_entries()


func _process(_delta: float) -> void:
	if _session == null or not is_instance_valid(_session):
		return
	_sync_entries()


func _sync_entries() -> void:
	var ordered := _ordered_participants()
	for participant in _entries.keys().duplicate():
		if not ordered.has(participant):
			var stale: CombatOrderEntry = _entries[participant]
			if is_instance_valid(stale):
				stale.queue_free()
			_entries.erase(participant)

	var active := _session.get_active_participant()
	for i in ordered.size():
		var participant: CombatParticipant = ordered[i]
		var entry: CombatOrderEntry = _entries.get(participant)
		if entry == null or not is_instance_valid(entry):
			entry = ENTRY_SCENE.instantiate() as CombatOrderEntry
			_row.add_child(entry)
			entry.bind(participant)
			_entries[participant] = entry
		_row.move_child(entry, i)
		entry.refresh(participant == active)


func _ordered_participants() -> Array[CombatParticipant]:
	var result: Array[CombatParticipant] = []
	if _session == null:
		return result
	var active := _session.get_active_participant()
	if active and not active.is_defeated:
		result.append(active)
	for participant in _session.turn_queue:
		if not participant.is_defeated and not result.has(participant):
			result.append(participant)
	var rest: Array[CombatParticipant] = []
	for participant in _session.participants:
		if participant.is_defeated or result.has(participant):
			continue
		rest.append(participant)
	rest.sort_custom(func(a: CombatParticipant, b: CombatParticipant) -> bool:
		return a.initiative_meter > b.initiative_meter)
	result.append_array(rest)
	return result


func _clear_entries() -> void:
	for entry in _entries.values():
		if is_instance_valid(entry):
			entry.queue_free()
	_entries.clear()
