class_name PartyHud extends PanelContainer

const ENTRY_SCENE := preload("res://src/ui/hud/party_hud_entry.tscn")

@export_group("Bewegungs-Fade")
@export var fade_delay_sec: float = 1.2
@export var fade_in_duration_sec: float = 2.5
@export var fade_out_duration_sec: float = 0.8
@export_range(0.0, 1.0, 0.05) var min_opacity: float = 0.25

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
## nachdem PartyOrderUI die Marschreihenfolge der Follower geändert hat.
func rebuild() -> void:
	if is_node_ready():
		_rebuild_entries()


func _rebuild_entries() -> void:
	for entry in _entries:
		entry.queue_free()
	_entries.clear()
	if _party == null:
		return
	for member in _party.get_all_members():
		var entry := ENTRY_SCENE.instantiate() as PartyHudEntry
		_row.add_child(entry)
		entry.bind(member)
		_entries.append(entry)


func refresh() -> void:
	for entry in _entries:
		entry.refresh()


func _process(delta: float) -> void:
	refresh()
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
