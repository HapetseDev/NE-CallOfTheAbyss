# World-space disc showing the player's interaction radius while the action menu is open.
class_name ActionRangeIndicator extends Node3D

const SHADER_PATH := "res://src/gameplay/interaction/action_range_indicator.gdshader"
const Y_OFFSET := 0.04

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	plane.orientation = PlaneMesh.FACE_Y
	_mesh_instance.mesh = plane

	var shader := load(SHADER_PATH) as Shader
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.render_priority = 1
	_mesh_instance.material_override = _material

	add_child(_mesh_instance)
	position.y = Y_OFFSET
	visible = false


func show_range(radius: float) -> void:
	if radius <= 0.0:
		hide_range()
		return
	scale = Vector3(radius, 1.0, radius)
	visible = true


func hide_range() -> void:
	visible = false
