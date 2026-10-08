class_name PartyHud extends PanelContainer

const ENTRY_SCENE := preload("res://src/ui/hud/party_hud_entry.tscn")

@export_group("Bewegungs-Fade")
@export var fade_delay_sec: float = 1.2
@export var fade_in_duration_sec: float = 2.5
@export var fade_out_duration_sec: float = 0.8
@export_range(0.0, 1.0, 0.05) var min_opacity: float = 0.25

var world_tracking := false
var _world_panels: Array[PanelContainer] = []
var _party: Party
var _entries: Array[PartyHudEntry] = []
var _moving_time: float = 0.0
var _current_opacity: float = 1.0

@onready var _row: HBoxContainer = %Row


func _ready() -> void:
	modulate.a = 1.0
	if _party:
		_rebuild_entries()


func setup(party: Party) -> void:
	_party = party
	if is_node_ready():
		_rebuild_entries()


## Baut die Anzeige neu auf, ohne die gebundene Party zu wechseln – z.B.
## nachdem PartyOrderUI die Reihenfolge oder den Anführer geändert hat.
func rebuild() -> void:
	if is_node_ready():
		_rebuild_entries()


func _rebuild_entries() -> void:
	for panel in _world_panels:
		panel.get_parent().remove_child(panel)
		panel.queue_free()
	_world_panels.clear()
	for entry in _entries:
		if not world_tracking:
			entry.queue_free()
	_entries.clear()
	if _party == null:
		return
	for member in _party.get_all_members():
		var entry := ENTRY_SCENE.instantiate() as PartyHudEntry
		if world_tracking:
			var panel := PanelContainer.new()
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			get_parent().add_child(panel)
			panel.add_child(entry)
			_world_panels.append(panel)
		else:
			_row.add_child(entry)
		entry.bind(member)
		_entries.append(entry)


func refresh() -> void:
	for entry in _entries:
		entry.refresh()


func _process(delta: float) -> void:
	refresh()
	if world_tracking:
		self_modulate.a = 0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var camera := get_viewport().get_camera_3d()
		for index in _world_panels.size():
			var panel := _world_panels[index]
			var member := _entries[index].member
			panel.visible = camera != null and is_instance_valid(member) and not camera.is_position_behind(member.global_position)
			if panel.visible:
				var screen := camera.unproject_position(member.global_position + Vector3.UP * 1.4)
				panel.size = panel.get_combined_minimum_size()
				panel.position = (screen - Vector2(panel.size.x * 0.5, panel.size.y)).clamp(Vector2.ZERO, get_viewport_rect().size - panel.size)
				for earlier in range(index):
					var other := _world_panels[earlier]
					if other.visible and panel.get_rect().intersects(other.get_rect()):
						var left := screen.x < other.position.x + other.size.x * 0.5
						panel.position.x = other.position.x - panel.size.x - NEDimensions.SPACING_S if left else other.position.x + other.size.x + NEDimensions.SPACING_S
						panel.position.x = clampf(panel.position.x, 0, get_viewport_rect().size.x - panel.size.x)
	else:
		_update_movement_fade(delta)


func _update_movement_fade(delta: float) -> void:
	if _party == null:
		return
	if _party.is_moving():
		_moving_time += delta
		if _moving_time <= fade_delay_sec:
			_current_opacity = move_toward(_current_opacity, 1.0, delta / maxf(fade_out_duration_sec, 0.001))
		elif fade_in_duration_sec <= 0.0:
			_current_opacity = min_opacity
		else:
			var fade_progress := clampf((_moving_time - fade_delay_sec) / fade_in_duration_sec, 0.0, 1.0)
			_current_opacity = lerpf(1.0, min_opacity, fade_progress)
	else:
		_moving_time = 0.0
		if fade_out_duration_sec <= 0.0:
			_current_opacity = 1.0
		else:
			_current_opacity = move_toward(_current_opacity, 1.0, delta / fade_out_duration_sec)
	modulate.a = _current_opacity


func _exit_tree() -> void:
	for panel in _world_panels:
		if is_instance_valid(panel):
			panel.queue_free()
