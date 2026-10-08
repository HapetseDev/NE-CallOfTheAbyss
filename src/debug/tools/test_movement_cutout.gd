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
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var player := game.party.leader
	var walk := player.get_node("StateMachine/Walk") as StateWalk
	player.direction = Vector3.RIGHT
	Input.action_press("Run")
	walk.process(2.0)
	Input.action_release("Run")
	check(is_equal_approx(player.velocity.x, 3.75), "Laufzustand erreicht erhöhtes Geschwindigkeitsmaximum")
	var visual := game.party.get_node("OcclusionVisual") as OcclusionVisual
	check(not visual._materials.is_empty(), "Markierte Levelgeometrie erhält Sichtfenster")
	var grid := game.level_manager.current_level.get_node("Umgebung/WandGridMap") as GridMap
	var original := load("res://assets/tilesets/tilesfreedungeon.tres") as MeshLibrary
	check(grid.mesh_library != original, "MeshLibrary bleibt isolierte Laufzeitkopie")
	check(not original.get_item_mesh(original.get_item_list()[0]).surface_get_material(0) is ShaderMaterial, "Originalmaterial bleibt unangetastet")
	var meshes := player.find_children("*", "MeshInstance3D", true, false)
	var unchanged := true
	for mesh in meshes:
		if mesh.mesh:
			for surface in range(mesh.mesh.get_surface_count()):
				var material: Material = mesh.get_active_material(surface)
				if material and material.next_pass:
					unchanged = false
	check(unchanged, "Charakter erhält keinen Leucht-Zweitpass")
	visual._process(0)
	var material := visual._materials[0]
	check(material.get_shader_parameter("subject_count") == 2, "Beide Partymitglieder erhalten Sichtfenster")
	var follower := game.party.followers[0]
	var positions: PackedVector4Array = material.get_shader_parameter("subjects")
	check(is_equal_approx(positions[1].x, follower.global_position.x), "Zweites Fenster folgt Begleiter")
	check(game.party.move_member(follower, -1), "Anführerwechsel möglich")
	visual._process(0)
	positions = material.get_shader_parameter("subjects")
	check(is_equal_approx(positions[0].x, follower.global_position.x) and material.get_shader_parameter("subject_count") == 2, "Anführerwechsel behält beide Fenster")
	follower.hide()
	visual._process(0)
	check(material.get_shader_parameter("subject_count") == 1, "Unsichtbare Mitglieder erzeugen kein Fenster")
	follower.show()
	game.party.followers.erase(player)
	visual._process(0)
	check(material.get_shader_parameter("subject_count") == 1, "Ausgetretenes Mitglied erzeugt kein Fenster")
	game.party.followers.append(player)
	# Echte Physikkollision für die neue raycast-gesteuerte Kapsel.
	var test_camera := Camera3D.new()
	game.add_child(test_camera)
	test_camera.position = Vector3(1000, 1, 6)
	var obstacle := StaticBody3D.new()
	obstacle.add_to_group("camera_occluder")
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.3)
	collider.shape = box
	obstacle.add_child(collider)
	game.add_child(obstacle)
	obstacle.position = Vector3(1000, 1, 3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hit := visual._occlusion_hit(player, test_camera, Vector3(1000, 1, 0))
	check(not hit.is_empty() and hit.collider == obstacle, "Strahltest findet verdeckende Wand")
	obstacle.remove_from_group("camera_occluder")
	check(visual._occlusion_hit(player, test_camera, Vector3(1000, 1, 0)).is_empty(), "Nicht markierte Objekte lösen kein Sichtfenster aus")
	obstacle.add_to_group("camera_occluder")
	obstacle.position.z = -3
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(visual._occlusion_hit(player, test_camera, Vector3(1000, 1, 0)).is_empty(), "Wand hinter Figur löst kein Sichtfenster aus")
	obstacle.free()
	test_camera.free()
	visual._restore()
	check(grid.mesh_library == original, "Abbau stellt Originalressourcen wieder her")
	game.free()
	print("movement_cutout: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
