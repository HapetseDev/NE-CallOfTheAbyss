class_name PartyHudEntry extends HBoxContainer

var member: Playable

@onready var _name_label: Label = %NameLabel
@onready var _hp_label: Label = %HpLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _mp_label: Label = %MpLabel
@onready var _mp_bar: ProgressBar = %MpBar


func bind(playable: Playable) -> void:
	member = playable
	if member:
		_name_label.text = member.get_display_name()
	refresh()


func refresh() -> void:
	if member == null:
		return
	_hp_bar.max_value = member.get_max_health()
	_hp_bar.value = clampf(float(member.health), float(-member.get_max_health()), float(member.get_max_health()))
	_hp_label.text = "SP %d / %d" % [member.health, member.get_max_health()]
	_mp_bar.max_value = member.get_max_mana()
	_mp_bar.value = clampf(float(member.mana), float(-member.get_max_mana()), float(member.get_max_mana()))
	_mp_label.text = "KP %d / %d" % [member.mana, member.get_max_mana()]
