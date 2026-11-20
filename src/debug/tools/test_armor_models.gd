extends Node

const VISUAL := preload("res://src/resources/items/item_visual.gd")
const KEYS := ["eisenhelm", "beschaedigter_eisenhelm"]
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
	var sheet := CharacterResource.new()
	sheet.ensure_initialized()
	var body := CombatAnatomy.profile(sheet)
	for key in KEYS:
		var item := load("res://src/resources/items/" + key + ".tres") as ItemData
		check(item.is_armor and item.equipment_slot == "kopf" and item.armor_zones == ["head"], key + ": Kopfschutz definiert")
		check(Inventory.can_place_item(item, "kopf") and not Inventory.can_place_item(item, "rumpf"), key + ": richtiger Körperplatz")
		check(item.icon != null and item.icon.get_image().get_used_rect().has_area(), key + ": gerendertes Inventarbild vorhanden")
		for slot in ["primaer_hand", "guertel_1"]:
			sheet.inventory.equipment.clear()
			sheet.inventory.equip(slot, item)
			check(not CombatAnatomy.protection(sheet, body.get_zone("head"), "slash").armored, key + ": kein Kopfschutz in " + slot)
		sheet.inventory.equipment.clear()
		sheet.inventory.add_item(item)
		check(not CombatAnatomy.protection(sheet, body.get_zone("head"), "slash").armored, key + ": Rucksack schützt nicht")
		sheet.inventory.equip("kopf", item)
		for type in ["blunt", "slash", "pierce"]:
			var protection := CombatAnatomy.protection(sheet, body.get_zone("head"), type)
			check(protection.armored and protection.amount == item.armor_protection[type], key + ": örtlicher " + type + "-Schutz")
		check(not CombatAnatomy.protection(sheet, body.get_zone("torso"), "slash").armored and not CombatAnatomy.protection(sheet, body.get_zone("forearm_left"), "slash").armored, key + ": Rumpf und Unterarm bleiben ungeschützt")
		var model := VISUAL.create(item)
		check(model.has_node("ArmorModel") and VISUAL.bounds(model).size.y > 0.2 and VISUAL.bounds(model).size.y < 0.3, key + ": vorhandenes Modell in Weltmetern")
		model.free()
		var dropped := load("res://src/world/objects/items/" + key + ".tscn").instantiate() as BasicItem
		dropped.freeze = true
		add_child(dropped)
		var visual := dropped.get_node("ArmorVisual") as Node3D
		var bounds := VISUAL.bounds(visual)
		var collision := dropped.get_node("CollisionShape3D") as CollisionShape3D
		check(is_equal_approx(collision.shape.size.y, bounds.size.y) and is_zero_approx(bounds.position.y + visual.position.y), key + ": Weltmodell und Kollision passen")
		dropped.free()
		var codec := WorldValueCodec.new()
		var restored := codec.decode(codec.encode(item.duplicate_deep(Resource.DEEP_DUPLICATE_ALL))) as ItemData
		check(not codec.failed and restored != null and restored.armor_protection == item.armor_protection and restored.icon == item.icon, key + ": tiefe Kopie mit Bild und Schutz speicherbar")
	var attacker_body := Playable.new()
	attacker_body.character = CharacterResource.new()
	attacker_body.character.ensure_initialized()
	var target_body := Playable.new()
	target_body.character = CharacterResource.new()
	target_body.character.ensure_initialized()
	target_body.character.gewandheit = 0
	target_body.character.robustheit = 0
	target_body.health = 1000
	var attacker := CombatParticipant.new(attacker_body, &"attacker")
	var target := CombatParticipant.new(target_body, &"victim")
	var unarmored := CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "head", "slash")
	target_body.equip("kopf", load("res://src/resources/items/eisenhelm.tres"))
	var intact := CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "head", "slash")
	check(intact == unarmored - 5, "Eisenhelm mindert echten Kopftreffer um fünf Schnittschaden")
	check(CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "torso", "slash") == 10, "Eisenhelm ändert echten Rumpftreffer nicht")
	check(CombatResolver.resolve_damage(attacker, target, 1, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "head", "slash") == 0, "Kopfschutz kann kleinen Treffer vollständig abfangen")
	target_body.equip("kopf", load("res://src/resources/items/beschaedigter_eisenhelm.tres"))
	check(CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "head", "slash") == unarmored - 2, "Beschädigte Variante hat geringeren tatsächlichen Schutz")
	attacker_body.free()
	target_body.free()
	# Fallback für Actors ohne Kopfknochen richtet sich nach dem Körperprofil.
	var fallback := Playable.new()
	fallback.character = CharacterResource.new()
	fallback.character.ensure_initialized()
	fallback.character.inventory.equip("kopf", load("res://src/resources/items/eisenhelm.tres"))
	add_child(fallback)
	fallback.set_physics_process(false)
	await get_tree().process_frame
	var fallback_held: Node = fallback.get_node("HeldItemVisuals")
	var fallback_visual := fallback_held._visuals.kopf as Node3D
	check(not fallback_held._sockets.kopf is BoneAttachment3D and fallback_visual.to_global(VISUAL.bounds(fallback_visual).get_center()).distance_to(CombatAnatomy.frame(fallback) * CombatAnatomy.profile(fallback.character).get_zone("head").center) < 0.01, "Ohne Skeleton sitzt der Helm am Profilkopf")
	fallback.free()
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	game.game_windows.open_page(2)
	for frame in 4: await get_tree().process_frame
	var view := game.game_windows._embedded_views[0] as InventoryUI
	var player := view.playable
	player.gold = 100
	var shop := ShopManager.instance.get_shop("haendler_01")
	for key in KEYS:
		var template := load("res://src/resources/items/" + key + ".tres") as ItemData
		var offer: ShopEntry
		for entry in shop.entries:
			if entry.item.item_id == template.item_id: offer = entry
		check(offer != null, key + ": beim Wanderhändler verfügbar")
		var gold := player.gold
		check(GameState.apply_effects([{"type": "shop_buy", "shop_id": "haendler_01", "character_id": player.character.character_id, "item_id": template.item_id, "count": 1}]), key + ": Kauf über WorldRules")
		check(player.gold == gold - offer.buy_price, key + ": Kaufpreis korrekt")
		var index := -1
		for i in player.inventory.size():
			if player.inventory[i].item.item_id == template.item_id: index = i
		check(index >= 0 and view._inv_slots[index].icon != null, key + ": gekauftes Modellbild im Inventar")
		view.equip_from_slot(index, "kopf")
		view._inspect_equipment("kopf")
		for frame in 4: await get_tree().process_frame
		var held: Node = player.get_node("HeldItemVisuals")
		var model := held._visuals.get("kopf") as Node3D
		check(held._sockets.kopf is BoneAttachment3D and held._sockets.kopf.bone_name == "Head", key + ": Helm folgt dem Kopfknochen")
		check(model != null and model.get_meta("item_id") == template.item_id and model.global_basis.get_scale().is_equal_approx(Vector3.ONE), key + ": Kopfmodell hat richtige Variante und Weltgröße")
		check(view._item_preview.texture == template.icon and view._stats.text.contains("Kopf"), key + ": Vorschau und örtlicher Schutz sichtbar")
		view.unequip_to_backpack("kopf")
		check(not held._visuals.has("kopf"), key + ": Ablegen entfernt Kopfmodell sofort")
		check(not CombatAnatomy.protection(player.character, CombatAnatomy.profile(player.character).get_zone("head"), "slash").armored, key + ": Ablegen entfernt Schutz")
	# Beide Party-Rigs und Szenenabbau mit angelegtem Helm prüfen.
	var members := game.party.get_all_members()
	for i in members.size():
		members[i].equip("kopf", load("res://src/resources/items/" + KEYS[i % KEYS.size()] + ".tres"))
	for frame in 4: await get_tree().process_frame
	for member in members:
		var held: Node = member.get_node("HeldItemVisuals")
		check(held._visuals.has("kopf"), member.name + ": Helm sichtbar")
		var skeleton: Skeleton3D = held._find_skeleton(member.get_node("Model"))
		var center := skeleton.global_transform * ((skeleton.get_bone_global_pose(skeleton.find_bone("headfront")).origin + skeleton.get_bone_global_pose(skeleton.find_bone("head_end")).origin) * 0.5)
		check(held._visuals.kopf.global_position.distance_to(center) < 0.02, member.name + ": Helmmitte folgt den Kopfmarkierungen")
	var store := WorldSaveStore.new()
	check(store.write(GameState.world_state, "res://.armor-test-save.json") == OK, "Welt mit Helmen speicherbar: " + store.last_error)
	var restored := store.read("res://.armor-test-save.json")
	check(restored != null and restored.characters.get_character(player.character.character_id).inventory.equipment.kopf.item_id == "Eisenhelm", "Angelegter Helm und Händlerbestand ladbar")
	DirAccess.remove_absolute("res://.armor-test-save.json")
	if "--visual-smoke" in OS.get_cmdline_user_args():
		view._inspect_equipment("kopf")
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.armor-inventory-preview.png")
		for layer in [game.hud_root, game.menu_root, game.dialogue_root, game.pause_root, game.transition_root]: layer.visible = false
		game.camera_system.set_process(false)
		var origin := player.global_position
		for i in members.size():
			members[i].set_physics_process(false)
			members[i].global_position = origin + Vector3(i * 0.8, 0, 0)
			members[i].face_world_position(members[i].global_position + Vector3.BACK * 4)
		var camera := game.camera_system.get_node("Camera3D") as Camera3D
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.5
		camera.global_position = origin + Vector3(1.8, 1.2, 3)
		camera.look_at(origin + Vector3(0.4, 0.9, 0))
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.armor-equipped-preview.png")
	game.free()
	await get_tree().process_frame
	print("armor_models: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
