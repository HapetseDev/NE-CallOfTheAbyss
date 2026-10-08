class_name Party extends Node3D

var leader: Player
var followers: Array[Player] = []

var _hud_layer: CanvasLayer
var _game_hud: PartyHud


func _ready() -> void:
	_find_party_members()
	_restore_saved_members()
	_wire_followers()
	var occlusion := OcclusionVisual.new()
	occlusion.name = "OcclusionVisual"
	add_child(occlusion)
	capture_state()


func get_all_members() -> Array[Playable]:
	var members: Array[Playable] = []
	if leader:
		members.append(leader)
	for follower in followers:
		members.append(follower)
	return members


func bind_hud(hud: PartyHud, layer: CanvasLayer = null, top_offset: float = 16.0) -> void:
	_game_hud = hud
	_hud_layer = layer
	_setup_game_hud(top_offset)


func get_party_hud() -> PartyHud:
	return _game_hud


## Verschiebt einen Follower um `delta` Plätze innerhalb der Marschreihenfolge
## (negativ = nach vorn, positiv = nach hinten). Der Anführer (Index 0 in
## get_all_members()) ist davon nicht betroffen.
func move_follower(follower: Player, delta: int) -> void:
	var index := followers.find(follower)
	if index == -1:
		return
	var new_index := clampi(index + delta, 0, followers.size() - 1)
	if new_index == index:
		return
	followers.remove_at(index)
	followers.insert(new_index, follower)
	capture_state()
	if _game_hud:
		_game_hud.rebuild()


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
		if child is Player:
			if child.is_player_controlled and leader == null:
				leader = child
			else:
				followers.append(child)


func _wire_followers() -> void:
	if leader == null:
		push_warning("Party: Kein Party-Leader (Player) gefunden.")
		return
	leader.set_player_controlled(true)
	for follower in followers:
		follower.set_player_controlled(false)
		follower.set_leader(leader)


func _setup_game_hud(top_offset: float) -> void:
	if _game_hud == null:
		return
	_game_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_game_hud.offset_left = 16.0
	_game_hud.offset_top = top_offset
	_game_hud.setup(self)


## Spielzustand nur aus tatsächlich gebundenen, registrierten Figuren erfassen.
func capture_state() -> bool:
	if not is_instance_valid(leader) or leader.character == null:
		return false
	for child in get_children():
		if child is Playable and not get_all_members().has(child):
			return false
	var ids: Array = []
	for member in get_all_members():
		if not is_instance_valid(member) or member.is_queued_for_deletion() or member.get_parent() != self or member.character == null:
			return false
		if GameState.character_registry.get_character(member.character.character_id) != member.character:
			return false
		ids.append(member.character.character_id)
	var data := {"leader_id": leader.character.character_id, "member_ids": ids}
	if not preload("res://src/core/world/party_state.gd").valid(data, GameState.character_registry):
		return false
	GameState.world_state.party_state = data
	return true


func _restore_saved_members() -> void:
	var saved := GameState.world_state.party_state
	if saved.is_empty():
		return
	if not preload("res://src/core/world/party_state.gd").valid(saved, GameState.character_registry):
		push_error("Party: Gespeicherte Besetzung wird nicht unterstützt.")
		return
	var by_id: Dictionary = {}
	var members := get_all_members()
	for member in members:
		by_id[member.character.character_id] = member
	for id in saved.member_ids:
		if not by_id.has(id):
			push_error("Party: Gespeicherte Figur fehlt in der Partyszene.")
			return
	leader = by_id[saved.leader_id]
	followers.clear()
	for id in saved.member_ids:
		if id != saved.leader_id:
			followers.append(by_id[id])
	for member in members:
		if not saved.member_ids.has(member.character.character_id):
			remove_child(member)
			member.free()


func can_reorder() -> bool:
	if get_tree().paused or GameState.is_player_input_locked():
		return false
	if CombatManager.instance and CombatManager.instance.active_session != null:
		return false
	for member in get_all_members():
		if member.is_in_combat_mode():
			return false
	return true


## Der erste Platz bestimmt die steuerbare Figur. Kein Austausch von Nodes/Daten.
func move_member(member: Player, delta: int) -> bool:
	if not can_reorder():
		return false
	var members := get_all_members()
	var index := members.find(member)
	if index < 0:
		return false
	var destination := clampi(index + delta, 0, members.size() - 1)
	if index == destination:
		return false
	members.remove_at(index)
	members.insert(destination, member)
	if members[0].is_character_dead():
		return false
	var old_leader := leader
	var old_followers := followers.duplicate()
	leader = members[0] as Player
	followers.clear()
	for i in range(1, members.size()):
		followers.append(members[i] as Player)
	if not capture_state():
		leader = old_leader
		followers.assign(old_followers)
		return false
	_wire_followers()
	if CameraSystem.instance:
		CameraSystem.instance.set_target(leader, true)
	set_game_hud_visible(true)
	if _game_hud:
		_game_hud.rebuild()
	return true
