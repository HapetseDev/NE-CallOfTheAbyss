@tool
class_name SurfaceDefinition extends Node

# Füge dieses Script zu einem StaticBody3D oder Area3D hinzu,
# um den Oberflächentyp zu definieren

@export var surface_type: String = "grass" :
	set(value):
		surface_type = value
		_update_metadata()

func _ready() -> void:
	_update_metadata()


func _update_metadata() -> void:
	var parent = get_parent()
	if parent:
		parent.set_meta("surface_type", surface_type)
