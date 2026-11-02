extends Node

## Local preferences, independent of save games and session resets.
signal changed
const SETTINGS_PATH := "user://graphics.cfg"
enum Quality { OFF, SIMPLE, HIGH }
const RESOLUTIONS := [1.0, 0.85, 0.7, 0.5]
var cutout_quality := Quality.HIGH
var shadow_quality := Quality.HIGH
var resolution_index := 0
var cutout_enabled: bool:
	get: return cutout_quality != Quality.OFF
var shadows_enabled: bool:
	get: return shadow_quality != Quality.OFF
var reduced_resolution: bool:
	get: return resolution_index != 0
var _lights: Array[WeakRef] = []
var _original_shadow_filter := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", RenderingServer.SHADOW_QUALITY_SOFT_LOW))

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		load_preferences(config)
	get_tree().node_added.connect(_on_node_added)
	_apply_resolution()
	_apply_shadow_filter()

func load_preferences(config: ConfigFile) -> void:
	# Migrate the original boolean preferences without re-enabling disabled effects.
	cutout_quality = clampi(int(config.get_value("graphics", "cutout_quality", 2 if config.get_value("graphics", "cutout", true) else 0)), 0, 2)
	shadow_quality = clampi(int(config.get_value("graphics", "shadow_quality", 2 if config.get_value("graphics", "shadows", true) else 0)), 0, 2)
	resolution_index = clampi(int(config.get_value("graphics", "resolution_index", 2 if config.get_value("graphics", "reduced_resolution", false) else 0)), 0, 3)

func set_option(option: String, value: Variant) -> void:
	match option:
		"cutout": cutout_quality = Quality.HIGH if value else Quality.OFF
		"shadows": shadow_quality = Quality.HIGH if value else Quality.OFF
		"reduced_resolution": resolution_index = 2 if value else 0
		"cutout_quality": cutout_quality = clampi(int(value), 0, 2)
		"shadow_quality": shadow_quality = clampi(int(value), 0, 2)
		"resolution_index": resolution_index = clampi(int(value), 0, 3)
		_: return
	_apply_resolution()
	_apply_shadow_filter()
	for index in range(_lights.size() - 1, -1, -1):
		var light = _lights[index].get_ref()
		if not is_instance_valid(light):
			_lights.remove_at(index)
		else:
			_apply_light(light)
	changed.emit()
	var config := ConfigFile.new()
	config.set_value("graphics", "cutout", cutout_enabled)
	config.set_value("graphics", "shadows", shadows_enabled)
	config.set_value("graphics", "reduced_resolution", reduced_resolution)
	config.set_value("graphics", "cutout_quality", cutout_quality)
	config.set_value("graphics", "shadow_quality", shadow_quality)
	config.set_value("graphics", "resolution_index", resolution_index)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Grafikeinstellungen konnten nicht gespeichert werden: " + error_string(error))

func _apply_resolution() -> void:
	var scale: float = RESOLUTIONS[resolution_index]
	ProjectSettings.set_setting("rendering/scaling_3d/scale", scale)
	RenderingServer.viewport_set_scaling_3d_scale(get_tree().root.get_viewport_rid(), scale)

func _apply_shadow_filter() -> void:
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD if shadow_quality == Quality.SIMPLE else _original_shadow_filter)

func _on_node_added(node: Node) -> void:
	if node is Light3D:
		_register_light.call_deferred(weakref(node))

func _register_light(reference: WeakRef) -> void:
	var light = reference.get_ref()
	if not is_instance_valid(light) or not light.is_inside_tree():
		return
	if not light.has_meta("graphics_original_shadow"):
		light.set_meta("graphics_original_shadow", light.shadow_enabled)
		if light is DirectionalLight3D:
			light.set_meta("graphics_original_distance", light.directional_shadow_max_distance)
			light.set_meta("graphics_original_mode", light.directional_shadow_mode)
	_lights.append(reference)
	_apply_light(light)

func _apply_light(light: Light3D) -> void:
	light.shadow_enabled = shadows_enabled and bool(light.get_meta("graphics_original_shadow", false))
	if shadow_quality == Quality.SIMPLE and not light is DirectionalLight3D:
		light.shadow_enabled = false
	if light is DirectionalLight3D:
		var simple := shadow_quality == Quality.SIMPLE
		light.directional_shadow_max_distance = minf(float(light.get_meta("graphics_original_distance")), 30.0) if simple else float(light.get_meta("graphics_original_distance"))
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if simple else int(light.get_meta("graphics_original_mode"))
