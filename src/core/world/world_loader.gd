extends RefCounted

const MAIN_SCENE := "res://src/core/main_game/main_game.tscn"

static func _result(error: Error, message: String = "") -> Dictionary:
	return {"error": error, "message": message}

static func _busy(state: Node) -> bool:
	return state.get_tree().paused or state.is_player_input_locked() or (CombatManager.instance != null and CombatManager.instance.is_in_combat())


static func load_game(state: Node, path: String) -> Dictionary:
	if _busy(state):
		return _result(ERR_BUSY, "Laden ist während Kampf, Pause oder Interaktion gesperrt.")
	var tree := state.get_tree()
	var previous := tree.current_scene
	var previous_world: WorldState = state.world_state
	if previous == null or previous.is_queued_for_deletion() or previous.get_parent() != tree.root or (MainGame.instance != null and MainGame.instance != previous):
		return _result(ERR_UNAVAILABLE, "Keine unterstützte aktuelle Szene zum Ersetzen.")
	var store := WorldSaveStore.new()
	var candidate := store.read(path)
	if candidate == null:
		return _result(ERR_INVALID_DATA, store.last_error)
	# Der Reader erlaubt auch isolierte Daten-Snapshots; der Spiellader verlangt eine Welt.
	if candidate.active_location.is_empty() or candidate.party_state.is_empty():
		return _result(ERR_INVALID_DATA, "Spielstand enthält keine aktive Welt und Party.")
	var level_scene := load(candidate.active_location) as PackedScene
	if level_scene == null:
		return _result(ERR_CANT_OPEN, "Gespeicherter Ort ist nicht ladbar.")
	var level_probe := level_scene.instantiate()
	var valid_level := level_probe is BaseLevel
	level_probe.free()
	if not valid_level:
		return _result(ERR_INVALID_DATA, "Gespeicherter Ort ist kein Spiellevel.")
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		return _result(ERR_CANT_OPEN, "Hauptspielszene fehlt.")
	var incoming := packed.instantiate() as MainGame
	if incoming == null:
		return _result(ERR_CANT_CREATE, "Hauptspielszene konnte nicht vorbereitet werden.")
	# Nicht mitten in einer Button-/Signalverarbeitung den aufrufenden Node entfernen.
	await tree.process_frame
	if not is_instance_valid(previous) or previous.is_queued_for_deletion() or tree.current_scene != previous or state.world_state != previous_world or _busy(state):
		incoming.free()
		return _result(ERR_BUSY, "Die aktive Sitzung hat sich während der Vorbereitung verändert.")
	var expected_party: Dictionary = candidate.party_state.duplicate(true)
	var previous_index := previous.get_index()
	if previous is MainGame:
		previous.preserve_state_on_exit = true
	tree.current_scene = null
	tree.root.remove_child(previous)
	state.world_state = candidate
	tree.root.add_child(incoming)
	tree.current_scene = incoming
	if not _is_ready(incoming, candidate, expected_party):
		# Neue Szene abbauen, dann dieselben alten Daten und Nodes wieder einsetzen.
		incoming.preserve_state_on_exit = true
		tree.current_scene = null
		tree.root.remove_child(incoming)
		incoming.free()
		state.world_state = previous_world
		state._input_lock_count = 0
		tree.paused = false
		tree.root.add_child(previous)
		tree.root.move_child(previous, previous_index)
		tree.current_scene = previous
		if previous is MainGame:
			previous.preserve_state_on_exit = false
			previous.camera_system.camera.make_current()
		return _result(ERR_CANT_CREATE, "Spielwelt konnte nicht vollständig aufgebaut werden; bisherige Sitzung wiederhergestellt.")
	# Alte Nodes sind bereits aus dem Baum: ihre Freigabe kann die neue Sitzung nicht resetten.
	previous.free()
	return _result(OK)


static func _is_ready(game: MainGame, candidate: WorldState, expected_party: Dictionary) -> bool:
	if game.is_queued_for_deletion() or not game.is_node_ready() or game.party == null or game.party.leader == null or game.level_manager.current_level == null:
		return false
	if game.level_manager.current_level.is_queued_for_deletion() or candidate.party_state != expected_party:
		return false
	if game.level_manager.current_level_path != candidate.active_location or game.camera_system.target != game.party.leader:
		return false
	var ids: Array = []
	for member in game.party.get_all_members():
		if not is_instance_valid(member) or member.is_queued_for_deletion() or member.character == null:
			return false
		if candidate.characters.get_character(member.character.character_id) != member.character:
			return false
		ids.append(member.character.character_id)
	if ids != expected_party.member_ids:
		return false
	for node in game.get_tree().get_nodes_in_group("combat_reactive"):
		if node is Playable and node.is_queued_for_deletion():
			return false
	return true
