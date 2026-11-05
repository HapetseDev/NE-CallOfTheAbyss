class_name CombatOrderHud extends Control

const ENTRY_SCENE := preload("res://src/ui/hud/combat_order_entry.tscn")
var _manager: CombatManager
var _session: CombatSession
var _party_hud: PartyHud
var _entries: Dictionary = {}
var _departing: Dictionary = {}
@onready var _row: Control = %Row

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(manager: CombatManager, party_hud: PartyHud = null) -> void:
	_disconnect_manager()
	_manager = manager
	_party_hud = party_hud
	if is_instance_valid(_manager):
		_manager.combat_started.connect(_on_combat_started)
		_manager.combat_ended.connect(_on_combat_ended)
		if _manager.active_session:
			_on_combat_started(_manager.active_session)

func _disconnect_manager() -> void:
	if is_instance_valid(_manager):
		if _manager.combat_started.is_connected(_on_combat_started):
			_manager.combat_started.disconnect(_on_combat_started)
		if _manager.combat_ended.is_connected(_on_combat_ended):
			_manager.combat_ended.disconnect(_on_combat_ended)

func _disconnect_session() -> void:
	if not is_instance_valid(_session):
		return
	for event in [_session.participant_joined, _session.participant_fled, _session.participant_defeated, _session.turn_started, _session.turn_ended]:
		if event.is_connected(_on_participant_changed):
			event.disconnect(_on_participant_changed)

func _on_combat_started(session: CombatSession) -> void:
	if _session == session:
		return
	_disconnect_session()
	_release_live_cards()
	_session = session
	for event in [session.participant_joined, session.participant_fled, session.participant_defeated, session.turn_started, session.turn_ended]:
		event.connect(_on_participant_changed)
	visible = true
	_sync_entries()

func _on_combat_ended(ended_session: CombatSession, _outcome: Dictionary) -> void:
	if ended_session != _session:
		return
	_disconnect_session()
	_session = null
	_release_live_cards()
	if is_instance_valid(_party_hud):
		_party_hud.restore_world_cards()
	visible = not _departing.is_empty()

func _on_participant_changed(_participant: CombatParticipant) -> void:
	_sync_entries()

func _process(_delta: float) -> void:
	if _session != null:
		if is_instance_valid(_session):
			_sync_entries()
		else:
			_session = null
			_release_live_cards()

func _ordered_participants() -> Array[CombatParticipant]:
	return _session.get_upcoming_participants() if is_instance_valid(_session) else []

func _friendly_side() -> StringName:
	if is_instance_valid(_party_hud) and _party_hud._party:
		for member in _party_hud._party.get_all_members():
			var participant := _session.get_participant(member)
			if participant:
				return participant.side
	return CombatParticipantResolver.SIDE_ATTACKER

func _sync_entries() -> void:
	if not is_instance_valid(_session):
		return
	var ordered := _ordered_participants()
	for participant in _entries.keys():
		if not ordered.has(participant):
			_begin_departure(participant)
	var active := _session.get_active_participant()
	var friendly := _friendly_side()
	for participant in ordered:
		var entry := _entries.get(participant) as CombatOrderEntry
		if not is_instance_valid(entry):
			# Rückkehr während der Ausblendung oder in einer unmittelbar neuen Session.
			for old in _departing.keys():
				if old.playable == participant.playable:
					entry = _departing[old]
					_departing.erase(old)
					entry.cancel_exit()
					entry.participant = participant
					break
			if not is_instance_valid(entry):
				entry = ENTRY_SCENE.instantiate() as CombatOrderEntry
				_row.add_child(entry)
				var world_card := _party_hud.take_world_card(participant.playable) if is_instance_valid(_party_hud) else null
				entry.bind(participant, world_card)
				if not entry.borrowed:
					entry.position.y = -entry.card_size().y - NEDimensions.SPACING_L
			_entries[participant] = entry
		entry.refresh(participant == active, participant.side == friendly)
	_layout_cards(ordered)
	visible = true

func _layout_cards(ordered: Array[CombatParticipant]) -> void:
	var base_width := 0.0
	for participant in ordered:
		base_width += (_entries[participant] as CombatOrderEntry).card_size().x * NEDimensions.COMBAT_CARD_SCALE
	var gaps := maxf(0, ordered.size() - 1) * NEDimensions.SPACING_S
	var available := maxf(1, get_viewport_rect().size.x - NEDimensions.SPACING_M * 2)
	var fit := minf(1.0, available / maxf(1, base_width + gaps))
	var factor := NEDimensions.COMBAT_CARD_SCALE * fit
	var x := maxf(NEDimensions.SPACING_M, (get_viewport_rect().size.x - (base_width + gaps) * fit) * 0.5)
	for participant in ordered:
		var entry := _entries[participant] as CombatOrderEntry
		entry.move_to(Vector2(x, 0), factor)
		x += entry.card_size().x * factor + NEDimensions.SPACING_S * fit

func _begin_departure(participant: CombatParticipant) -> void:
	var entry := _entries.get(participant) as CombatOrderEntry
	_entries.erase(participant)
	if not is_instance_valid(entry):
		return
	_departing[participant] = entry
	entry.animate_exit(_finish_departure.bind(participant, entry))

func _finish_departure(participant: CombatParticipant, entry: CombatOrderEntry) -> void:
	if _departing.get(participant) != entry:
		return
	_departing.erase(participant)
	if is_instance_valid(entry):
		if entry.borrowed and is_instance_valid(_party_hud):
			_party_hud.discard_world_card(participant.playable, entry.card)
		entry.queue_free()
	if _session == null:
		if is_instance_valid(_party_hud):
			_party_hud.restore_world_cards()
		visible = not _departing.is_empty()

func _release_live_cards() -> void:
	for participant in _entries.keys():
		var entry := _entries[participant] as CombatOrderEntry
		if not is_instance_valid(entry):
			_entries.erase(participant)
			continue
		if not participant.is_out_of_combat() and entry.borrowed and is_instance_valid(_party_hud):
			var card := entry.release_card()
			if not _party_hud.return_world_card(participant.playable, card):
				card.queue_free()
			_entries.erase(participant)
			entry.queue_free()
		else:
			_begin_departure(participant)

func _exit_tree() -> void:
	_disconnect_manager()
	_disconnect_session()
	# Beim separaten HUD-Abbau übernommene Partykarten zurückgeben.
	for participant in _entries.keys():
		var entry := _entries[participant] as CombatOrderEntry
		if is_instance_valid(entry) and entry.borrowed and is_instance_valid(_party_hud) and _party_hud.is_inside_tree():
			var card := entry.release_card()
			if not _party_hud.return_world_card(participant.playable, card):
				card.queue_free()
	for participant in _departing.keys():
		var entry := _departing[participant] as CombatOrderEntry
		if is_instance_valid(entry) and entry.borrowed and is_instance_valid(_party_hud):
			_party_hud.discard_world_card(participant.playable, entry.card)
	_entries.clear()
	_departing.clear()
	_session = null
