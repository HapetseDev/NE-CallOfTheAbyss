extends Node

## Importiert ausschließlich vorhandene Helmvarianten; Originaldateien bleiben erhalten.
const BASE := "res://assets/environments/POLY_MedievalCamp/AnimpicStudio/POLY - Medieval Camp/Models/"
const MODELS := {"eisenhelm": "helmet", "beschaedigter_eisenhelm": "broken helmet"}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "Helmet.gltf"))
	for image in data.images:
		image.uri = "../Textures/MainTexture_01.png"
	var temporary := BASE + "necota_armor_import.gltf"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(temporary, state)
	DirAccess.remove_absolute(temporary)
	if error != OK:
		printerr("Helmimport fehlgeschlagen: ", error)
		get_tree().quit(1)
		return
	var scene := document.generate_scene(state)
	DirAccess.make_dir_recursive_absolute("res://assets/items/armor")
	var failed := false
	for key in MODELS:
		var found := false
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			# glTF-Namen können beim Node-Import Leerzeichen verlieren.
			if String(node.name).replace(" ", "").to_lower() != String(MODELS[key]).replace(" ", "").to_lower():
				continue
			found = true
			var mesh := ArrayMesh.new()
			for surface in node.mesh.get_surface_count():
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for index in vertices.size():
					vertices[index] = node.transform * vertices[index]
				for index in normals.size():
					normals[index] = (node.basis * normals[index]).normalized()
				arrays[Mesh.ARRAY_VERTEX] = vertices
				arrays[Mesh.ARRAY_NORMAL] = normals
				arrays[Mesh.ARRAY_TANGENT] = null
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				var material := node.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
				if material.albedo_texture:
					material.albedo_texture = ImageTexture.create_from_image(material.albedo_texture.get_image())
				mesh.surface_set_material(surface, material)
			mesh.resource_name = MODELS[key]
			error = ResourceSaver.save(mesh, "res://assets/items/armor/" + key + ".res", ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_COMPRESS)
			failed = failed or error != OK
			print(key, ": ", error, " ", mesh.get_aabb())
		if not found:
			failed = true
			printerr("Helmvariante nicht gefunden: ", MODELS[key])
	scene.free()
	get_tree().quit(1 if failed else 0)
