extends RefCounted

## Reine Ansicht: keine ItemData-Kopie, Physik, Welt-ID oder Aufnahme-Logik.
## Aufbereitete Meshes: Atlas eingebettet, ohne Demo-Positionen oder Importpfade.
const MODELS := {
	"Schwert": preload("res://assets/items/weapons/schwert.res"),
	"Dolch": preload("res://assets/items/weapons/dolch.res"),
	"Messer": preload("res://assets/items/weapons/messer.res"),
}
const MODEL_SOURCES := {
	"Schwert": "SM_Handcrafted_Sword",
	"Dolch": "SM_Handcrafted_Knife_02",
	"Messer": "SM_Handcrafted_Knife_01",
}
const ARMOR_MODELS := {
	"Eisenhelm": preload("res://assets/items/armor/eisenhelm.res"),
	"BeschaedigterEisenhelm": preload("res://assets/items/armor/beschaedigter_eisenhelm.res"),
}
const WEAPONS := ["Dolch", "Schwert", "Speer", "Messer", "Bogen", "Pfeil"]

static func length_meters(item: ItemData) -> float:
	if item.item_id == "Bogen":
		return 1.2 * WorldUnits.METER
	for mode in item.get_combat_usage_modes():
		if mode.range_type == ItemUsageMode.RangeType.MELEE:
			return mode.range_meters
	return 0.25 * WorldUnits.METER

static func _material(color: Color, metal: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.75 if metal else 0.0
	material.roughness = 0.35 if metal else 0.8
	return material

static func _part(root: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	root.add_child(part)
	return part

static func _rod(root: Node3D, start: Vector3, end: Vector3, radius: float, material: Material, tip: bool = false) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = start.distance_to(end)
	mesh.bottom_radius = radius
	mesh.top_radius = 0.0 if tip else radius
	mesh.radial_segments = 4 if tip else 12
	var part := _part(root, mesh, (start + end) * 0.5, material)
	part.quaternion = Quaternion(Vector3.UP, (end - start).normalized())

static func create(item: ItemData) -> Node3D:
	var root := Node3D.new()
	root.name = "ItemVisual"
	root.set_meta("item_id", item.item_id)
	if ARMOR_MODELS.has(item.item_id):
		var mesh: Mesh = ARMOR_MODELS[item.item_id]
		var reference: AABB = ARMOR_MODELS.Eisenhelm.get_aabb()
		var factor := 0.26 * WorldUnits.METER / reference.size.y
		var model := MeshInstance3D.new()
		model.name = "ArmorModel"
		model.mesh = mesh
		model.scale = Vector3.ONE * factor
		model.position = -reference.get_center() * factor
		root.add_child(model)
		root.set_meta("source_model", "helmet" if item.item_id == "Eisenhelm" else "broken helmet")
		return root
	var length := length_meters(item)
	root.set_meta("length_meters", length)
	if MODELS.has(item.item_id):
		var mesh: Mesh = MODELS[item.item_id]
		var model := MeshInstance3D.new()
		model.name = "WeaponModel"
		model.mesh = mesh
		# Originalursprung im Griff belassen; die Hand hält den Griff statt den Knauf.
		model.scale = Vector3.ONE * length / mesh.get_aabb().size.y
		root.add_child(model)
		root.set_meta("source_model", MODEL_SOURCES[item.item_id])
		return root
	var steel := _material(Color.SILVER, true)
	var wood := _material(Color.SADDLE_BROWN)
	var grip := _material(Color.DIM_GRAY)
	if item.item_id == "Bogen":
		var points := [Vector3(0, -0.6, 0.25), Vector3(0, -0.4, 0.08), Vector3.ZERO, Vector3(0, 0.4, 0.08), Vector3(0, 0.6, 0.25)]
		for index in range(points.size() - 1):
			_rod(root, points[index], points[index + 1], 0.025, wood)
		_rod(root, points[0], points[-1], 0.004, _material(Color.BEIGE))
	elif item.item_id in ["Speer", "Pfeil"]:
		var shaft := length * 0.85
		_rod(root, Vector3.ZERO, Vector3.UP * shaft, 0.022 if item.item_id == "Speer" else 0.008, wood)
		_rod(root, Vector3.UP * shaft, Vector3.UP * length, 0.07 if item.item_id == "Speer" else 0.025, steel, true)
	elif item.item_id in ["Dolch", "Schwert", "Messer"]:
		var handle := minf(0.22, length * 0.2)
		_rod(root, Vector3.ZERO, Vector3.UP * handle, 0.026, grip)
		_rod(root, Vector3(-0.1, handle, 0), Vector3(0.1, handle, 0), 0.018, steel)
		_rod(root, Vector3.UP * handle, Vector3.UP * length, 0.06, steel, true)
	else:
		var texture := item.world_texture if item.world_texture else item.icon
		if texture:
			var sprite := Sprite3D.new()
			sprite.texture = texture
			sprite.pixel_size = 0.25 / maxf(texture.get_width(), texture.get_height())
			sprite.position.y = 0.125
			root.add_child(sprite)
		else:
			var mesh := SphereMesh.new()
			mesh.radius = 0.08
			mesh.height = 0.16
			_part(root, mesh, Vector3.UP * 0.08, grip)
	return root

## Grenzen relativ zum Visual-Root, auch für verschachtelte Modell-Nodes.
static func bounds(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect_bounds(root, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var result := boxes[0]
	for index in range(1, boxes.size()):
		result = result.merge(boxes[index])
	return result

static func _collect_bounds(node: Node3D, pose: Transform3D, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh:
		boxes.append(pose * node.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_collect_bounds(child, pose * child.transform, boxes)
