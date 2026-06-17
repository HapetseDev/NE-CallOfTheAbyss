class_name CharacterModelAnimator extends Node
## Prozedurale Idle-/Lauf-Animationen für importierte GLTF-Modelle (ein Mesh, ohne Bones).

@export_group("Idle")
@export var idle_bob_height: float = 0.04
@export var idle_cycle_sec: float = 1.35
@export var idle_sway_rad: float = 0.025

@export_group("Walk")
@export var walk_bob_height: float = 0.07
@export var walk_cycle_sec: float = 0.55
@export var walk_lean_rad: float = 0.06

@export_group("Run")
@export var run_bob_height: float = 0.11
@export var run_cycle_sec: float = 0.28
@export var run_lean_rad: float = 0.14

var _model: Node3D
var _anim_player: AnimationPlayer
var _mesh_path: NodePath = NodePath(".")
var _current: String = ""


func _ready() -> void:
	_model = get_parent() as Node3D
	if _model == null:
		push_warning("CharacterModelAnimator: Parent muss Node3D sein.")
		return
	_mesh_path = _model.get_path_to(_find_mesh_node(_model))
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	_model.add_child(_anim_player)
	_build_library()
	call_deferred("play_state", "idle")


func play_state(state: String) -> void:
	if _anim_player == null:
		return
	var anim_name := state
	match state:
		"walk", "attack":
			anim_name = "walk"
		"run", "sprint":
			anim_name = "run"
		_:
			anim_name = "idle"
	if _current == anim_name and _anim_player.is_playing():
		return
	_current = anim_name
	if not _anim_player.has_animation(anim_name):
		anim_name = "idle"
	_anim_player.play(anim_name)


func _build_library() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make_cycle_anim(idle_bob_height, idle_cycle_sec, idle_sway_rad, 0.0))
	lib.add_animation("walk", _make_cycle_anim(walk_bob_height, walk_cycle_sec, walk_lean_rad * 0.35, walk_lean_rad))
	lib.add_animation("run", _make_cycle_anim(run_bob_height, run_cycle_sec, run_lean_rad * 0.25, run_lean_rad))
	if _anim_player.has_animation_library(&""):
		_anim_player.remove_animation_library(&"")
	_anim_player.add_animation_library(&"", lib)


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
