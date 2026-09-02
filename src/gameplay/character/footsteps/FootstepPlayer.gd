class_name FootstepPlayer extends Node3D

# Schrittgeräusche-System
# Erkennt Oberflächen per Raycast und spielt passende Sounds ab

signal footstep_played(surface_type: SurfaceType.Type)

@export var footstep_sounds: FootstepSounds
@export var step_interval: float = 0.35  # Zeit zwischen Schritten (normal)
@export var sprint_step_interval: float = 0.25  # Zeit zwischen Schritten (Sprint)
@export var raycast_length: float = 2.0  # Länge des Raycasts nach unten
@export var pitch_variation: float = 0.1  # Zufällige Tonhöhenvariation
@export var enabled: bool = true

var audio_player: AudioStreamPlayer3D
var step_timer: float = 0.0
var is_moving: bool = false
var is_sprinting: bool = false
var current_surface: SurfaceType.Type = SurfaceType.Type.DEFAULT
var ray_query: PhysicsRayQueryParameters3D


func _ready() -> void:
	# Audio Player erstellen
	audio_player = AudioStreamPlayer3D.new()
	audio_player.max_polyphony = 4
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	audio_player.max_distance = 20.0
	add_child(audio_player)

	# Raycast Query vorbereiten
	ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.collision_mask = 1  # Ground layer


func _process(delta: float) -> void:
	if not enabled or not is_moving:
		return

	step_timer -= delta

	if step_timer <= 0:
		_detect_surface()
		_play_footstep()
		step_timer = sprint_step_interval if is_sprinting else step_interval


# Wird vom Walk-State aufgerufen
func start_walking(sprinting: bool = false) -> void:
	is_moving = true
	is_sprinting = sprinting
	step_timer = 0.1  # Kurze Verzögerung vor erstem Schritt


func stop_walking() -> void:
	is_moving = false
	step_timer = 0.0


func set_sprinting(sprinting: bool) -> void:
	is_sprinting = sprinting


func _detect_surface() -> void:
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return

	var from = global_position + Vector3(0, 0.5, 0)
	var to = global_position + Vector3(0, -raycast_length, 0)

	ray_query.from = from
	ray_query.to = to

	var result = space_state.intersect_ray(ray_query)

	if result:
		var collider = result.collider

		# Prüfe auf surface_type Metadaten
		if collider.has_meta("surface_type"):
			var surface_name = collider.get_meta("surface_type")
			current_surface = SurfaceType.from_string(surface_name)
		# Prüfe auf Gruppen
		elif collider.is_in_group("grass"):
			current_surface = SurfaceType.Type.GRASS
		elif collider.is_in_group("stone"):
			current_surface = SurfaceType.Type.STONE
		elif collider.is_in_group("wood"):
			current_surface = SurfaceType.Type.WOOD
		elif collider.is_in_group("water"):
			current_surface = SurfaceType.Type.WATER
		else:
			current_surface = SurfaceType.Type.DEFAULT
	else:
		current_surface = SurfaceType.Type.DEFAULT


func _play_footstep() -> void:
	if not footstep_sounds:
		return

	var sound = footstep_sounds.get_random_sound(current_surface)
	if not sound:
		return

	audio_player.stream = sound
	audio_player.volume_db = footstep_sounds.get_volume_db(current_surface)
	audio_player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	audio_player.play()

	footstep_played.emit(current_surface)


# Manuell einen Schritt auslösen (z.B. von Animation Event)
func play_step() -> void:
	_detect_surface()
	_play_footstep()
