extends SceneTree
## Bakes BoxShape3D collisions into a MeshLibrary from each item's mesh AABB.
##
## Run (terminal):
##   Godot --headless --path . --script res://Tools/bake_meshlibrary_collisions.gd
##
## Or in the Godot editor: open this script → File → Run.

const LIBRARY_PATH := "res://Resources/res/tilesfreedungeon.tres"
const MIRROR_MESHLIB_PATH := "res://Resources/Mesh/tilesfreedungeon.meshlib"

## Only bake structural tiles (floors / walls / stairs / …). Set true to bake every item.
const BAKE_ALL_ITEMS := false

## Skip items that already have shapes (set false to overwrite).
const ONLY_MISSING := true

## Thin floor meshes get at least this collision height (meters).
const MIN_BOX_HEIGHT := 0.2

## Name prefixes that receive collision when BAKE_ALL_ITEMS is false.
const STRUCTURAL_PREFIXES: PackedStringArray = [
	"floor_",
	"wall",
	"stairs",
	"barrier",
	"column",
	"pillar",
	"rubble_",
]


func _init() -> void:
	var err := _bake()
	quit(err)


func _bake() -> int:
	if not ResourceLoader.exists(LIBRARY_PATH):
		push_error("MeshLibrary not found: %s" % LIBRARY_PATH)
		return 1

	var library := load(LIBRARY_PATH) as MeshLibrary
	if library == null:
		push_error("Failed to load MeshLibrary: %s" % LIBRARY_PATH)
		return 1

	var baked := 0
	var skipped := 0
	var failed := 0

	for item_id in library.get_item_list():
		var item_name := String(library.get_item_name(item_id))
		if not _should_bake(item_name):
			skipped += 1
			continue

		var existing: Array = library.get_item_shapes(item_id)
		if ONLY_MISSING and not existing.is_empty():
			skipped += 1
			continue

		var mesh := library.get_item_mesh(item_id)
		if mesh == null:
			push_warning("Item '%s' (%d) has no mesh — skipped." % [item_name, item_id])
			failed += 1
			continue

		var mesh_xform := library.get_item_mesh_transform(item_id)
		var shape_data := _make_box_from_mesh(mesh, mesh_xform)
		if shape_data.is_empty():
			push_warning("Item '%s' (%d) has empty AABB — skipped." % [item_name, item_id])
			failed += 1
			continue

		library.set_item_shapes(item_id, shape_data)
		baked += 1

	var save_err := ResourceSaver.save(library, LIBRARY_PATH)
	if save_err != OK:
		push_error("Could not save MeshLibrary to %s (error %d)" % [LIBRARY_PATH, save_err])
		return 1

	if ResourceLoader.exists(MIRROR_MESHLIB_PATH):
		var mirror_err := ResourceSaver.save(library, MIRROR_MESHLIB_PATH)
		if mirror_err != OK:
			push_warning("Primary save OK, but mirror save failed: %s (error %d)" % [MIRROR_MESHLIB_PATH, mirror_err])

	print(
		"MeshLibrary collision bake done.\n"
		+ "  baked:   %d\n" % baked
		+ "  skipped: %d\n" % skipped
		+ "  failed:  %d\n" % failed
		+ "  saved:   %s" % LIBRARY_PATH
	)
	return 0


func _should_bake(item_name: String) -> bool:
	if BAKE_ALL_ITEMS:
		return true
	var n := item_name.to_lower()
	for prefix in STRUCTURAL_PREFIXES:
		if n.begins_with(prefix):
			return true
	return false


func _make_box_from_mesh(mesh: Mesh, mesh_xform: Transform3D) -> Array:
	var aabb := mesh.get_aabb()
	if aabb.size.length_squared() <= 0.000001:
		return []

	# Apply the MeshLibrary's per-item mesh transform to the collision.
	aabb = mesh_xform * aabb

	var size := aabb.size
	if size.y < MIN_BOX_HEIGHT:
		var grow := MIN_BOX_HEIGHT - size.y
		aabb.position.y -= grow * 0.5
		aabb.size.y = MIN_BOX_HEIGHT
		size = aabb.size

	var box := BoxShape3D.new()
	box.size = size

	var xform := Transform3D(Basis.IDENTITY, aabb.get_center())
	# MeshLibrary shapes array: [Shape3D, Transform3D, Shape3D, Transform3D, ...]
	return [box, xform]
