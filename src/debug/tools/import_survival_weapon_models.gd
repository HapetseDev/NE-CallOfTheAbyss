extends Node

## Adapter für das gelieferte Assetpaket; Originaldateien bleiben unverändert.
## Direktimport repariert den Texturpfad und entfernt Demo-Positionsversätze.
const BASE := "res://assets/items/Poly-Survival Melee Weapons/Models/"
const MODELS := {
	"schwert": "SM_Handcrafted_Sword",
	"dolch": "SM_Handcrafted_Knife_02",
	"messer": "SM_Handcrafted_Knife_01",
}

func _ready() -> void:
	var failed := false
	DirAccess.make_dir_recursive_absolute("res://assets/items/weapons")
	for key in MODELS:
		var source: String = BASE + MODELS[key] + ".gltf"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
		for image in data.get("images", []):
			image.uri = "../Textures/MainTexture.png"
		for node in data.get("nodes", []):
			node.erase("translation")
		var temporary: String = BASE + "necota_import_" + key + ".gltf"
		var file := FileAccess.open(temporary, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(temporary, state)
		DirAccess.remove_absolute(temporary)
		if error != OK:
			printerr("Import fehlgeschlagen: ", source, " / ", error)
			failed = true
			continue
		var scene := document.generate_scene(state)
		var instances := scene.find_children("*", "MeshInstance3D", true, false)
		if instances.size() != 1:
			failed = true
		else:
			var mesh := (instances[0] as MeshInstance3D).mesh.duplicate() as Mesh
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
				if material.albedo_texture:
					# Importtexturen nicht als externe Cache-Ressourcen einbetten.
					material.albedo_texture = ImageTexture.create_from_image(material.albedo_texture.get_image())
				mesh.surface_set_material(surface, material)
			mesh.resource_name = MODELS[key]
			error = ResourceSaver.save(mesh, "res://assets/items/weapons/" + key + ".res", ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_COMPRESS)
			print(key, ": ", error, " bounds=", mesh.get_aabb())
			failed = failed or error != OK
		scene.free()
	get_tree().quit(1 if failed else 0)
