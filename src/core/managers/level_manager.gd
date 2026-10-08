class_name LevelManager
extends Node

## Lädt und entlädt Level unter MainGame/World/LevelRoot.
## Aufruf von überall: LevelManager.load_level("res://src/world/levels/towns/lyrandis.tscn")

static var instance: LevelManager

signal tilemap_bounds_changed(bounds: Array[Vector3])
signal level_loaded(level: BaseLevel)
signal level_unloaded(path: String)

var current_tilemap_bounds: Array[Vector3] = []
var current_level: BaseLevel
var current_level_path: String = ""

@export_range(0.05, 1.0) var fade_out_seconds: float = 0.2
@export_range(0.05, 1.0) var fade_in_seconds: float = 0.25
@export_range(0.0, 2.0) var settle_seconds: float = 0.45
var _transition_lock_owned := false
var _level_root: Node3D
var _transition_pending := false
var _party: Party


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if _transition_lock_owned:
		GameState.release_input_lock()
		_transition_lock_owned = false
	if instance == self:
		instance = null


func setup(level_root: Node3D, party: Party) -> void:
	_level_root = level_root
	_party = party


static func load_level(path: String) -> void:
	if instance == null:
		push_error("LevelManager.load_level: MainGame ist nicht aktiv.")
		return
	instance._load_level(path)


func _load_level(path: String, arrival_path: NodePath = NodePath()) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("LevelManager: Level nicht gefunden: %s" % path)
		return false
	if _level_root == null:
		push_error("LevelManager: LevelRoot ist nicht gebunden.")
		return false

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("LevelManager: Konnte Szene nicht laden: %s" % path)
		return false

	var spawned := packed.instantiate()
	if not spawned is BaseLevel:
		spawned.free()
		push_error("LevelManager: Szene ist kein BaseLevel: %s" % path)
		return false
	# Keine Weltfiguren während laufender Interaktionen/Kämpfe entfernen.
	if (CombatManager.instance and CombatManager.instance.is_in_combat()) or GameState.is_player_input_locked():
		spawned.free()
		return false
	if not arrival_path.is_empty() and not spawned.get_node_or_null(arrival_path) is Node3D:
		spawned.free()
		push_warning("LevelManager: Ankunftspunkt fehlt: " + str(arrival_path))
		return false
	_unload_current_level()
	current_level_path = path
	GameState.world_state.active_location = path
	GameState.world_state.locations[path] = true
	_level_root.add_child(spawned)
	current_level = spawned as BaseLevel

	var spawn := _resolve_spawn(spawned)
	_place_party_at(spawn)
	WorldSceneState.restore(get_tree(), path, _level_root)
	if not arrival_path.is_empty():
		# Ein Ortsübergang hat Vorrang vor alten Partypositionen. Laden ohne
		# Ankunftspfad stellt dagegen weiterhin die gespeicherten Positionen her.
		var arrival := spawned.get_node(arrival_path) as Node3D
		_place_party_at(arrival.global_position)
		for index in range(_party.get_all_members().size()):
			var member: Playable = _party.get_all_members()[index]
			member.global_position = arrival.global_position + Vector3(-1.25 * index, 0, 0)
		if CameraSystem.instance:
			CameraSystem.instance.set_target(_party.leader, true)

	if current_level:
		current_level.on_level_enter()
	level_loaded.emit(current_level)

	return true


func _unload_current_level() -> void:
	WorldSceneState.capture(get_tree(), current_level_path)
	current_tilemap_bounds.clear()
	if current_level:
		current_level.on_level_exit()
	var old_path := current_level_path
	for child in _level_root.get_children():
		_level_root.remove_child(child)
		child.free()
	current_level = null
	current_level_path = ""
	if not old_path.is_empty():
		level_unloaded.emit(old_path)


func _resolve_spawn(level_node: Node) -> Vector3:
	if level_node is BaseLevel:
		return (level_node as BaseLevel).get_default_player_spawn()
	var marker := level_node.get_node_or_null("PlayerSpawn") as Node3D
	if marker:
		return marker.global_position
	return Vector3.ZERO


func _place_party_at(spawn: Vector3) -> void:
	if _party == null:
		return
	_party.global_position = spawn
	for member in _party.get_all_members():
		member.velocity = Vector3.ZERO
		if member.has_method("clear_click_move"):
			member.clear_click_move()


func get_level_root() -> Node3D:
	return _level_root


func get_party() -> Party:
	return _party


func change_tilemap_bounds(bounds: Array[Vector3]) -> void:
	current_tilemap_bounds = bounds
	tilemap_bounds_changed.emit(bounds)


## Speicherstand nur im freien Gameplay, ohne temporäre Kampf-/Dialogzustände.
func save_world(path: String) -> Error:
	if GameState.is_player_input_locked() or (CombatManager.instance and CombatManager.instance.is_in_combat()):
		return ERR_BUSY
	if _party == null or not _party.capture_state():
		return ERR_INVALID_DATA
	WorldSceneState.capture(get_tree(), current_level_path)
	return WorldSaveStore.new().write(GameState.world_state, path)


## Physics-Areas dürfen den Szenenbaum nicht während der Kollisionsauswertung abbauen.
func request_transition(source: Area3D, path: String, arrival: NodePath) -> bool:
	if _transition_pending or current_level == null or not current_level.is_ancestor_of(source):
		return false
	if get_tree().paused or GameState.is_player_input_locked() or (CombatManager.instance and CombatManager.instance.is_in_combat()):
		return false
	_transition_pending = true
	_finish_transition.call_deferred(weakref(source), path, arrival)
	return true

func _finish_transition(source: WeakRef, path: String, arrival: NodePath) -> void:
	var area: Area3D = source.get_ref() as Area3D
	if area == null or current_level == null or not current_level.is_ancestor_of(area) or get_tree().paused or GameState.is_player_input_locked():
		_transition_pending = false
		return
	var previous := current_level
	var fade := MainGame.instance.transition_root.get_node("FadeRect") as ColorRect
	fade.color = NEColors.TRANSITION_BLACK
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.show()
	GameState.acquire_input_lock()
	_transition_lock_owned = true
	await create_tween().tween_property(fade, "modulate:a", 1.0, fade_out_seconds).finished
	# Nur unsere eigene Sperre lösen; fremde Interaktionen bleiben geschützt.
	GameState.release_input_lock()
	_transition_lock_owned = false
	var changed := false
	if is_instance_valid(previous) and current_level == previous and not get_tree().paused:
		changed = _load_level(path, arrival)
	GameState.acquire_input_lock()
	_transition_lock_owned = true
	if changed:
		# Physik läuft hinter der deckenden Fläche weiter, Eingaben bleiben gesperrt.
		await get_tree().create_timer(settle_seconds, false, true).timeout
	await create_tween().tween_property(fade, "modulate:a", 0.0, fade_in_seconds).finished
	fade.hide()
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.release_input_lock()
	_transition_lock_owned = false
	_transition_pending = false
