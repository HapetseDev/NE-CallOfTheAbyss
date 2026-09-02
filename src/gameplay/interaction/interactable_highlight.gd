# Temporary glow on actionable entities while the action menu is open.
# Supports MeshInstance3D (outline overlay) and Sprite3D (modulate pulse).
class_name InteractableHighlightFx extends Node

const MESH_SHADER_PATH := "res://src/gameplay/interaction/interactable_highlight.gdshader"
const SPRITE_TINT := Color(1.35, 1.65, 2.0, 1.0)
const PULSE_SPEED := 2.0
const PULSE_AMOUNT := 0.18

static var _shared_overlay: ShaderMaterial

var _meshes: Array[MeshInstance3D] = []
var _sprites: Array[Sprite3D] = []
var _sprite_originals: Array[Color] = []
var _active: bool = false


func setup(visual_root: Node3D) -> void:
	_clear_applied()
	_ensure_overlay()
	_collect_visuals(visual_root)
	_apply()
	_active = true
	set_process(not _sprites.is_empty())


func _process(_delta: float) -> void:
	if not _active or _sprites.is_empty():
		return
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.001 * PULSE_SPEED * TAU) * PULSE_AMOUNT
	for i in _sprites.size():
		var sprite := _sprites[i]
		if not is_instance_valid(sprite):
			continue
		var base: Color = _sprite_originals[i]
		sprite.modulate = Color(
			base.r * SPRITE_TINT.r * pulse,
			base.g * SPRITE_TINT.g * pulse,
			base.b * SPRITE_TINT.b * pulse,
			base.a
		)


func _exit_tree() -> void:
	_clear_applied()
	_active = false


func _ensure_overlay() -> void:
	if _shared_overlay != null and is_instance_valid(_shared_overlay):
		return
	var shader := load(MESH_SHADER_PATH) as Shader
	_shared_overlay = ShaderMaterial.new()
	_shared_overlay.shader = shader
	_shared_overlay.render_priority = 2


func _collect_visuals(root: Node) -> void:
	_collect_recursive(root)


func _collect_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.visible:
			_meshes.append(mesh)
	elif node is Sprite3D:
		var sprite := node as Sprite3D
		if sprite.visible and not _is_shadow_sprite(sprite):
			_sprites.append(sprite)
	for child in node.get_children():
		_collect_recursive(child)


func _is_shadow_sprite(sprite: Sprite3D) -> bool:
	var n := String(sprite.name).to_lower()
	return n.contains("shadow") or n.contains("schatten")


func _apply() -> void:
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = _shared_overlay
	for sprite in _sprites:
		if not is_instance_valid(sprite):
			continue
		_sprite_originals.append(sprite.modulate)
		sprite.modulate = Color(
			sprite.modulate.r * SPRITE_TINT.r,
			sprite.modulate.g * SPRITE_TINT.g,
			sprite.modulate.b * SPRITE_TINT.b,
			sprite.modulate.a
		)


func _clear_applied() -> void:
	for mesh in _meshes:
		if is_instance_valid(mesh) and mesh.material_overlay == _shared_overlay:
			mesh.material_overlay = null
	for i in _sprites.size():
		var sprite := _sprites[i]
		if is_instance_valid(sprite) and i < _sprite_originals.size():
			sprite.modulate = _sprite_originals[i]
	_meshes.clear()
	_sprites.clear()
	_sprite_originals.clear()
	set_process(false)
