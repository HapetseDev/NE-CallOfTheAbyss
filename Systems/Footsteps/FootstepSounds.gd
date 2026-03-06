class_name FootstepSounds extends Resource

# Sound-Arrays für jeden Oberflächentyp
# Mehrere Sounds pro Typ für Variation

@export var grass_sounds: Array[AudioStream] = []
@export var stone_sounds: Array[AudioStream] = []
@export var wood_sounds: Array[AudioStream] = []
@export var sand_sounds: Array[AudioStream] = []
@export var water_sounds: Array[AudioStream] = []
@export var metal_sounds: Array[AudioStream] = []
@export var dirt_sounds: Array[AudioStream] = []
@export var snow_sounds: Array[AudioStream] = []
@export var default_sounds: Array[AudioStream] = []

# Lautstärke-Modifikatoren pro Oberfläche
@export var grass_volume_db: float = -5.0
@export var stone_volume_db: float = 0.0
@export var wood_volume_db: float = -2.0
@export var sand_volume_db: float = -8.0
@export var water_volume_db: float = 0.0
@export var metal_volume_db: float = 2.0
@export var dirt_volume_db: float = -3.0
@export var snow_volume_db: float = -6.0
@export var default_volume_db: float = 0.0


# Gibt einen zufälligen Sound für den Oberflächentyp zurück
func get_random_sound(surface_type: SurfaceType.Type) -> AudioStream:
	var sounds = _get_sounds_for_type(surface_type)
	if sounds.is_empty():
		sounds = default_sounds
	if sounds.is_empty():
		return null
	return sounds[randi() % sounds.size()]


# Gibt die Lautstärke für den Oberflächentyp zurück
func get_volume_db(surface_type: SurfaceType.Type) -> float:
	match surface_type:
		SurfaceType.Type.GRASS: return grass_volume_db
		SurfaceType.Type.STONE: return stone_volume_db
		SurfaceType.Type.WOOD: return wood_volume_db
		SurfaceType.Type.SAND: return sand_volume_db
		SurfaceType.Type.WATER: return water_volume_db
		SurfaceType.Type.METAL: return metal_volume_db
		SurfaceType.Type.DIRT: return dirt_volume_db
		SurfaceType.Type.SNOW: return snow_volume_db
		_: return default_volume_db


func _get_sounds_for_type(surface_type: SurfaceType.Type) -> Array[AudioStream]:
	match surface_type:
		SurfaceType.Type.GRASS: return grass_sounds
		SurfaceType.Type.STONE: return stone_sounds
		SurfaceType.Type.WOOD: return wood_sounds
		SurfaceType.Type.SAND: return sand_sounds
		SurfaceType.Type.WATER: return water_sounds
		SurfaceType.Type.METAL: return metal_sounds
		SurfaceType.Type.DIRT: return dirt_sounds
		SurfaceType.Type.SNOW: return snow_sounds
		_: return default_sounds
