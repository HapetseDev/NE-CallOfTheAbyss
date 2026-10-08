class_name PartyFollower extends Player

## Startet als Begleiter, kann von Party zum steuerbaren Anführer werden.
func _init() -> void:
	super._init()
	is_player_controlled = false
