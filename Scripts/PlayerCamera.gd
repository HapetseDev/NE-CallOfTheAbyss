class_name PlayerCamera extends Camera3D

@export var follow_distance : float = 8.0  # Abstand zum Spieler
@export var camera_height : float = 6.0    # Höhe der Kamera
@export var pitch_angle : float = -45.0    # Neigungswinkel (Mode7-Stil: -30 bis -60)
@export var smooth_speed : float = 5.0     # Glättung der Kamerabewegung
@export var look_ahead_distance : float = 3.0  # Maximaler Versatz in Blickrichtung

# Goldener Schnitt: 1 / 1.618 ≈ 0.618 (größerer Teil) und 0.382 (kleinerer Teil)
const GOLDEN_RATIO : float = 0.618

var target : Node3D
var current_offset : Vector3 = Vector3.ZERO
var target_look_offset : Vector3 = Vector3.ZERO

func _ready() -> void:
	target = get_parent()
	# Initiale Position setzen
	if target:
		_update_camera_position(1.0)
		# Verbinde Signal für Richtungsänderung
		if target.has_signal("direction_changed"):
			target.direction_changed.connect(_on_direction_changed)
	pass

func _process(delta: float) -> void:
	if target:
		_update_camera_position(delta)
	pass

func _on_direction_changed(new_direction: Vector3) -> void:
	# Berechne Offset basierend auf Blickrichtung und goldenem Schnitt
	# Der Spieler wird im kleineren Teil (38.2%) positioniert,
	# sodass mehr Raum (61.8%) in Blickrichtung sichtbar ist
	target_look_offset = new_direction * look_ahead_distance * GOLDEN_RATIO

func _update_camera_position(delta: float) -> void:
	# Sanfte Interpolation des Blickrichtungs-Offsets
	current_offset = current_offset.lerp(target_look_offset, smooth_speed * 0.5 * delta)

	# Position: hinter und über dem Spieler, mit Blickrichtungs-Offset
	var base_offset = Vector3(
		0,
		camera_height,
		follow_distance
	)

	# Kombiniere Basis-Offset mit Blickrichtungs-Offset
	# Der Offset verschiebt die Kamera in Blickrichtung des Spielers
	var look_offset_3d = Vector3(current_offset.x, 0, current_offset.z)

	var target_position = target.global_position + base_offset + look_offset_3d

	# Sanfte Interpolation zur Zielposition
	global_position = global_position.lerp(target_position, smooth_speed * delta)

	# Kamera auf Spieler ausrichten mit festem Neigungswinkel
	rotation_degrees = Vector3(pitch_angle, 0, 0)
