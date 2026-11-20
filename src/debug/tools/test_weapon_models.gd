extends Node

const VISUAL := preload("res://src/resources/items/item_visual.gd")
const KEYS := ["messer", "dolch", "schwert", "speer", "bogen", "pfeil"]
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for key in KEYS:
		var item := load("res://src/resources/items/" + key + ".tres") as ItemData
		check(item.icon != null and item.icon.get_size() == Vector2(256, 256), key + ": Inventarbild zugewiesen")
		if item.icon == null:
			continue
		var image := item.icon.get_image()
		check(image.get_used_rect().has_area(), key + ": Inventarbild enthält sichtbare Pixel")
		var model := VISUAL.create(item)
		var bounds := VISUAL.bounds(model)
		check((is_equal_approx(float(model.get_meta("length_meters")), 1.2) and bounds.size.y < 1.3) if key == "bogen" else is_equal_approx(bounds.size.y, VISUAL.length_meters(item)), key + ": Länge bleibt erhalten")
		check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), key + ": Ansicht hat keine Physik")
		if VISUAL.MODELS.has(item.item_id):
			check(model.get_meta("source_model", "") == VISUAL.MODEL_SOURCES[item.item_id], key + ": passendes Assetmodell ausgewählt")
			var mesh := model.get_node("WeaponModel") as MeshInstance3D
			var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
			check(material != null and material.albedo_texture != null and not material.albedo_texture.get_image().is_empty(), key + ": Texturatlas eingebettet")
		else:
			check(not model.has_meta("source_model"), key + ": bestehende Form ohne falschen Assetersatz")
		model.free()
		var dropped := load("res://src/world/objects/items/basic_item.tscn").instantiate() as BasicItem
		dropped.item_data = item
		dropped.freeze = true
		add_child(dropped)
		var visual := dropped.get_node("WeaponVisual") as Node3D
		var visual_bounds := VISUAL.bounds(visual)
		var collision := dropped.get_node("CollisionShape3D") as CollisionShape3D
		check(is_equal_approx(collision.shape.size.y, visual_bounds.size.y) and collision.position.is_equal_approx(visual_bounds.get_center() + visual.position), key + ": Weltkollision umfasst das Modell")
		check(is_zero_approx(visual_bounds.position.y + visual.position.y), key + ": abgelegtes Modell steht auf dem Boden")
		dropped.free()
		var codec := WorldValueCodec.new()
		var restored := codec.decode(codec.encode(item)) as ItemData
		check(not codec.failed and restored != null and restored.icon.resource_path == item.icon.resource_path, key + ": Bild über bestehenden Save-Codec ladbar")
		var legacy_codec := WorldValueCodec.new()
		var legacy_data: Dictionary = legacy_codec.encode(item)
		legacy_data.value.icon = null
		var legacy := legacy_codec.decode(legacy_data) as ItemData
		check(not legacy_codec.failed and legacy != null and legacy.icon == item.icon, key + ": alter Speicherstand ohne Bild erhält Modellvorschau")
		var duplicate := item.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ItemData
		var duplicate_codec := WorldValueCodec.new()
		var duplicated: Variant = duplicate_codec.decode(duplicate_codec.encode(duplicate))
		check(not duplicate_codec.failed and duplicated != null, key + ": Laufzeitkopie bleibt speicherbar")
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	game.game_windows.open_page(2)
	for frame in 4: await get_tree().process_frame
	var view := game.game_windows._embedded_views[0] as InventoryUI
	for key in KEYS:
		var id: String = (load("res://src/resources/items/" + key + ".tres") as ItemData).item_id
		var index := -1
		for i in view.playable.inventory.size():
			if view.playable.inventory[i].item.item_id == id:
				index = i
		check(index >= 0, key + ": Spielerinventar enthält Gegenstand")
		if index < 0: continue
		var item: ItemData = view.playable.inventory[index].item
		view._inspect_inventory(index)
		check(view._inv_slots[index].icon == item.icon and view._item_preview.texture == item.icon and view._item_preview.visible, key + ": Rucksack und Detailansicht zeigen dasselbe Modellbild")
		view.equip_from_slot(index, "nebenhand")
		view._inspect_equipment("nebenhand")
		check(view._equip_buttons.nebenhand.icon == item.icon and view._item_preview.texture == item.icon, key + ": ausgerüsteter Handplatz zeigt Modellbild")
	var store := WorldSaveStore.new()
	var saved := store.write(GameState.world_state, "res://.weapon-model-save.json")
	check(saved == OK, "Welt mit bebilderten Waffen speicherbar: " + store.last_error)
	if saved == OK:
		check(store.read("res://.weapon-model-save.json") != null, "Welt mit bebilderten Waffen wieder ladbar")
	DirAccess.remove_absolute("res://.weapon-model-save.json")
	DirAccess.remove_absolute("res://.weapon-model-save.json.tmp")
	view._inspect_item(null)
	check(view._item_preview.texture == null and not view._item_preview.visible, "Leere Auswahl entfernt vorherige Vorschau")
	if "--visual-smoke" in OS.get_cmdline_user_args():
		view._inspect_item(load("res://src/resources/items/schwert.tres"))
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.weapon-inventory-preview.png")
	game.free()
	await get_tree().process_frame
	print("weapon_models: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
