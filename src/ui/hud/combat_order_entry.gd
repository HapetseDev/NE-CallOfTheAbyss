class_name CombatOrderEntry extends HBoxContainer

var participant: CombatParticipant

@onready var _name_label: Label = %NameLabel
@onready var _readiness_bar: ProgressBar = %ReadinessBar


func bind(p: CombatParticipant) -> void:
	participant = p
	refresh(false)


func refresh(is_active: bool) -> void:
	if participant == null or participant.playable == null:
		return
	var ratio := participant.initiative_meter / CombatBalance.INITIATIVE_THRESHOLD
	_readiness_bar.value = clampf(ratio, 0.0, 1.0) * 100.0
	_name_label.add_theme_color_override(&"font_color", _name_color())
	var display_name := participant.playable.get_display_name()
	_name_label.text = ("► %s" % display_name) if is_active else display_name
	modulate.a = 1.0 if is_active else 0.75


func _name_color() -> Color:
	if _is_own_party(participant.playable):
		return Color(0.45, 0.8, 0.5, 1)
	return Color(0.85, 0.4, 0.35, 1)


func _is_own_party(playable: Playable) -> bool:
	return playable is Player or playable is PartyFollower
