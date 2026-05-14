class_name Player extends Playable

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hurt_box: HurtBox = %AttackHurtBox

var _inventory_layer: CanvasLayer


func _ready() -> void:
	footstep_player = $FootstepPlayer as FootstepPlayer
	state_machine.initialize(self)
	super._ready()
	_inventory_layer = CanvasLayer.new()
	_inventory_layer.layer = 25
	_inventory_layer.visible = false
	add_child(_inventory_layer)
	var ui := InventoryUI.new()
	ui.playable = self
	_inventory_layer.add_child(ui)
	if inventory.is_empty():
		add_item(load("res://Ressources/Items/messer.tres") as Item)


func _process(delta: float) -> void:
	super._process(delta)
	if Input.is_action_just_pressed("Inventar"):
		_inventory_layer.visible = not _inventory_layer.visible


# Spielereingabe als Bewegungsrichtung
func get_move_direction() -> Vector3:
	return Vector3(
		Input.get_axis("Left", "Right"),
		0,
		Input.get_axis("Up", "Down")
	).normalized()
