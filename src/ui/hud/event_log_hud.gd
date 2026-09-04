class_name EventLogHud extends PanelContainer

## Zeigt projektweite Ereignis-Zeilen (Kampf, Gegenstände aufheben, Dialog, …)
## – hört direkt auf EventLog.event_logged (Autoload), immer sichtbar, kein
## Kampf-Binding nötig. Ehemals CombatLogHud (nur Kampf, an CombatManager
## gebunden). Neueste Zeile ganz oben, ältere werden nach unten verdrängt und
## bleiben (bis MAX_ENTRIES) stehen statt nach ein paar Sekunden auszublenden
## – scrollbar über den ScrollContainer, an dessen rechtem Rand Godot bei
## Bedarf automatisch die vertikale Scrollbar einblendet.

const MAX_ENTRIES := 100

@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List


func _ready() -> void:
	if not EventLog.event_logged.is_connected(_on_event_logged):
		EventLog.event_logged.connect(_on_event_logged)


func _on_event_logged(text: String) -> void:
	_push_line(text)


func _push_line(text: String) -> void:
	var was_at_top := _scroll.scroll_vertical <= 0
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 13)
	label.add_theme_color_override(&"font_color", Color(0.92, 0.92, 0.88, 1))
	_list.add_child(label)
	_list.move_child(label, 0)
	while _list.get_child_count() > MAX_ENTRIES:
		var oldest := _list.get_child(_list.get_child_count() - 1)
		_list.remove_child(oldest)
		oldest.queue_free()
	if was_at_top:
		await get_tree().process_frame
		_scroll.scroll_vertical = 0
