class_name EventLogHud extends PanelContainer

## Zeigt projektweite Ereignis-Zeilen (Kampf, Gegenstände aufheben, Dialog, …)
## als gestapelte, einzeln ausblendende Zeilen – hört direkt auf
## EventLog.event_logged (Autoload), immer sichtbar, kein Kampf-Binding mehr
## nötig. Ehemals CombatLogHud (nur Kampf, an CombatManager gebunden).

const MAX_VISIBLE_LINES := 6
const LINE_LIFETIME_SEC := 4.0
const LINE_FADE_SEC := 0.6

@onready var _list: VBoxContainer = %List


func _ready() -> void:
	if not EventLog.event_logged.is_connected(_on_event_logged):
		EventLog.event_logged.connect(_on_event_logged)


func _on_event_logged(text: String) -> void:
	_push_line(text)


func _push_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 13)
	label.add_theme_color_override(&"font_color", Color(0.92, 0.92, 0.88, 1))
	_list.add_child(label)
	while _list.get_child_count() > MAX_VISIBLE_LINES:
		var oldest := _list.get_child(0)
		_list.remove_child(oldest)
		oldest.queue_free()
	var tween := create_tween()
	tween.tween_interval(LINE_LIFETIME_SEC)
	tween.tween_property(label, "modulate:a", 0.0, LINE_FADE_SEC)
	tween.tween_callback(label.queue_free)
