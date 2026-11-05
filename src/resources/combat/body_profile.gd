class_name CombatBodyProfile extends Resource

@export var profile_id: String = "human"
@export var default_zone_id: String = "torso"
@export var zones: Array[CombatBodyZone] = []
@export var front_evasion: float = 1.0
@export var side_evasion: float = 0.6
@export var rear_evasion: float = 0.25

func get_zone(id: String) -> CombatBodyZone:
	for zone in zones:
		if zone.zone_id == id:
			return zone
	return null
