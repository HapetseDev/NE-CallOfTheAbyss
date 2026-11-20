extends Node

const PLANNER := preload("res://src/gameplay/combat/ai/combat_ai_planner.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func strip_factors(value: Variant) -> void:
	if value is Dictionary:
		if value.get("kind") == "ItemData": value.value.erase("armor_direction_factors")
		for child in value.values(): strip_factors(child)
	elif value is Array:
		for child in value: strip_factors(child)

func _run() -> void:
	var attacker := Playable.new()
	attacker.character = CharacterResource.new()
	attacker.character.ensure_initialized()
	attacker.character.koerperkraft = 10
	var victim := Playable.new()
	victim.character = CharacterResource.new()
	victim.character.ensure_initialized()
	victim.character.gewandheit = 0
	victim.character.robustheit = 0
	victim.health = 10000
	victim.facing_direction = Vector3.BACK
	var armor := ItemData.new()
	armor.item_id = "DirectionalTestArmor"
	armor.item_name = "Testrüstung"
	armor.max_stack = 1
	armor.is_armor = true
	armor.equipment_slot = "rumpf"
	armor.armor_zones = ["torso"]
	armor.armor_protection = {"slash": 8, "blunt": 4}
	victim.equip("rumpf", armor)
	var actor := CombatParticipant.new(attacker, &"attacker")
	var target := CombatParticipant.new(victim, &"victim")
	var torso := CombatAnatomy.profile(victim.character).get_zone("torso")
	for entry in [[Vector3(0, 0, 2), "front", 8], [Vector3(2, 0, 0), "side", 6], [Vector3(0, 0, -2), "rear", 4]]:
		attacker.position = entry[0]
		var direction := CombatAnatomy.direction(attacker, victim)
		check(direction == entry[1], "Richtung folgt Position: " + entry[1])
		check(CombatAnatomy.protection(victim.character, torso, "slash", direction).amount == entry[2], "Örtlicher Richtungswert: " + entry[1])
		check(CombatResolver.resolve_damage(actor, target, 20, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "torso", "slash") == 20 - entry[2], "Tatsächlicher Schaden: " + entry[1])
	attacker.position = Vector3(0, 0, 2)
	victim.facing_direction = Vector3.FORWARD
	check(CombatResolver.resolve_damage(actor, target, 20, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "torso", "slash") == 16, "Drehung des Verteidigers kehrt den Schutz um")
	victim.facing_direction = Vector3.BACK
	check(not CombatAnatomy.protection(victim.character, CombatAnatomy.profile(victim.character).get_zone("head"), "slash", "front").armored, "Rumpfrüstung schützt Kopf weiterhin nicht")
	armor.armor_direction_factors = {"side": 0.5, "rear": 0.25}
	check(CombatAnatomy.protection(victim.character, torso, "slash", "rear").amount == 2 and CombatAnatomy.protection(victim.character, torso, "slash", "front").amount == 8, "Teilweise Item-Overrides ersetzen nur gewählte Richtungen")
	armor.armor_direction_factors.rear = 0.0
	check(not CombatAnatomy.protection(victim.character, torso, "slash", "rear").armored, "Faktor null bedeutet keine rückseitige Abdeckung")
	attacker.position = Vector3(0, 0, -2)
	check(CombatResolver.resolve_damage(actor, target, 1, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "torso", "slash") == 1, "Unbedeckter Rücken behält ungerüsteten Mindestschaden")
	armor.armor_direction_factors = {}
	victim.character.body_profile_id = "beetle"
	armor.armor_zones = ["head"]
	var beetle_head := CombatAnatomy.profile(victim.character).get_zone("head")
	for direction in ["front", "side", "rear"]:
		check(CombatAnatomy.protection(victim.character, beetle_head, "slash", direction).amount == 10, "Käfer behält natürlichen Schutz und gleichmäßige Rüstung: " + direction)
	victim.character.body_profile_id = "human"
	armor.armor_zones = ["torso"]
	armor.armor_protection.slash = 5
	check(CombatAnatomy.protection(victim.character, torso, "slash", "side").amount == 4 and CombatAnatomy.protection(victim.character, torso, "slash", "rear").amount == 3, "Bruchteile des Rüstungsschutzes werden einmal gerundet")
	var action := CombatAction.new()
	action.actor = actor
	action.item = load("res://src/resources/items/schwert.tres")
	action.item_usage_mode = action.item.usage_modes[0]
	var profile := load("res://src/resources/combat/ai/melee_default.tres")
	var front_score := PLANNER._attack_score(action, target, "torso", profile, Vector3(0, 0, 2))
	var rear_score := PLANNER._attack_score(action, target, "torso", profile, Vector3(0, 0, -2))
	check(is_equal_approx(rear_score - front_score, 2.0 * profile.damage_weight), "KI bewertet Schutz aus geplanter Position statt tatsächlichem alten Standort")
	for invalid in [{"back": 0.5}, {"rear": -0.1}, {"front": 2.1}, {"side": "bad"}, {"rear": INF}]:
		var codec := WorldValueCodec.new()
		var data: Dictionary = codec.encode(armor)
		data.value.armor_direction_factors = {"kind": "Dictionary", "value": invalid}
		check(codec.decode(data) == null and codec.failed, "Ungültige Richtungsdaten abgewiesen: " + str(invalid))
	attacker.free()
	victim.free()
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	game.party.leader.equip("rumpf", armor)
	game.game_windows.open_page(2)
	for frame in 3: await get_tree().process_frame
	var view := game.game_windows._embedded_views[0] as InventoryUI
	view._inspect_equipment("rumpf")
	check(view._stats.text.contains("vorn 100 %") and view._stats.text.contains("seitlich 75 %") and view._stats.text.contains("hinten 50 %"), "Inventar erklärt die Richtungsfaktoren")
	if "--visual-smoke" in OS.get_cmdline_user_args():
		view._inspect_item(load("res://src/resources/items/eisenhelm.tres"))
		for frame in 4: await get_tree().process_frame
		view._stats.get_parent().scroll_vertical = 40
		for frame in 2: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.directional-armor-preview.png")
	game.game_windows.close()
	armor.armor_direction_factors = {"front": 1.25, "side": 0.5, "rear": 0.0}
	var store := WorldSaveStore.new()
	var path := "res://.directional-armor-test.json"
	var saved := game.level_manager.save_world(path)
	check(saved == OK, "Welt mit angepassten Richtungsfaktoren speicherbar")
	if saved != OK:
		game.free()
		get_tree().quit(1)
		return
	var world := store.read(path)
	check(world != null and world.characters.get_character("dannerman").inventory.equipment.rumpf.armor_direction_factors == armor.armor_direction_factors, "Richtungsfaktoren überleben Welt-Rundlauf")
	armor.armor_direction_factors.rear = -0.1
	check(store.write(GameState.world_state, path) != OK, "Writer lehnt ungültigen Richtungsfaktor ab")
	check(store.read(path) != null, "Ungültiges Schreiben erhält letzten gültigen Spielstand")
	armor.armor_direction_factors.rear = 0.0
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(json.version == 14, "Writer verwendet Speicherversion 14")
	strip_factors(json.world)
	json.version = 13
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(json))
	file.close()
	world = store.read(path)
	check(world != null and world.characters.get_character("dannerman").inventory.equipment.rumpf.armor_direction_factors.is_empty(), "Vollständiger Version-13-Spielstand ergänzt Standardfaktoren")
	json.version = 14
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(json))
	file.close()
	check(store.read(path) == null, "Version 14 ohne neues Rüstungsfeld wird abgelehnt")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
	game.free()
	await get_tree().process_frame
	print("directional_armor: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
