extends Node

## Mit einem Rendering-Treiber ausführen (nicht --headless).
## Erzeugt statische Inventarbilder aus genau derselben Ansicht wie Welt und Hand.
const VISUAL := preload("res://src/resources/items/item_visual.gd")
@export var items: Array[String] = ["messer", "dolch", "schwert", "speer", "bogen", "pfeil"]
@export var output_directory: String = "res://assets/items/weapons/icons"
@export var model_rotation := Vector3(0, PI * 0.4, -0.45)
const ICON_SIZE := 256
var _views: Array[SubViewport] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output_directory)
	for key in items:
		var item := load("res://src/resources/items/" + key + ".tres") as ItemData
		var viewport := SubViewport.new()
		viewport.size = Vector2i.ONE * ICON_SIZE
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		add_child(viewport)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.65
		viewport.add_child(environment)
		var pivot := Node3D.new()
		viewport.add_child(pivot)
		var visual := VISUAL.create(item)
		var bounds := VISUAL.bounds(visual)
		visual.position = -bounds.get_center()
		pivot.add_child(visual)
		pivot.rotation = model_rotation
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -35, 0)
		light.light_energy = 1.2
		viewport.add_child(light)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)) * 1.25
		camera.position = Vector3(0, 0, 10)
		viewport.add_child(camera)
		camera.current = true
		_views.append(viewport)
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var sheet := Image.create(ICON_SIZE * 3, ICON_SIZE * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	var failed := false
	for index in items.size():
		var image := _views[index].get_texture().get_image()
		var path: String = output_directory.path_join(items[index]) + ".png"
		var error := image.save_png(path)
		failed = failed or error != OK or image.is_empty()
		print(items[index], " icon=", error, " ", image.get_size())
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(index % 3, index / 3) * ICON_SIZE)
	if "--preview" in OS.get_cmdline_user_args():
		sheet.save_png("res://.weapon-models-preview.png")
	get_tree().quit(1 if failed else 0)
