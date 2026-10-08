extends Node3D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 2, 7)
	camera.look_at(Vector3(0, 1, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6
	camera.make_current()
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-35, -20, 0)
	var subject := MeshInstance3D.new()
	subject.mesh = SphereMesh.new()
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1, 0.05, 0.05)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	subject.material_override = red
	add_child(subject)
	subject.position = Vector3(0, 1, 0)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(5, 3, 0.3)
	wall.mesh = box
	var source := StandardMaterial3D.new()
	source.albedo_color = Color(0.8, 0.65, 0.1)
	var controller := OcclusionVisual.new()
	var material := controller._convert(source)
	wall.material_override = material
	add_child(wall)
	wall.position = Vector3(0, 1, 2)
	set_subject(material, Vector3(0, 1, 0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/necota-cutout-before.png")
	material.set_shader_parameter("cutout_enabled", true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image()
	result.save_png("/tmp/necota-cutout-after.png")
	var center := result.get_pixel(floori(result.get_width() * 0.5), floori(result.get_height() * 0.5))
	var success := center.r > center.g * 3.0
	print("cutout_render: character visible through wall = ", success)
	var companion := subject.duplicate() as MeshInstance3D
	add_child(companion)
	companion.position.x = 1.8
	var subjects := PackedVector4Array()
	subjects.resize(64)
	subjects[0] = Vector4(0, 1, 0, 0)
	subjects[1] = Vector4(1.8, 1, 0, 0)
	material.set_shader_parameter("subjects", subjects)
	material.set_shader_parameter("subject_count", 2)
	var hits := PackedVector4Array()
	hits.resize(64)
	hits[0] = Vector4(0, 1, 2, 1.5)
	hits[1] = Vector4(1.8, 1, 2, 1.5)
	material.set_shader_parameter("cutout_hits", hits)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var party_image := get_viewport().get_texture().get_image()
	party_image.save_png("/tmp/necota-cutout-party.png")
	for member in [subject, companion]:
		var screen := camera.unproject_position(member.global_position) * Vector2(party_image.get_size()) / get_viewport().get_visible_rect().size
		var pixel := party_image.get_pixel(int(screen.x), int(screen.y))
		success = success and pixel.r > pixel.g * 3.0
	print("cutout_render: both party members visible = ", success)
	companion.queue_free()
	set_subject(material, subject.position)
	# Kamera und Figur ändern sich jedes Bild; kein CPU-Kamerawert im Material.
	for i in range(8):
		subject.position.x = sin(float(i)) * 0.5
		camera.position = Vector3(subject.position.x, 2 + i * 0.1, 7 + i * 0.2)
		camera.look_at(subject.position)
		camera.size = 5 + i * 0.3
		set_subject(material, subject.position)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var moving := get_viewport().get_texture().get_image()
		var pixel := moving.get_pixel(floori(moving.get_width() * 0.5), floori(moving.get_height() * 0.5))
		success = success and pixel.r > pixel.g * 3.0
	print("cutout_render: movement and zoom = ", success)
	subject.position = Vector3(0, 1, 0)
	camera.position = Vector3(0, 2, 7)
	camera.look_at(subject.position)
	camera.size = 6
	set_subject(material, subject.position)
	# Wand hinter der Figur darf kein Sichtfenster erhalten.
	wall.position.z = -2
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var behind := get_viewport().get_texture().get_image()
	var side := behind.get_pixel(floori(behind.get_width() * 0.59), floori(behind.get_height() * 0.5))
	success = success and side.r > side.b * 2.0 and side.g > side.b * 2.0
	print("cutout_render: wall behind subject intact = ", success)
	# Obergeschoss verdeckt die Figur von oben und muss ausgeschnitten werden.
	box.size = Vector3(6, 0.2, 6)
	wall.position = Vector3(0, 3, 0)
	camera.position = Vector3(0, 8, 0)
	camera.look_at(subject.position, Vector3.BACK)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var ceiling := get_viewport().get_texture().get_image()
	var ceiling_center := ceiling.get_pixel(floori(ceiling.get_width() * 0.5), floori(ceiling.get_height() * 0.5))
	success = success and ceiling_center.r > ceiling_center.g * 3.0
	print("cutout_render: upper floor cutout = ", success)
	# Laufboden im vorderen Bereich des Kreises darf nicht verschwinden.
	wall.position = Vector3(0, -0.1, 0)
	camera.position = Vector3(0, 6, 6)
	camera.look_at(Vector3.ZERO)
	set_subject(material, Vector3(0, 0.7, 0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var ground := get_viewport().get_texture().get_image()
	var ground_screen := camera.unproject_position(Vector3(0, 0, 1.3)) * Vector2(ground.get_size()) / get_viewport().get_visible_rect().size
	var ground_pixel := ground.get_pixel(int(ground_screen.x), int(ground_screen.y))
	success = success and ground_pixel.r > ground_pixel.b * 2.0 and ground_pixel.g > ground_pixel.b * 2.0
	print("cutout_render: standing floor intact = ", success)
	controller.free()
	wall.queue_free()
	subject.queue_free()
	camera.queue_free()
	sun.queue_free()
	await get_tree().process_frame
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/necota-cutout-game.png")
	game.free()
	get_tree().quit(0 if success else 1)

func set_subject(material: ShaderMaterial, position: Vector3) -> void:
	var subjects := PackedVector4Array()
	subjects.resize(64)
	subjects[0] = Vector4(position.x, position.y, position.z, 0.0)
	material.set_shader_parameter("subjects", subjects)
	material.set_shader_parameter("subject_count", 1)
	var hits := PackedVector4Array()
	hits.resize(64)
	hits[0] = Vector4(position.x, position.y, position.z, 1.5)
	material.set_shader_parameter("cutout_hits", hits)
