class_name DialogueCameraMarker
extends Marker3D

## Optionaler Marker unter DialogueCameraPoints.
## Der Node-Name reicht bereits (Close, Medium, …); dieses Script ergänzt Shot-Typ, Gewicht, Tags und FOV.

@export var shot: CameraShot.Kind = CameraShot.Kind.CLOSE
@export var weight: float = 1.0
@export var tags: PackedStringArray = PackedStringArray()

@export_group("Kamera")
## 0 = aktuellen FOV der Dialogkamera behalten.
@export_range(0.0, 179.0, 0.5, "or_greater", "suffix:°") var fov: float = CameraShot.INHERIT_FOV
## < 0 = CameraSystem.dialogue_transition_sec. 0 = sofort.
@export var transition_sec: float = CameraShot.DEFAULT_TRANSITION_SEC
@export var transition_ease: CameraShot.TransitionEase = CameraShot.TransitionEase.DEFAULT
