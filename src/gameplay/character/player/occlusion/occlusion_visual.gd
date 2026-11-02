class_name OcclusionVisual
extends Node

## dmlarys VisualShader: raycast-gesteuerte Sichtkapseln für die ganze Party.
## Charaktermaterialien werden niemals verändert; kein X-Ray-/Leuchtpass.
const MAX_SUBJECTS := 64
const CUTOUT := preload("res://src/gameplay/character/player/occlusion/party_cutout.tres")
@export_range(0.5, 4.0) var radius: float = 1.5
@export var height: float = 0.7
var _level: BaseLevel
var _materials: Array[ShaderMaterial] = []
var _saved: Array[Dictionary] = []
var _cache: Dictionary = {}
var _radii: Dictionary = {}
var _quality := -1
var _simple_time := 0.0
var _simple_grids: Dictionary = {}
var _simple_hidden: Array[Dictionary] = []
var _simple_geometry: Dictionary = {}
var _retired_libraries: Array[Dictionary] = []

func _process(delta: float) -> void:
	for index in range(_retired_libraries.size() - 1, -1, -1):
		if Engine.get_process_frames() >= _retired_libraries[index].release_frame:
			_retired_libraries.remove_at(index)
	if _quality != GraphicsSettings.cutout_quality:
		_restore()
		_quality = GraphicsSettings.cutout_quality
		_simple_time = 0.0
	if not GraphicsSettings.cutout_enabled:
		if is_instance_valid(_level):
			_restore()
		return
	var level: BaseLevel = LevelManager.instance.current_level if LevelManager.instance else null
	if _quality == GraphicsSettings.Quality.SIMPLE:
		if level != _level:
			_restore()
			_level = level
			_simple_time = 0.0
		_simple_time -= delta
		if level and _simple_time <= 0.0:
			_simple_time = 0.1
			_update_simple()
		return
	if not is_instance_valid(_level) or level != _level:
		_restore()
		_level = level
		if level:
			for node in get_tree().get_nodes_in_group("camera_occluder"):
				if level.is_ancestor_of(node):
					_prepare(node)
	var subjects := PackedVector4Array()
	subjects.resize(MAX_SUBJECTS)
	var hits := PackedVector4Array()
	hits.resize(MAX_SUBJECTS)
	var camera := get_viewport().get_camera_3d()
	var active_members: Array[int] = []
	var count := 0
	var party := get_parent() as Party
	if party:
		for member in party.get_all_members():
			if not is_instance_valid(member) or not member.is_inside_tree() or not member.is_visible_in_tree():
				continue
			if count == MAX_SUBJECTS:
				break
			var position := member.global_position
			subjects[count] = Vector4(position.x, position.y + height, position.z, position.y)
			var id := member.get_instance_id()
			active_members.append(id)
			var center := position + Vector3.UP * height
			var collision := _occlusion_hit(member, camera, center)
			var target_radius := radius if not collision.is_empty() else 0.0
			var current_radius := lerpf(float(_radii.get(id, 0.0)), target_radius, clampf(delta * 8.0, 0, 1))
			_radii[id] = current_radius
			# Without an occluder no capsule is needed; stale hit positions are not reused.
			if not collision.is_empty():
				var hit: Vector3 = collision.position
				hits[count] = Vector4(hit.x, hit.y, hit.z, current_radius)
			count += 1
	for id in _radii.keys():
		if not active_members.has(id):
			_radii.erase(id)
	for material in _materials:
		material.set_shader_parameter("subjects", subjects)
		material.set_shader_parameter("subject_count", count)
		material.set_shader_parameter("cutout_hits", hits)
		material.set_shader_parameter("cutout_enabled", count > 0)

func _occlusion_hit(member: Playable, camera: Camera3D, center: Vector3) -> Dictionary:
	if not camera:
		return {}
	var excluded: Array[RID] = []
	for actor in get_tree().get_nodes_in_group("combat_reactive"):
		if actor is CollisionObject3D:
			excluded.append(actor.get_rid())
	var end := camera.global_position
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		end = center + camera.global_basis.z * (end - center).dot(camera.global_basis.z)
	var ray := PhysicsRayQueryParameters3D.create(center, end, 0xFFFFFFFF, excluded)
	for attempt in 16:
		var hit := member.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			return {}
		var node := hit.collider as Node
		while node:
			if node.is_in_group("camera_occluder"):
				return hit
			node = node.get_parent()
		excluded.append(hit.rid)
		ray.exclude = excluded
	return {}

func _exit_tree() -> void:
	# Beim Szenenabbau keine GridMap-Neuberechnung mehr auslösen. Die Kopien
	# gehören ihren Nodes; beim Wiedereintritt wird aus den Originalen aufgebaut.
	_restore(false)

func _restore(restore_nodes: bool = true) -> void:
	_restore_simple(restore_nodes)
	for material in _materials:
		material.set_shader_parameter("cutout_enabled", false)
	for entry in _saved:
		if not restore_nodes or not is_instance_valid(entry.node):
			continue
		if entry.node is GridMap:
			# GridMap hat beim Verlassen bereits seine Render-RIDs freigegeben.
			# Beim Rollback/erneuten Eintritt wird aus der Originalbibliothek aufgebaut.
			if entry.node.is_inside_tree():
				_retire_library(entry.node.mesh_library)
				entry.node.mesh_library = entry.original
				entry.node.remove_meta("cutout_original_library")
		else:
			entry.node.set_surface_override_material(entry.surface, entry.original)
	_saved.clear()
	_materials.clear()
	_cache.clear()
	_radii.clear()
	_level = null

## Simple mode changes only the visual mesh of hit GridMap cells. Collision and
## navigation are copied unchanged; original libraries and cells are restored.
func _restore_simple(_restore_nodes: bool = true) -> void:
	for entry in _simple_hidden:
		_restore_simple_entry(entry)
	for grid in _simple_grids:
		if is_instance_valid(grid):
			_retire_library(grid.mesh_library)
			grid.mesh_library = _simple_grids[grid].original
	_simple_hidden.clear()
	_simple_grids.clear()
	_simple_geometry.clear()

func _retire_library(library: MeshLibrary) -> void:
	# GridMap rebuilds render instances later; retain their meshes across that update.
	_retired_libraries.append({"library": library, "release_frame": Engine.get_process_frames() + 3})

func _restore_simple_entry(entry: Dictionary) -> void:
	if not is_instance_valid(entry.node):
		return
	if entry.node is GridMap:
		entry.node.set_cell_item(entry.cell, entry.item, entry.orientation)
	else:
		entry.node.visible = entry.visible

func _update_simple() -> void:
	var desired: Array[Dictionary] = []
	var party := get_parent() as Party
	var camera := get_viewport().get_camera_3d()
	if party and camera:
		for node in get_tree().get_nodes_in_group("camera_occluder"):
			if _level.is_ancestor_of(node):
				_cache_simple_geometry(node)
		for member in party.get_all_members():
			if not is_instance_valid(member) or not member.is_visible_in_tree():
				continue
			for node in _simple_geometry:
				if not is_instance_valid(node) or not node.is_inside_tree():
					continue
				for entry in _simple_geometry[node]:
					var bounds: AABB = node.global_transform * entry.bounds
					if not _blocks_simple_view(bounds, member.global_position, camera):
						continue
					if node is GridMap:
						_add_simple_cell(node, entry.cell, desired)
					else:
						_collect_simple_meshes(node, desired)
	for old in _simple_hidden:
		if not _contains_simple(desired, old):
			_restore_simple_entry(old)
	for entry in desired:
		if _contains_simple(_simple_hidden, entry):
			continue
		if entry.node is GridMap:
			entry.node.set_cell_item(entry.cell, _simple_grids[entry.node].variants[entry.item], entry.orientation)
		else:
			entry.node.hide()
	_simple_hidden = desired

func _cache_simple_geometry(node: Node) -> void:
	if node is GridMap and not _simple_geometry.has(node) and node.mesh_library:
		var entries: Array[Dictionary] = []
		for cell in node.get_used_cells():
			var item: int = node.get_cell_item(cell)
			var mesh: Mesh = node.mesh_library.get_item_mesh(item)
			if mesh == null:
				continue
			var cell_transform := Transform3D(node.get_cell_item_basis(cell).scaled(Vector3.ONE * node.cell_scale), node.map_to_local(cell))
			var bounds: AABB = cell_transform * node.mesh_library.get_item_mesh_transform(item) * mesh.get_aabb()
			entries.append({"cell": cell, "bounds": bounds})
		_simple_geometry[node] = entries
	elif node is MeshInstance3D and not _simple_geometry.has(node) and node.mesh:
		_simple_geometry[node] = [{"bounds": node.mesh.get_aabb()}]
	for child in node.get_children():
		_cache_simple_geometry(child)

func _blocks_simple_view(bounds: AABB, feet: Vector3, camera: Camera3D) -> bool:
	# Use visual bounds, not a collision point: tiles can extend outside their cell,
	# and a steep camera ray can hit the top of a wall rather than its upright face.
	if bounds.end.y <= feet.y + 0.35:
		return false
	var right := camera.global_basis.x * 0.35
	for offset in [Vector3.UP * height, Vector3.UP * (height + 0.7), Vector3.UP * height + right, Vector3.UP * height - right]:
		var start: Vector3 = feet + offset
		var end := camera.global_position
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			end = start + camera.global_basis.z * (end - start).dot(camera.global_basis.z)
		if bounds.intersects_segment(start, end) != null:
			return true
	return false

func _contains_simple(entries: Array[Dictionary], entry: Dictionary) -> bool:
	for candidate in entries:
		if candidate.node == entry.node and candidate.get("cell") == entry.get("cell"):
			return true
	return false

func _add_simple_cell(grid: GridMap, cell: Vector3i, desired: Array[Dictionary]) -> void:
	for old in _simple_hidden:
		if old.node == grid and old.get("cell") == cell:
			if not _contains_simple(desired, old):
				desired.append(old)
			return
	var item := grid.get_cell_item(cell)
	if item < 0 or grid.mesh_library == null:
		return
	if not _simple_grids.has(grid):
		var original := grid.mesh_library
		var library := original.duplicate() as MeshLibrary
		var variants := {}
		for id in original.get_item_list():
			var hidden_id := library.get_last_unused_item_id()
			library.create_item(hidden_id)
			library.set_item_shapes(hidden_id, original.get_item_shapes(id))
			library.set_item_navigation_mesh(hidden_id, original.get_item_navigation_mesh(id))
			library.set_item_navigation_mesh_transform(hidden_id, original.get_item_navigation_mesh_transform(id))
			library.set_item_navigation_layers(hidden_id, original.get_item_navigation_layers(id))
			variants[id] = hidden_id
		_simple_grids[grid] = {"original": original, "variants": variants}
		grid.mesh_library = library
	var entry := {"node": grid, "cell": cell, "item": item, "orientation": grid.get_cell_item_orientation(cell)}
	if not _contains_simple(desired, entry):
		desired.append(entry)

func _collect_simple_meshes(node: Node, desired: Array[Dictionary]) -> void:
	if node is MeshInstance3D:
		var entry := {"node": node, "visible": node.visible}
		for old in _simple_hidden:
			if old.node == node:
				entry = old
		if entry.visible and not _contains_simple(desired, entry):
			desired.append(entry)
	for child in node.get_children():
		_collect_simple_meshes(child, desired)

func _prepare(node: Node) -> void:
	if node is GridMap:
		var grid := node as GridMap
		if grid.mesh_library == null:
			return
		var original: MeshLibrary = grid.get_meta("cutout_original_library", grid.mesh_library)
		var library := original.duplicate() as MeshLibrary
		for id in library.get_item_list():
			var mesh := library.get_item_mesh(id)
			if mesh == null:
				continue
			var copy := mesh.duplicate() as Mesh
			for surface in range(copy.get_surface_count()):
				var material := _convert(mesh.surface_get_material(surface))
				if material:
					copy.surface_set_material(surface, material)
			library.set_item_mesh(id, copy)
		_saved.append({"node": grid, "original": original})
		grid.set_meta("cutout_original_library", original)
		grid.mesh_library = library
	elif node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh:
			for surface in range(mesh.mesh.get_surface_count()):
				var material := _convert(mesh.get_active_material(surface))
				if material:
					_saved.append({"node": mesh, "surface": surface, "original": mesh.get_surface_override_material(surface)})
					mesh.set_surface_override_material(surface, material)
	for child in node.get_children():
		_prepare(child)

func _convert(source: Material) -> ShaderMaterial:
	if not source is StandardMaterial3D:
		return null
	if _cache.has(source):
		return _cache[source]
	var original := source as StandardMaterial3D
	# Spezielle Shader/Glas nicht stillschweigend in ein anderes Material umwandeln.
	if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and original.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		return null
	var material := ShaderMaterial.new()
	material.shader = CUTOUT
	material.set_shader_parameter("camera_occlusion_cutout_noise", preload("res://src/gameplay/character/player/occlusion/vendor/dmlary/noise_texture_2d.tres"))
	material.set_shader_parameter("albedo", original.albedo_color)
	material.set_shader_parameter("use_texture", original.albedo_texture != null)
	material.set_shader_parameter("albedo_texture", original.albedo_texture)
	material.set_shader_parameter("uv_scale", original.uv1_scale)
	material.set_shader_parameter("uv_offset", original.uv1_offset)
	material.set_shader_parameter("roughness_value", original.roughness)
	material.set_shader_parameter("metallic_value", original.metallic)
	material.set_shader_parameter("specular_value", original.metallic_specular)
	material.set_shader_parameter("alpha_scissor", original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	material.set_shader_parameter("alpha_threshold", original.alpha_scissor_threshold)
	_cache[source] = material
	_materials.append(material)
	return material
