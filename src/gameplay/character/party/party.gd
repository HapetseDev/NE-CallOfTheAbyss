class_name Party extends Node3D

var leader: Player
var followers: Array[PartyFollower] = []

var _hud_layer: CanvasLayer
var _game_hud: PartyHud


func _ready() -> void:
	_find_party_members()
	_wire_followers()


func get_all_members() -> Array[Playable]:
	var members: Array[Playable] = []
	if leader:
		members.append(leader)
	for follower in followers:
		members.append(follower)
	return members


func bind_hud(hud: PartyHud, layer: CanvasLayer = null) -> void:
	_game_hud = hud
	_hud_layer = layer
	_setup_game_hud()


func get_party_hud() -> PartyHud:
	return _game_hud


func set_game_hud_visible(hud_visible: bool) -> void:
	if _hud_layer:
		_hud_layer.visible = hud_visible
	elif _game_hud:
		_game_hud.visible = hud_visible


func is_moving() -> bool:
	const MOVING_EPSILON_SQ := 0.02
	for member in get_all_members():
		if member.direction.length_squared() > MOVING_EPSILON_SQ:
			return true
		var horizontal := Vector3(member.velocity.x, 0.0, member.velocity.z)
		if horizontal.length_squared() > MOVING_EPSILON_SQ:
			return true
	return false


func _find_party_members() -> void:
	for child in get_children():
		if child is Player and leader == null:
			leader = child as Player
		elif child is PartyFollower:
			followers.append(child as PartyFollower)


func _wire_followers() -> void:
	if leader == null:
		push_warning("Party: Kein Party-Leader (Player) gefunden.")
		return
	for follower in followers:
		follower.set_leader(leader)


func _setup_game_hud() -> void:
	if _game_hud == null:
		return
	_game_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_game_hud.offset_left = 16.0
	_game_hud.offset_top = 16.0
	_game_hud.setup(self)
