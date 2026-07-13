class_name CharacterModelAnimator extends Node
## Spielt importierte GLB-Skelettanimationen oder prozedurale Fallback-Bob-Animationen.

@export_group("Imported Animations")
@export var use_imported_animations: bool = true
@export var anim_idle: StringName = &"Idle_02"
@export var anim_walk: StringName = &"Walking"
@export var anim_run: StringName = &"Running"
@export var anim_attack: StringName = &""

@export_group("Procedural Fallback")
@export var idle_bob_height: float = 0.04
@export var idle_cycle_sec: float = 1.35
@export var idle_sway_rad: float = 0.025
@export var walk_bob_height: float = 0.07
@export var walk_cycle_sec: float = 0.55
@export var walk_lean_rad: float = 0.06
@export var run_bob_height: float = 0.11
@export var run_cycle_sec: float = 0.28
@export var run_lean_rad: float = 0.14

var _model: Node3D
var _imported_player: AnimationPlayer
var _procedural_player: AnimationPlayer
var _mesh_path: NodePath = NodePath(".")
var _current: String = ""
var _uses_imported: bool = false


func _ready() -> void:
	_model = get_parent() as Node3D
	if _model == null:
		push_warning("CharacterModelAnimator: Parent muss Node3D sein.")
		return
	_imported_player = _find_animation_player(_model)
	_uses_imported = use_imported_animations and _imported_player != null
	if _uses_imported:
		call_deferred("play_state", "idle")
		return
	_setup_procedural_animations()
	call_deferred("play_state", "idle")


func play_state(state: String) -> void:
	if _uses_imported:
		_play_imported_state(state)
	else:
		_play_procedural_state(state)


func _play_imported_state(state: String) -> void:
	if _imported_player == null:
		return
	var anim_name := _map_state_to_imported(state)
	if anim_name.is_empty() or not _imported_player.has_animation(anim_name):
		if state != "idle" and not anim_idle.is_empty() and _imported_player.has_animation(anim_idle):
			anim_name = anim_idle
		else:
			return
	if _current == anim_name and _imported_player.is_playing() and _imported_player.current_animation == anim_name:
		return
	_current = anim_name
	var anim: Animation = _imported_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if state in ["idle", "walk", "run", "sprint"] else Animation.LOOP_NONE
	_imported_player.play(anim_name)


func _map_state_to_imported(state: String) -> StringName:
	match state:
		"idle":
			return anim_idle
		"walk":
			return anim_walk
		"run", "sprint":
			return anim_run
		"attack":
			return anim_attack
		_:
			return anim_idle


func _play_procedural_state(state: String) -> void:
	if _procedural_player == null:
		return
	var anim_name := state
	match state:
		"walk", "attack":
			anim_name = "walk"
		"run", "sprint":
			anim_name = "run"
		_:
			anim_name = "idle"
	if _current == anim_name and _procedural_player.is_playing():
		return
	_current = anim_name
	if not _procedural_player.has_animation(anim_name):
		anim_name = "idle"
	_procedural_player.play(anim_name)


func _setup_procedural_animations() -> void:
	_mesh_path = _model.get_path_to(_find_mesh_node(_model))
	_procedural_player = AnimationPlayer.new()
	_procedural_player.name = "ProceduralAnimationPlayer"
	_model.add_child(_procedural_player)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make_cycle_anim(idle_bob_height, idle_cycle_sec, idle_sway_rad, 0.0))
	lib.add_animation("walk", _make_cycle_anim(walk_bob_height, walk_cycle_sec, walk_lean_rad * 0.35, walk_lean_rad))
	lib.add_animation("run", _make_cycle_anim(run_bob_height, run_cycle_sec, run_lean_rad * 0.25, run_lean_rad))
	if _procedural_player.has_animation_library(&""):
		_procedural_player.remove_animation_library(&"")
	_procedural_player.add_animation_library(&"", lib)


func _make_cycle_anim(bob_height: float, cycle_sec: float, sway_rad: float, lean_rad: float) -> Animation:
	var anim := Animation.new()
	anim.length = cycle_sec
	anim.loop_mode = Animation.LOOP_LINEAR
	var half := cycle_sec * 0.5
	var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, _mesh_path)
	anim.track_insert_key(pos_track, 0.0, Vector3.ZERO)
	anim.track_insert_key(pos_track, half, Vector3(0.0, bob_height, 0.0))
	anim.track_insert_key(pos_track, cycle_sec, Vector3.ZERO)
	if sway_rad > 0.001 or lean_rad > 0.001:
		var rot_track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot_track, _mesh_path)
		var base := Quaternion.from_euler(Vector3(-lean_rad, 0.0, 0.0))
		var sway_l := Quaternion.from_euler(Vector3(-lean_rad, 0.0, sway_rad))
		var sway_r := Quaternion.from_euler(Vector3(-lean_rad, 0.0, -sway_rad))
		anim.track_insert_key(rot_track, 0.0, base)
		anim.track_insert_key(rot_track, half * 0.5, sway_l)
		anim.track_insert_key(rot_track, half, base)
		anim.track_insert_key(rot_track, half * 1.5, sway_r)
		anim.track_insert_key(rot_track, cycle_sec, base)
	return anim


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		if child is CharacterModelAnimator:
			continue
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _find_mesh_node(root: Node) -> Node3D:
	for child in root.get_children():
		if child is CharacterModelAnimator or child is AnimationPlayer:
			continue
		if child is MeshInstance3D:
			return child as Node3D
		if child is Node3D:
			var found := _find_mesh_node(child)
			if found:
				return found
	for child in root.get_children():
		if child is Node3D and child is not CharacterModelAnimator:
			return child as Node3D
	return root as Node3D
