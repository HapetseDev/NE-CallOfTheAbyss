extends Area3D

## Wiederverwendbarer Ausgang: Zielszene und Ankunftsknoten im Inspector.
@export_file("*.tscn") var target_level: String
@export var target_arrival: NodePath = ^"Levelwechseln/Eingang/Eingangsshape"
var _armed := false
var _initial_frames := 0

func _physics_process(_delta: float) -> void:
	if LevelManager.instance == null or LevelManager.instance.get_party() == null:
		return
	var leader := LevelManager.instance.get_party().leader
	var inside := overlaps_body(leader)
	# Initiale Überlappungen (auch nach Laden) lösen keinen Rücksprung aus.
	if _initial_frames < 2:
		_initial_frames += 1
		return
	if not inside:
		_armed = true
	elif _armed and LevelManager.instance.request_transition(self, target_level, target_arrival):
		_armed = false
