# Basisklasse für alle interaktiven Objekte in der Welt.
# Abgeleitete Klassen überschreiben get_actions() und perform_action().
class_name Interactable extends Node3D


func _ready() -> void:
	add_to_group("interactable")


# Gibt alle verfügbaren Aktionen zurück, die der Spieler an diesem Objekt ausführen kann.
# Jede Aktion ist ein Dictionary: { "label": String, "action_id": String }
func get_actions(_player: Playable) -> Array[Dictionary]:
	return []


# Führt die Aktion mit der gegebenen ID aus.
func perform_action(_action_id: String, _player: Playable) -> void:
	pass
