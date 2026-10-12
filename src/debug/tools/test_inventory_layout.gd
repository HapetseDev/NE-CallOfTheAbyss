extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	GameState.reset_session()
	var game := preload("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame
	var shell := game.game_windows
	shell.open_page(2)
	await get_tree().process_frame
	var members := game.party.get_all_members()
	check(shell._embedded_views.size() == members.size(), "Ein Inventar je Partymitglied")
	for i in members.size():
		var card := shell._embedded_views[i] as InventoryUI
		check(card.playable == members[i], "Inventare folgen Partyreihenfolge")
		check(card._portrait.texture == members[i].character.get_portrait(), "Charakterportrait zugeordnet")
		check(card._paperdoll.texture != null and card._paperdoll.texture == members[i].character.get_paperdoll(), "Eigene Paperdoll geladen")
		check(card._more_info.text.is_empty(), "Weitere Infos bleibt leer")
		check(card._quick_grid.get_child_count() == 9, "Neun Schnellplätze")
		check(card._equip_buttons.has("schmuck") and card._equip_buttons.has("primaer_hand"), "Schmuck und beide Hände erreichbar")
		check(card._inv_slots.size() >= 18, "Rucksack mit zwei Reihen")
	var view := shell._embedded_views[0] as InventoryUI
	var player := view.playable
	var knife := preload("res://src/resources/items/messer.tres").duplicate() as ItemData
	player.add_item(knife)
	var index := _find(player, knife)
	check(view.can_equip_from_slot(index, "primaer_hand"), "Messer passt in Waffenplatz")
	check(not view.can_equip_from_slot(index, "kopf"), "Messer passt nicht auf Kopf")
	check(not view.can_equip_from_slot(-1, "guertel_1"), "Ungültiger Index abgewiesen")
	var weight := player.get_total_weight()
	view.equip_from_slot(index, "guertel_9")
	check(player.equipment.guertel_9 == knife, "Messer in neunten Schnellplatz")
	check(player.get_combat_usable_items().has(knife), "Neunter Schnellplatz im Kampf verfügbar")
	check(is_equal_approx(player.get_total_weight(), weight), "Ausrüsten erhält Traglast")
	var plant := Plant.new()
	check(plant.can_schneiden(player), "Messer aus Schnellplatz schneidet Pflanzen")
	plant.free()
	view._inspect_equipment("guertel_9")
	check(view._stats.text.contains("Gewicht: 0.30") and view._stats.text.contains("Werfen"), "Vorhandene Eigenschaften und Kampfmodi sichtbar")
	if "--visual-smoke" in OS.get_cmdline_user_args():
		await _preview(shell)
	var stale := {"type": "equipped_item", "source": view, "slot_key": "guertel_9", "item": knife}
	view.unequip_to_backpack("guertel_9")
	check(not view._inv_slots[0]._can_drop_data(Vector2.ZERO, stale), "Veralteter Ausrüstungsdrag wird abgewiesen")
	check(not player.get_combat_usable_items().has(knife), "Rucksack nicht im Kampf verfügbar")
	view.equip_from_slot(_find(player, knife), "primaer_hand")
	view.unequip_to_backpack("primaer_hand")
	check(player.equipment.primaer_hand == null and _find(player, knife) >= 0, "Körperausrüstung in Rucksack zurück")
	var potion := preload("res://src/resources/items/heiltrank.tres").duplicate() as ItemData
	player.add_item(potion, 3)
	check(not view.can_equip_from_slot(_find(player, potion), "kopf"), "Verbrauchsgegenstand passt nicht an Körper")
	view.equip_from_slot(_find(player, potion), "guertel_1")
	check(player.inventory[_find(player, potion)].count == 2, "Schnellplatz nimmt ein Exemplar aus Stapel")
	view.equip_from_slot(_find(player, knife), "guertel_1")
	check(player.inventory[_find(player, potion)].count == 3, "Schnellplatztausch verstaut bisherigen Gegenstand")
	check(player.equipment.guertel_1 == knife, "Tausch setzt neues Item")
	view.unequip_to_backpack("guertel_1")
	view.equip_from_slot(_find(player, potion), "guertel_1")
	view._inspect_equipment("guertel_1")
	check(view._stats.text.contains("Stärkepunkte"), "Heilwirkung in Stats")
	var turn := StateCombatTurn.new()
	turn.player = player
	turn._vbox = VBoxContainer.new()
	turn.add_child(turn._vbox)
	turn._render_item_menu()
	var has_potion_button := false
	for child in turn._vbox.get_children():
		has_potion_button = has_potion_button or (child is Button and child.text == potion.item_name + " – Verwenden")
	check(has_potion_button, "Kampfmenü bietet Schnelltrank zur Verwendung an")
	turn.free()
	var participant := CombatParticipant.new(player, &"party")
	var action := CombatAction.new()
	action.actor = participant
	action.type = CombatAction.ActionType.ITEM
	action.item = potion
	action.targets = [participant]
	player.health = 1
	action.targets = [CombatParticipant.new(members[1], &"enemy")]
	check(not CombatResolver.resolve_action(action).success and player.equipment.guertel_1 == potion, "Feindziel verbraucht keinen Schnelltrank")
	action.targets = [participant, participant]
	check(not CombatResolver.resolve_action(action).success and player.equipment.guertel_1 == potion, "Ein Trank erlaubt genau ein Ziel")
	action.targets = [participant]
	var result := CombatResolver.resolve_action(action)
	check(result.success and player.health > 1, "Schnelltrank heilt im Kampf")
	check(player.equipment.guertel_1 == null and player.inventory[_find(player, potion)].count == 2, "Kampf verbraucht Schnellplatz, nicht Rucksack")
	check(not CombatResolver.resolve_action(action).success, "Bereits verbrauchter Schnelltrank nicht nochmals nutzbar")
	view.equip_from_slot(_find(player, knife), "guertel_9")
	action.item = knife
	action.item_usage_mode = knife.usage_modes[1]
	action.item_usage_mode.requires_line_of_sight = false
	action.targets = [CombatParticipant.new(members[1], &"enemy")]
	result = CombatResolver.resolve_action(action)
	check(result.success and player.equipment.guertel_9 == null, "Werfen entfernt ausgerüstetes Exemplar")
	check(not CombatResolver.resolve_action(action).success, "Verbrauchter Wurfgegenstand nicht mehrfach nutzbar")
	view.equip_from_slot(_find(player, potion), "guertel_9")
	shell.close()
	var store := WorldSaveStore.new()
	check(game.level_manager.save_world("/tmp/necota-inventory-layout.json") == OK, "Neue Ausrüstungsplätze speicherbar")
	var restored := store.read("/tmp/necota-inventory-layout.json")
	check(restored != null and restored.characters.get_character(player.character.character_id).inventory.equipment.guertel_9.item_id == potion.item_id, "Neunter Schnellplatz wird geladen")
	# Optionalen neuen Slot-Keys fehlen in alten Saves; vorhandene Gürtel bleiben.
	var inv := player.character.inventory
	for key in ["schmuck", "guertel_4", "guertel_5", "guertel_6", "guertel_7", "guertel_8", "guertel_9"]:
		inv.equipment.erase(key)
	inv.equipment.guertel_2 = potion
	check(store.write(GameState.world_state, "/tmp/necota-inventory-legacy.json") == OK, "Alte Ausrüstungsstruktur schreib-/lesbar")
	restored = store.read("/tmp/necota-inventory-legacy.json")
	var legacy := restored.characters.get_character(player.character.character_id).inventory
	check(legacy.equipment.guertel_2.item_id == potion.item_id and legacy.equipment.has("guertel_9") and legacy.equipment.guertel_9 == null, "Alte Gürtelbelegung erhalten; neue Plätze leer ergänzt")
	# Echtes Legacy-JSON mit Waffenplatz; Reader normalisiert vor Slotvalidierung.
	inv.equipment.primaer_hand = null
	inv.equipment["waffe"] = knife
	check(store.write(GameState.world_state, "/tmp/necota-inventory-weapon-legacy.json") == OK, "Legacy-Waffenplatz wird beim Lesen akzeptiert")
	restored = store.read("/tmp/necota-inventory-weapon-legacy.json")
	var normalized := restored.characters.get_character(player.character.character_id).inventory
	check(not normalized.equipment.has("waffe") and normalized.equipment.primaer_hand.item_id == "Messer", "Legacy-Waffe wird rechte Hand")
	inv.equipment.primaer_hand = potion
	check(store.write(GameState.world_state, "/tmp/necota-inventory-weapon-conflict.json") == OK, "Migration bei bereits belegter rechter Hand")
	restored = store.read("/tmp/necota-inventory-weapon-conflict.json")
	normalized = restored.characters.get_character(player.character.character_id).inventory
	check(normalized.equipment.primaer_hand.item_id == potion.item_id and normalized.has_item("Messer"), "Belegte Hand bleibt erhalten; zusätzliche Waffe im Rucksack")
	inv.ensure_equipment_slots()
	var total_slots := inv.slots.size()
	inv.ensure_equipment_slots()
	check(inv.slots.size() == total_slots and not inv.equipment.has("waffe"), "Migration ist idempotent")
	shell.open_page(0)
	shell._move(members[1], -1)
	shell.select_page(2)
	await get_tree().process_frame
	check((shell._embedded_views[0] as InventoryUI).playable == members[1], "Inventar folgt geändertem Anführer")
	check(shell._scroll.get_v_scroll_bar().max_value > shell._scroll.size.y, "Ein äußerer Scrollbereich erreicht alle Inventare")
	shell.close()
	await get_tree().process_frame
	game.free()
	await get_tree().process_frame
	print("inventory_layout: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _find(player: Playable, item: ItemData) -> int:
	for i in player.inventory.size():
		if player.inventory[i].item == item:
			return i
	return -1


func _preview(shell: GameWindows) -> void:
	for frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/necota-inventory-top.png")
	shell._scroll.scroll_vertical = 320
	for frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/necota-inventory-backpack.png")
	get_window().content_scale_size = Vector2i(800, 450)
	get_window().size = Vector2i(1280, 720)
	shell._scroll.scroll_vertical = 0
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/necota-inventory-small.png")
	var view := shell._embedded_views[0] as InventoryUI
	check(view._upper.vertical, "Schmale Ansicht ordnet Details unter Körperansicht")
	check(view._inv_grid.get_global_rect().end.x <= shell._scroll.get_global_rect().end.x, "Schmale Ansicht hält Rucksack im sichtbaren Bereich")
