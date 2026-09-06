class_name PartyHudEntry extends HBoxContainer

var member: Playable

@onready var _name_label: Label = %NameLabel
@onready var _hp_label: Label = %HpLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _mp_label: Label = %MpLabel
@onready var _mp_bar: ProgressBar = %MpBar
@onready var _portrait: TextureRect = %Portrait
@onready var _portrait_label: Label = %PortraitLabel


func bind(playable: Playable) -> void:
	member = playable
	if member:
		_name_label.text = member.get_display_name()
		_apply_portrait()
	refresh()


## Portrait kommt aus CharacterResource.get_portrait() (Konvention siehe dort);
## ohne Datei bleibt der "?"-Platzhalter sichtbar statt eines leeren Rechtecks.
func _apply_portrait() -> void:
	var portrait: Texture2D = member.character.get_portrait() if member.character else null
	_portrait.texture = portrait
	_portrait_label.visible = portrait == null


func refresh() -> void:
	if member == null:
		return
	_hp_bar.max_value = member.get_max_health()
	_hp_bar.value = clampf(float(member.health), float(-member.get_max_health()), float(member.get_max_health()))
	_hp_label.text = "SP %d / %d" % [member.health, member.get_max_health()]
	_mp_bar.max_value = member.get_max_mana()
	_mp_bar.value = clampf(float(member.mana), float(-member.get_max_mana()), float(member.get_max_mana()))
	_mp_label.text = "KP %d / %d" % [member.mana, member.get_max_mana()]
