class_name CombatGridDisplay
extends MeshInstance3D

const GRID := preload("res://src/world/combat/combat_grid.gd")
const REACHABLE_ALPHA := 0.48
const SELECTED_FILL_ALPHA := 0.78
const SELECTED_LINE_ALPHA := 1.0
var session: CombatSession
var preview: Dictionary = {}
var selected := Vector2i.ZERO
var _elapsed := 0.5

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	material_override = material

func _process(delta: float) -> void:
	visible = is_instance_valid(session) and session.state == CombatSession.SessionState.ACTIVE
	if not visible:
		return
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		redraw()

func show_fields(fields: Dictionary, selection: Vector2i) -> void:
	preview = fields
	selected = selection
	redraw()

func redraw() -> void:
	if not is_instance_valid(session):
		return
	var cells: Dictionary = {}
	for participant in session.participants:
		if participant.is_out_of_combat() or not is_instance_valid(participant.playable):
			continue
		var body := participant.playable
		var origin := GRID.cell(body.global_position)
		for x in range(-2, 3):
			for z in range(-2, 3):
				var key := origin + Vector2i(x, z)
				if cells.has(key):
					continue
				var point = GRID.floor_point(body, key, body.global_position.y)
				if point != null:
					cells[key] = point
	for key in preview:
		cells[key] = preview[key].position
	var geometry := ImmediateMesh.new()
	if not cells.is_empty():
		# Das gewählte Feld ist als helle Fläche lesbar, nicht nur als weiterer Rand.
		if not preview.is_empty() and cells.has(selected):
			geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			var fill := NEColors.ACCENT_HOVER
			fill.a = SELECTED_FILL_ALPHA
			geometry.surface_set_color(fill)
			var selected_point: Vector3 = cells[selected] + Vector3.UP * 0.018
			var selected_half := GRID.CELL_SIZE * 0.45
			var selected_corners := [Vector3(-selected_half, 0, -selected_half), Vector3(selected_half, 0, -selected_half), Vector3(selected_half, 0, selected_half), Vector3(-selected_half, 0, selected_half)]
			for index in [0, 1, 2, 0, 2, 3]:
				geometry.surface_add_vertex(selected_point + selected_corners[index])
			geometry.surface_end()
		geometry.surface_begin(Mesh.PRIMITIVE_LINES)
		for key in cells:
			var color := NEColors.BORDER
			color.a = 0.35
			if preview.has(key):
				color = NEColors.SUCCESS
				color.a = REACHABLE_ALPHA
			if not preview.is_empty() and key == selected:
				color = NEColors.ACCENT_HOVER
				color.a = SELECTED_LINE_ALPHA
			geometry.surface_set_color(color)
			var point: Vector3 = cells[key] + Vector3.UP * 0.015
			var half := GRID.CELL_SIZE * 0.48
			var corners := [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]
			for index in 4:
				geometry.surface_add_vertex(point + corners[index])
				geometry.surface_add_vertex(point + corners[(index + 1) % 4])
		geometry.surface_end()
	mesh = geometry
