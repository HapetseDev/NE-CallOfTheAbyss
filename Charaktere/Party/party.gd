class_name Party extends Node3D

var leader: Player
var followers: Array[PartyFollower] = []


func _ready() -> void:
	_find_party_members()
	_wire_followers()


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
