extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var path: String = GraphicsSettings.SETTINGS_PATH
	var existed := FileAccess.file_exists(path)
	var original := FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	var options := [GraphicsSettings.cutout_quality, GraphicsSettings.shadow_quality, GraphicsSettings.resolution_index]
	var light := OmniLight3D.new()
	light.shadow_enabled = true
	add_child(light)
	await get_tree().process_frame
	GraphicsSettings.set_option("shadows", false)
	check(not light.shadow_enabled, "Existing light loses shadows")
	var late := DirectionalLight3D.new()
	late.shadow_enabled = true
	add_child(late)
	var unshadowed := OmniLight3D.new()
	add_child(unshadowed)
	await get_tree().process_frame
	check(not late.shadow_enabled, "New level lights respect disabled shadows")
	GraphicsSettings.set_option("shadows", true)
	check(light.shadow_enabled and late.shadow_enabled, "Original shadows restored")
	check(not unshadowed.shadow_enabled, "Originally unshadowed light stays unshadowed")
	var original_distance := late.directional_shadow_max_distance
	var original_mode := late.directional_shadow_mode
	GraphicsSettings.set_option("shadow_quality", GraphicsSettings.Quality.SIMPLE)
	check(not light.shadow_enabled and late.shadow_enabled, "Simple mode keeps only sunlight shadows")
	check(late.directional_shadow_max_distance <= 30.0 and late.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "Simple sunlight uses short range and one shadow map")
	GraphicsSettings.set_option("shadow_quality", GraphicsSettings.Quality.HIGH)
	check(late.directional_shadow_max_distance == original_distance and late.directional_shadow_mode == original_mode, "High restores original sunlight settings")
	for index in 4:
		GraphicsSettings.set_option("resolution_index", index)
		check(is_equal_approx(float(ProjectSettings.get_setting("rendering/scaling_3d/scale")), GraphicsSettings.RESOLUTIONS[index]), "Resolution preset %d" % index)
	GraphicsSettings.set_option("cutout", false)
	check(not GraphicsSettings.cutout_enabled, "Cutout preference changes")
	GraphicsSettings.set_option("reduced_resolution", true)
	check(is_equal_approx(float(ProjectSettings.get_setting("rendering/scaling_3d/scale")), 0.7), "Reduced render scale applied")
	var saved := ConfigFile.new()
	check(saved.load(path) == OK and saved.get_value("graphics", "reduced_resolution") == true, "Preferences persisted")
	GraphicsSettings.set_option("reduced_resolution", false)
	check(is_equal_approx(float(ProjectSettings.get_setting("rendering/scaling_3d/scale")), 1.0), "Native render scale restored")
	var legacy := ConfigFile.new()
	legacy.set_value("graphics", "cutout", false)
	legacy.set_value("graphics", "shadows", false)
	legacy.set_value("graphics", "reduced_resolution", true)
	GraphicsSettings.load_preferences(legacy)
	check(GraphicsSettings.cutout_quality == 0 and GraphicsSettings.shadow_quality == 0 and GraphicsSettings.resolution_index == 2, "Legacy preferences preserve disabled effects and 70 percent")
	await _test_simple_grid()
	await _test_game_options()
	GraphicsSettings.set_option("cutout_quality", options[0])
	GraphicsSettings.set_option("shadow_quality", options[1])
	GraphicsSettings.set_option("resolution_index", options[2])
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else:
		DirAccess.remove_absolute(path)
	print("Graphics settings: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_simple_grid() -> void:
	var visual := OcclusionVisual.new()
	add_child(visual)
	visual.set_process(false)
	var library := MeshLibrary.new()
	library.create_item(0)
	library.set_item_mesh(0, BoxMesh.new())
	library.set_item_shapes(0, [BoxShape3D.new(), Transform3D.IDENTITY])
	var grid := GridMap.new()
	grid.mesh_library = library
	grid.set_cell_item(Vector3i.ZERO, 0, 3)
	grid.set_cell_item(Vector3i(2, 0, 0), 0)
	add_child(grid)
	var desired: Array[Dictionary] = []
	visual._add_simple_cell(grid, Vector3i.ZERO, desired)
	var hidden_id: int = visual._simple_grids[grid].variants[0]
	grid.set_cell_item(Vector3i.ZERO, hidden_id, 3)
	visual._simple_hidden = desired
	check(grid.mesh_library.get_item_mesh(hidden_id) == null, "Simple wall has no rendered mesh")
	check(grid.mesh_library.get_item_shapes(hidden_id) == library.get_item_shapes(0), "Hidden wall retains collision shapes")
	check(grid.get_cell_item(Vector3i(2, 0, 0)) == 0 and library.get_item_list().size() == 1, "Neighbor and original library unchanged")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var point := grid.to_global(grid.map_to_local(Vector3i.ZERO))
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3(0, 0, 3), point - Vector3(0, 0, 3))
	var hit := grid.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == grid, "Hidden cell still physically blocks rays")
	visual._restore()
	check(grid.mesh_library == library and grid.get_cell_item(Vector3i.ZERO) == 0 and grid.get_cell_item_orientation(Vector3i.ZERO) == 3, "Cleanup restores original cell, orientation and library")
	grid.free()
	visual.free()

func _test_game_options() -> void:
	GameState.reset_session()
	GraphicsSettings.set_option("cutout_quality", GraphicsSettings.Quality.HIGH)
	var game := preload("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var visual := game.party.get_node("OcclusionVisual") as OcclusionVisual
	check(not visual._materials.is_empty(), "High mode installs cutout materials")
	var shell := game.game_windows
	shell.open_page(5)
	shell._options()
	var choices := shell._body.find_children("*", "OptionButton", true, false)
	check(choices.size() == 3, "Options contain three quality selectors")
	choices[0].select(1)
	choices[0].item_selected.emit(1)
	visual._process(0.0)
	check(GraphicsSettings.cutout_quality == 1 and visual._materials.is_empty(), "Simple selection removes expensive shader materials")
	# Place a known occluding GridMap cell in the real level, far from other geometry.
	var player := game.party.leader
	player.global_position = Vector3(1001, 0, 0)
	var grid := GridMap.new()
	var library := MeshLibrary.new()
	library.create_item(0)
	var box := BoxMesh.new()
	box.size = Vector3(2, 2, 2)
	library.set_item_mesh(0, box)
	# Real tiles can be offset from their owning cell; the old hit-to-cell lookup
	# selected an empty neighbor. A steep ray also hits the wall's top face.
	var mesh_offset := Transform3D(Basis.IDENTITY, Vector3(4, 0, 0))
	library.set_item_mesh_transform(0, mesh_offset)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	library.set_item_shapes(0, [shape, mesh_offset])
	grid.mesh_library = library
	grid.set_cell_item(Vector3i.ZERO, 0)
	grid.add_to_group("camera_occluder")
	game.level_manager.current_level.add_child(grid)
	grid.global_position = Vector3(996, 0, 2)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.global_position = Vector3(1001, 5, 8)
	camera.look_at(Vector3(1001, 0.7, 0))
	camera.make_current()
	await get_tree().physics_frame
	await get_tree().physics_frame
	visual._update_simple()
	check(grid.get_cell_item(Vector3i.ZERO) != 0, "Simple ray detection hides the actual occluding cell")
	check(grid.mesh_library != library, "Simple level uses an isolated library")
	check(visual._blocks_simple_view(AABB(Vector3(1000, 0, 2), Vector3(2, 2, 2)), player.global_position, camera), "Steep camera sees an offset wall as an occluder")
	check(not visual._blocks_simple_view(AABB(Vector3(999, -0.2, -1), Vector3(4, 0.2, 4)), player.global_position, camera), "Walkable floor remains visible")
	check(not visual._blocks_simple_view(AABB(Vector3(1000, 0, -5), Vector3(2, 2, 2)), player.global_position, camera), "Walls behind the party remain visible")
	visual._update_simple()
	check(grid.get_cell_item(Vector3i.ZERO) != 0, "Hidden offset wall stays hidden across repeated updates")
	if "--visual-smoke" in OS.get_cmdline_user_args():
		shell.close()
		GraphicsSettings.set_option("cutout_quality", GraphicsSettings.Quality.OFF)
		visual._process(0)
		await _capture("simple-wall-off")
		GraphicsSettings.set_option("cutout_quality", GraphicsSettings.Quality.SIMPLE)
		visual._process(0)
		await _capture("simple-wall-on")
		shell.open_page(5)
		shell._options()
	GraphicsSettings.set_option("cutout_quality", GraphicsSettings.Quality.OFF)
	visual._process(0)
	check(grid.mesh_library == library and grid.get_cell_item(Vector3i.ZERO) == 0, "Switching off restores level cells and library")
	GraphicsSettings.set_option("cutout_quality", GraphicsSettings.Quality.HIGH)
	visual._process(0)
	check(not visual._materials.is_empty(), "Switching back to high restores cutout materials")
	if "--visual-smoke" in OS.get_cmdline_user_args():
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/graphics-options.png")
	shell.close()
	GraphicsSettings.set_option("cutout_quality", GraphicsSettings.Quality.SIMPLE)
	visual._process(0)
	visual._update_simple()
	remove_child(game)
	check(grid.mesh_library == library and grid.get_cell_item(Vector3i.ZERO) == 0, "Scene teardown restores simple cell state for re-entry")
	game.free()

func _capture(filename: String) -> void:
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/" + filename + ".png")
