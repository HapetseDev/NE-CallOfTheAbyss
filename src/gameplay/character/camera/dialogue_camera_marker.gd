class_name DialogueCameraMarker
extends Marker3D

## Optionaler Marker unter DialogueCameraPoints.
## Der Node-Name reicht bereits (Close, Medium, …); dieses Script ergänzt Shot-Typ und Gewicht.

@export var shot: CameraShot.Kind = CameraShot.Kind.CLOSE
@export var weight: float = 1.0
