class_name CombatLogHud extends PanelContainer

## Zeigt, welcher Kampfteilnehmer gerade was tut (Text aus CombatNarrator),
## als gestapelte, einzeln ausblendende Zeilen – ereignisgetrieben über
## CombatSession.action_resolved statt gepollt wie PartyHud.

const MAX_VISIBLE_LINES := 6
const LINE_LIFETIME_SEC := 4.0
const LINE_FADE_SEC := 0.6

var _manager: CombatManager
var _session: CombatSession

@onready var _list: VBoxContainer = %List


func _ready() -> void:
	visible = false


func bind(manager: CombatManager) -> void:
	_manager = manager
	if _manager == null:
		return
	if not _manager.combat_started.is_connected(_on_combat_started):
		_manager.combat_started.connect(_on_combat_started)
	if not _manager.combat_ended.is_connected(_on_combat_ended):
		_manager.combat_ended.connect(_on_combat_ended)


func _on_combat_started(session: CombatSession) -> void:
	_session = session
	visible = true
	_clear_lines()
	if not session.action_resolved.is_connected(_on_action_resolved):
		session.action_resolved.connect(_on_action_resolved)


func _on_combat_ended(_session: CombatSession, _outcome: Dictionary) -> void:
	_session = null
	visible = false
	_clear_lines()


func _on_action_resolved(actor: CombatParticipant, action: CombatAction, result: CombatActionResult) -> void:
	for line in CombatNarrator.describe(actor, action, result):
		_push_line(line)


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


func _clear_lines() -> void:
	for child in _list.get_children():
		child.queue_free()
