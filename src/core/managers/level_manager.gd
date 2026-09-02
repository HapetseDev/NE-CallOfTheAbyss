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

var _level_root: Node3D
var _party: Party


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
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


func _load_level(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("LevelManager: Level nicht gefunden: %s" % path)
		return
	if _level_root == null:
		push_error("LevelManager: LevelRoot ist nicht gebunden.")
		return

	_unload_current_level()

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("LevelManager: Konnte Szene nicht laden: %s" % path)
		return

	var spawned := packed.instantiate()
	_level_root.add_child(spawned)
	current_level_path = path
	current_level = spawned as BaseLevel

	var spawn := _resolve_spawn(spawned)
	_place_party_at(spawn)

	if current_level:
		current_level.on_level_enter()
	level_loaded.emit(current_level)


func _unload_current_level() -> void:
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
