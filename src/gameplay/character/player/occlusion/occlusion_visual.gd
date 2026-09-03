class_name OcclusionVisual
extends Node

## Erkennt, ob der Host aus Kamerasicht verdeckt ist, und blendet
## einen X-Ray-Zweitpass auf dem Modell ein. Keine Gameplay-Logik.

const XRAY_SHADER_PATH := "res://src/gameplay/character/player/occlusion/player_xray.gdshader"
const XRAY_MATERIAL_PATH := "res://src/gameplay/character/player/occlusion/player_xray_material.tres"
const FLOOR_NORMAL_Y := 0.65

@export var visual_root: Node3D
@export_group("Darstellung")
@export var xray_color := Color(0.78, 0.84, 0.96, 1.0)
@export_range(0.0, 1.0) var xray_alpha: float = 0.42
@export_range(0.0, 2.0) var outline_strength: float = 0.7
@export_range(0.0, 2.0) var glow_strength: float = 0.28
@export_range(0.05, 0.8) var transition_sec: float = 0.22
@export_group("Erkennung")
@export var use_raycast_gate: bool = false
@export_flags_3d_physics var occlusion_mask: int = 0x7FFFFFFF
@export var sample_height_chest: float = 1.3
@export var sample_height_head: float = 1.65
@export var sample_spread: float = 0.22
@export var enter_hit_count: int = 2
@export var exit_hit_count: int = 0
@export var confirm_frames: int = 2
@export var clear_frames: int = 4
@export_group("Debug")
@export var debug_show_player_occlusion: bool = false

var _host: Node3D
var _xray_material: ShaderMaterial
var _applied: Array[Dictionary] = []
var _xray_amount: float = 1.0
var _occluded: bool = true
var _pending_occluded_frames: int = 0
var _pending_clear_frames: int = 0
var _last_occluder_name: String = ""
var _debug_label: Label3D
var _exclude_rids: Array[RID] = []


func _ready() -> void:
	if OS.has_feature("headless"):
		set_physics_process(false)
		return
	_host = get_parent() as Node3D
	if visual_root == null and _host:
		visual_root = _host.get_node_or_null("Model") as Node3D
		if visual_root == null:
			visual_root = _host
	if not use_raycast_gate:
		_occluded = true
		_xray_amount = 1.0
	_setup_material()
	_apply_xray_pass()
	_collect_exclude_rids()
	if LevelManager.instance:
		if not LevelManager.instance.level_loaded.is_connected(_on_level_changed):
			LevelManager.instance.level_loaded.connect(_on_level_changed)
		if not LevelManager.instance.level_unloaded.is_connected(_on_level_unloaded):
			LevelManager.instance.level_unloaded.connect(_on_level_unloaded)
	_push_shader_params()


func _exit_tree() -> void:
	_restore_materials()
	_xray_amount = 0.0
	_occluded = false


func _physics_process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host) or not _host.is_visible_in_tree():
		_set_occluded(false)
		_update_amount(delta)
		_push_shader_params()
		return
	if use_raycast_gate:
		_update_occlusion_from_rays()
		_update_amount(delta)
	else:
		_last_occluder_name = "depth"
		_occluded = true
		_xray_amount = 1.0
	_push_shader_params()
	_update_debug()


func is_occluded() -> bool:
	return _occluded


func get_last_occluder_name() -> String:
	return _last_occluder_name


func reset_occlusion() -> void:
	_pending_occluded_frames = 0
	_pending_clear_frames = 0
	_last_occluder_name = ""
	if use_raycast_gate:
		_occluded = false
		_xray_amount = 0.0
	else:
		_occluded = true
		_xray_amount = 1.0
	_push_shader_params()


func _on_level_changed(_level: BaseLevel) -> void:
	reset_occlusion()
	_collect_exclude_rids()


func _on_level_unloaded(_path: String) -> void:
	reset_occlusion()


func _setup_material() -> void:
	var packed := load(XRAY_MATERIAL_PATH) as ShaderMaterial
	if packed:
		_xray_material = packed.duplicate() as ShaderMaterial
	else:
		_xray_material = ShaderMaterial.new()
		_xray_material.shader = load(XRAY_SHADER_PATH) as Shader
	_xray_material.render_priority = 12


func _apply_xray_pass() -> void:
	_restore_materials()
	if visual_root == null or _xray_material == null:
		return
	_collect_meshes(visual_root)


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.visible:
			_attach_next_pass(mesh)
	elif node is Sprite3D:
		var sprite := node as Sprite3D
		if sprite.visible and not _is_shadow_sprite(sprite):
			_attach_sprite_next_pass(sprite)
	for child in node.get_children():
		if child is OcclusionVisual:
			continue
		_collect_meshes(child)


func _attach_next_pass(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	var surfaces := mesh.mesh.get_surface_count()
	for i in surfaces:
		var source := mesh.get_active_material(i)
		if source == null:
			continue
		var saved := mesh.get_surface_override_material(i)
		var dup := source.duplicate() as Material
		if dup is BaseMaterial3D:
			(dup as BaseMaterial3D).next_pass = _xray_material
		elif dup is ShaderMaterial:
			(dup as ShaderMaterial).next_pass = _xray_material
		else:
			continue
		mesh.set_surface_override_material(i, dup)
		_applied.append({
			"mesh": mesh,
			"index": i,
			"saved": saved,
		})


func _attach_sprite_next_pass(sprite: Sprite3D) -> void:
	var source := sprite.material_override
	if source == null:
		source = sprite.material_overlay
	if source == null:
		var generated := StandardMaterial3D.new()
		generated.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		generated.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		generated.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		generated.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		generated.albedo_texture = sprite.texture
		generated.next_pass = _xray_material
		sprite.material_override = generated
		_applied.append({
			"sprite": sprite,
			"saved_override": null,
		})
		return
	var saved := sprite.material_override
	var dup := source.duplicate()
	if dup is BaseMaterial3D:
		(dup as BaseMaterial3D).next_pass = _xray_material
	elif dup is ShaderMaterial:
		(dup as ShaderMaterial).next_pass = _xray_material
	sprite.material_override = dup
	_applied.append({
		"sprite": sprite,
		"saved_override": saved,
	})


func _restore_materials() -> void:
	for entry in _applied:
		if entry.has("mesh"):
			var mesh := entry["mesh"] as MeshInstance3D
			if is_instance_valid(mesh):
				mesh.set_surface_override_material(int(entry["index"]), entry["saved"] as Material)
		elif entry.has("sprite"):
			var sprite := entry["sprite"] as Sprite3D
			if is_instance_valid(sprite):
				sprite.material_override = entry["saved_override"] as Material
	_applied.clear()


func _is_shadow_sprite(sprite: Sprite3D) -> bool:
	var n := String(sprite.name).to_lower()
	return n.contains("shadow") or n.contains("schatten")


func _collect_exclude_rids() -> void:
	_exclude_rids.clear()
	if _host == null:
		return
	_collect_collision_rids(_host)


func _collect_collision_rids(node: Node) -> void:
	if node is CollisionObject3D:
		_exclude_rids.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_collision_rids(child)


func _update_occlusion_from_rays() -> void:
	var hits := _count_occlusion_hits()
	if hits >= enter_hit_count:
		_pending_clear_frames = 0
		_pending_occluded_frames += 1
		if _pending_occluded_frames >= confirm_frames:
			_set_occluded(true)
	elif hits <= exit_hit_count:
		_pending_occluded_frames = 0
		_pending_clear_frames += 1
		if _pending_clear_frames >= clear_frames:
			_set_occluded(false)
	else:
		_pending_occluded_frames = 0
		_pending_clear_frames = 0


func _count_occlusion_hits() -> int:
	var camera := _resolve_camera()
	if camera == null or _host == null:
		_last_occluder_name = ""
		return 0
	var space := _host.get_world_3d().direct_space_state
	if space == null:
		return 0
	var hits := 0
	_last_occluder_name = ""
	for sample in _sample_points():
		if _ray_hits_obstacle(space, camera.global_position, sample):
			hits += 1
	return hits


func _set_occluded(value: bool) -> void:
	_occluded = value


func _update_amount(delta: float) -> void:
	var target := 1.0 if _occluded else 0.0
	var speed := 1.0 / maxf(transition_sec, 0.01)
	_xray_amount = move_toward(_xray_amount, target, delta * speed)


func _push_shader_params() -> void:
	if _xray_material == null:
		return
	_xray_material.set_shader_parameter("xray_amount", _xray_amount)
	_xray_material.set_shader_parameter("xray_color", xray_color)
	_xray_material.set_shader_parameter("xray_alpha", xray_alpha)
	_xray_material.set_shader_parameter("outline_strength", outline_strength)
	_xray_material.set_shader_parameter("glow_strength", glow_strength)
	var camera := _resolve_camera()
	if camera:
		_xray_material.set_shader_parameter("inv_projection", camera.get_camera_projection().inverse())


func _sample_points() -> Array[Vector3]:
	var origin := _host.global_position
	var points: Array[Vector3] = [
		origin + Vector3(0.0, sample_height_chest, 0.0),
		origin + Vector3(0.0, sample_height_head, 0.0),
		origin + Vector3(sample_spread, sample_height_chest, 0.0),
		origin + Vector3(-sample_spread, sample_height_chest, 0.0),
	]
	return points


func _ray_hits_obstacle(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = occlusion_mask
	query.exclude = _exclude_rids
	var result := space.intersect_ray(query)
	if result.is_empty():
		return false
	var normal := Vector3.UP
	var normal_value: Variant = result.get("normal", Vector3.UP)
	if normal_value is Vector3:
		normal = normal_value
	if normal.y > FLOOR_NORMAL_Y:
		return false
	var collider_value: Variant = result.get("collider")
	if collider_value is Node:
		_last_occluder_name = (collider_value as Node).name
	return true


func _resolve_camera() -> Camera3D:
	if CameraSystem.instance:
		var cam := CameraSystem.instance.get_camera()
		if cam:
			return cam
	var viewport := get_viewport()
	if viewport:
		return viewport.get_camera_3d()
	return null


func _update_debug() -> void:
	if not debug_show_player_occlusion:
		if _debug_label and is_instance_valid(_debug_label):
			_debug_label.visible = false
		return
	if _debug_label == null or not is_instance_valid(_debug_label):
		_debug_label = Label3D.new()
		_debug_label.name = "OcclusionDebugLabel"
		_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_debug_label.font_size = 28
		_debug_label.outline_size = 6
		_debug_label.position = Vector3(0.0, 2.15, 0.0)
		if _host:
			_host.add_child(_debug_label)
	_debug_label.visible = true
	var state := "XRAY" if _occluded else "NORMAL"
	var occluder := _last_occluder_name if not _last_occluder_name.is_empty() else "-"
	_debug_label.text = "%s  %.2f\n%s" % [state, _xray_amount, occluder]
	_debug_label.modulate = Color(0.85, 0.95, 1.0) if _occluded else Color(0.75, 0.75, 0.75)
