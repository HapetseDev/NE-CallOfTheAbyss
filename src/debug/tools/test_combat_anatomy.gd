extends Node3D

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func actor_at(at: Vector3) -> Playable:
	var actor := Playable.new()
	actor.character = CharacterResource.new()
	actor.character.ensure_initialized()
	add_child(actor)
	actor.position = at
	actor.set_physics_process(false)
	actor.character.koerperkraft = 0
	actor.character.gewandheit = 0
	actor.character.robustheit = 0
	actor.health = 1000
	return actor

func _ready() -> void:
	var actor := actor_at(Vector3(0, 0, 2))
	var victim := actor_at(Vector3.ZERO)
	var attacker := CombatParticipant.new(actor)
	var target := CombatParticipant.new(victim)
	for id in CombatAnatomy.PROFILE_PATHS:
		victim.character.body_profile_id = id
		var body := CombatAnatomy.profile(victim.character)
		check(body.profile_id == id and body.get_zone(body.default_zone_id) != null, id + " Profil lädt")
		var ids: Array[String] = []
		for zone in body.zones:
			check(zone.zone_id not in ids and zone.size.x > 0 and zone.size.y > 0 and zone.size.z > 0 and zone.damage_multiplier > 0, id + ": gültige Zone " + zone.zone_id)
			ids.append(zone.zone_id)
	victim.character.body_profile_id = "human"
	check(CombatAnatomy.direction(actor, victim) == "front", "Front relativ zur Blickrichtung")
	actor.position = Vector3(2, 0, 0)
	check(CombatAnatomy.direction(actor, victim) == "side", "Seite relativ zur Blickrichtung")
	actor.position = Vector3(0, 0, -2)
	check(CombatAnatomy.direction(actor, victim) == "rear", "Rücken relativ zur Blickrichtung")
	victim.facing_direction = Vector3.FORWARD
	check(CombatAnatomy.direction(actor, victim) == "front", "Drehung kehrt Front/Rücken um")
	victim.facing_direction = Vector3.BACK
	actor.position = Vector3(0, 0, 2)
	var torso := CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "torso")
	var head := CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "head")
	var arm := CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "forearm_left")
	check(head > torso and torso > arm, "Kopf empfindlicher als Rumpf und Unterarm")
	var helmet := load("res://src/resources/items/lederhelm.tres") as ItemData
	victim.character.inventory.equip("kopf", helmet)
	check(CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "head", "slash") == head - 2, "Helm mindert Schnittschaden am Kopf")
	check(CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "torso", "slash") == torso, "Helm schützt Rumpf nicht")
	victim.character.inventory.unequip("kopf")
	victim.character.inventory.equip("guertel_1", helmet)
	check(CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "head", "slash") == head, "Schnellausrüstung schützt Kopf nicht")
	victim.character.body_profile_id = "beetle"
	var shell_slash := CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "carapace", "slash")
	var shell_blunt := CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "carapace", "blunt")
	var belly := CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "belly", "slash")
	check(shell_slash < shell_blunt and shell_blunt < belly, "Käferpanzer unterscheidet Schadensarten, Bauch bleibt verwundbar")
	check(CombatResolver.resolve_damage(attacker, target, 1, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "carapace", "slash") == 0, "Natürlicher Panzer darf vollständig abfangen")
	victim.character.body_profile_id = "animal"
	check(CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, null, null, "torso") == 10, "Ungerüstetes Tier ohne künstlichen Rüstungsbonus")
	victim.character.body_profile_id = "human"
	victim.character.gewandheit = 10
	var rng := RandomNumberGenerator.new()
	var saved_state := 0
	for candidate_seed in range(1000):
		rng.seed = candidate_seed
		saved_state = rng.state
		var roll := rng.randf()
		if roll > 0.075 and roll < 0.3:
			break
	rng.state = saved_state
	actor.position = Vector3(0, 0, 2)
	check(CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, rng) == 0, "Frontangriff wird ausgewichen")
	rng.state = saved_state
	actor.position = Vector3(0, 0, -2)
	check(CombatResolver.resolve_damage(attacker, target, 10, CharacterEnums.Attribute.KOERPERKRAFT, rng) > 0, "Identischer Wurf trifft von hinten")
	victim.character.gewandheit = 0
	actor.position = Vector3(0, 0, 2)
	var sword := load("res://src/resources/items/schwert.tres") as ItemData
	var hit := CombatResolver.get_item_attack_hit(attacker, target, sword.usage_modes[0], "head")
	check(not hit.is_empty() and hit.zone_id == "head", "Räumlicher Kopfstrahl trifft Kopfbox")
	check(CombatResolver.get_item_attack_hit(attacker, target, sword.usage_modes[0], "not_a_zone").is_empty(), "Ungültige Zielzone verworfen")
	var codec := WorldValueCodec.new()
	var encoded: Dictionary = codec.encode(victim.character)
	var restored := codec.decode(encoded) as CharacterResource
	check(restored != null and restored.body_profile_id == "human", "Körperprofil überlebt Codec-Rundlauf")
	encoded.value.erase("body_profile_id")
	var old := WorldValueCodec.new()
	old.migrate_legacy_anatomy = true
	check((old.decode(encoded) as CharacterResource).body_profile_id == "human", "Alte Figuren erhalten Menschenprofil")
	check(WorldValueCodec.new().decode(encoded) == null, "Aktuelles Schema verlangt Körperprofil")
	encoded.value.body_profile_id = "unknown"
	check(WorldValueCodec.new().decode(encoded) == null, "Unbekanntes Profil wird abgelehnt")
	var armor_data: Dictionary = WorldValueCodec.new().encode(helmet)
	var restored_helmet := WorldValueCodec.new().decode(armor_data) as ItemData
	check(restored_helmet != null and restored_helmet.armor_zones == ["head"] and restored_helmet.armor_protection.slash == 2, "Rüstungsabdeckung und Schutz überleben Rundlauf")
	for bad in [-1.0, INF, "2"]:
		var broken: Dictionary = WorldValueCodec.new().encode(helmet)
		broken.value.armor_protection.value.slash = bad
		check(WorldValueCodec.new().decode(broken) == null, "Ungültiger Rüstungsschutz abgelehnt")
	armor_data.value.erase("armor_zones")
	armor_data.value.erase("armor_protection")
	var legacy := WorldValueCodec.new()
	legacy.migrate_legacy_anatomy = true
	check((legacy.decode(armor_data) as ItemData).armor_zones.is_empty(), "Alte Rüstung verwendet Körperplatzabdeckung")
	await _test_cover_and_ui(actor, victim)
	await _test_world_save()
	print("combat_anatomy: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_cover_and_ui(actor: Playable, victim: Playable) -> void:
	var session := CombatSession.new()
	add_child(session)
	session.set_process(false)
	var attacker := session.admit(actor, CombatParticipantResolver.SIDE_ATTACKER)
	var target := session.admit(victim, CombatParticipantResolver.SIDE_VICTIM)
	var wall := StaticBody3D.new()
	wall.collision_layer = 16
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.65, 0.2)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.position = Vector3(0, 0.325, 1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mode := (load("res://src/resources/items/bogen.tres") as ItemData).usage_modes[0]
	check(CombatResolver.get_item_attack_hit(attacker, target, mode).is_empty(), "Niedrige Deckung verdeckt Rumpf")
	var hit := CombatResolver.get_item_attack_hit(attacker, target, mode, "head")
	check(not hit.is_empty() and hit.zone_id == "head", "Kopf über Deckung bleibt räumlich erreichbar")
	actor.character.inventory.add_item(load("res://src/resources/items/pfeil.tres"), 1)
	var turn := StateCombatTurn.new()
	turn.player = actor
	turn._session = session
	turn._participant = attacker
	turn._vbox = VBoxContainer.new()
	turn.add_child(turn._vbox)
	var bow := load("res://src/resources/items/bogen.tres") as ItemData
	turn._render_item_target_menu(bow, mode)
	var alternative := false
	for child in turn._vbox.get_children():
		if child is Button and child.text.contains("andere Trefferstelle möglich") and not child.disabled:
			alternative = true
	check(alternative, "Zielmenü erlaubt Trefferstellen trotz verdecktem Rumpf")
	turn._render_item_zone_menu(bow, mode, target)
	var head_button := false
	for child in turn._vbox.get_children():
		if child is Button and child.text.begins_with("Kopf") and not child.disabled:
			head_button = true
	check(head_button, "Trefferstellenmenü bietet erreichbaren Kopf an")
	turn._preview_attack(target, mode, "head")
	var vertices: PackedVector3Array = turn._attack_line.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices[1].is_equal_approx(CombatAnatomy.aim_point(victim, "head")), "Vorschau endet an gewählter räumlicher Trefferstelle")
	turn._destroy_menu()
	turn.free()
	wall.free()
	actor.exit_combat_mode()
	victim.exit_combat_mode()
	session.free()

func _strip_anatomy(value: Variant) -> void:
	if value is Dictionary:
		if value.get("kind") == "CharacterResource":
			value.value.erase("body_profile_id")
		elif value.get("kind") == "ItemUsageMode":
			value.value.erase("damage_type")
		elif value.get("kind") == "ItemData":
			value.value.erase("armor_zones")
			value.value.erase("armor_protection")
		for child in value.values():
			_strip_anatomy(child)
	elif value is Array:
		for child in value:
			_strip_anatomy(child)

func _test_world_save() -> void:
	GameState.reset_session()
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	await get_tree().physics_frame
	var sheet := game.party.leader.character
	sheet.body_profile_id = "beetle"
	sheet.inventory.equip("kopf", load("res://src/resources/items/lederhelm.tres"))
	var path := "res://.necota-anatomy-test.json"
	var store := WorldSaveStore.new()
	var saved := game.level_manager.save_world(path)
	check(saved == OK, "Anatomie wird im echten Weltzustand gespeichert")
	if saved != OK:
		game.free()
		return
	var world := store.read(path)
	check(world != null and world.characters.get_character(sheet.character_id).body_profile_id == "beetle", "Profil überlebt Welt-Speicherrundlauf")
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	json.version = 12
	_strip_anatomy(json.world)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(json))
	file.close()
	var migrated := store.read(path)
	check(migrated != null and migrated.characters.get_character(sheet.character_id).body_profile_id == "human", "Vollständiger Version-12-Spielstand migriert")
	json.version = WorldSaveStore.VERSION
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(json))
	file.close()
	check(store.read(path) == null, "Neue Speicherversion lehnt fehlende Anatomiefelder ab")
	DirAccess.remove_absolute(path)
	game.free()
