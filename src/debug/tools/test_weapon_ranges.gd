extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	var origin := Node3D.new()
	var target := Node3D.new()
	add_child(origin)
	add_child(target)
	for key in ["dolch", "schwert", "speer", "bogen"]:
		var item := load("res://src/resources/items/%s.tres" % key) as ItemData
		check(item != null, key + " lädt")
		var mode := item.usage_modes[0]
		target.position = Vector3(mode.range_meters, 0, 0)
		check(mode.is_in_range(origin, target), key + " trifft exakt an der Grenze")
		target.position.x += 0.01
		check(not mode.is_in_range(origin, target), key + " verwirft Ziel außerhalb")
		target.position = Vector3(0, mode.range_meters + 0.01, 0)
		check(not mode.is_in_range(origin, target), key + " berücksichtigt Höhe")
		var codec := WorldValueCodec.new()
		var saved: Dictionary = codec.encode(item)
		var restored := codec.decode(saved) as ItemData
		check(restored != null and restored.usage_modes[0].range_meters == mode.range_meters, key + " Speicherrundlauf")
		var scene := load("res://src/world/objects/items/%s.tscn" % key) as PackedScene
		var instance := scene.instantiate() as BasicItem
		check(instance.item_data.item_id == item.item_id, key + " Weltobjekt gebunden")
		instance.free()
	var mode := ItemUsageMode.new()
	var codec := WorldValueCodec.new()
	var legacy: Dictionary = codec.encode(mode)
	legacy.value.erase("range_meters")
	legacy.value.erase("ammunition_item_id")
	codec.migrate_legacy_weapon_ranges = true
	check((codec.decode(legacy) as ItemUsageMode).range_meters == 1.5, "Alte Nahkampfmodi migrieren")
	legacy.value.range_type = ItemUsageMode.RangeType.THROWN
	check((codec.decode(legacy) as ItemUsageMode).range_meters == 10.0, "Alte Wurfmodi migrieren")
	for bad in [-1.0, 0.0, INF, NAN, "2"]:
		var invalid: Dictionary = WorldValueCodec.new().encode(mode)
		invalid.value.range_meters = bad
		var reader := WorldValueCodec.new()
		check(reader.decode(invalid) == null and reader.failed, "Ungültige Reichweite abgelehnt")
	var actor := Playable.new()
	var victim := Playable.new()
	actor.character = CharacterResource.new()
	victim.character = CharacterResource.new()
	actor.character.ensure_initialized()
	victim.character.ensure_initialized()
	add_child(actor)
	add_child(victim)
	var bow := load("res://src/resources/items/bogen.tres").duplicate(true) as ItemData
	bow.usage_modes[0].requires_line_of_sight = false
	actor.character.inventory.equip("primaer_hand", bow)
	var action := CombatAction.new()
	action.type = CombatAction.ActionType.ITEM
	action.actor = CombatParticipant.new(actor)
	action.targets = [CombatParticipant.new(victim)]
	action.item = bow
	action.item_usage_mode = bow.usage_modes[0]
	check(CombatResolver.resolve_action(action).failed_reason == "no_ammunition", "Ohne Pfeil kein Schuss")
	var arrow := load("res://src/resources/items/pfeil.tres") as ItemData
	actor.character.inventory.add_item(arrow, 2)
	victim.position = Vector3(20.01, 0, 0)
	check(CombatResolver.resolve_action(action).failed_reason == "out_of_range", "Zu weit entfernt: kein Schuss")
	check(actor.character.inventory.slots[0].count == 2, "Außer Reichweite bleibt Munition erhalten")
	victim.position = Vector3(20.0, 0, 0)
	check(CombatResolver.resolve_action(action).outcomes.size() == 1, "Bogen führt Schuss aus")
	check(actor.character.inventory.slots[0].count == 1, "Ein Pfeil verbraucht")
	check(actor.character.inventory.equipment.primaer_hand == bow, "Bogen bleibt ausgerüstet")
	var sword := load("res://src/resources/items/schwert.tres").duplicate(true) as ItemData
	sword.break_chance = 1.0
	actor.character.inventory.equip("primaer_hand", sword)
	action.item = sword
	action.item_usage_mode = sword.usage_modes[0]
	victim.position.x = 2.01
	var health_before := victim.health
	var result := CombatResolver.resolve_action(action)
	check(not result.success and result.failed_reason == "out_of_range" and result.outcomes.is_empty(), "Schwert außerhalb Reichweite schlägt ausdrücklich fehl")
	check(victim.health == health_before and actor.character.inventory.equipment.primaer_hand == sword, "Fehlschlag ohne Schaden oder Bruch")
	action.item_usage_mode.consumes_item = true
	check(not CombatResolver.resolve_action(action).success and actor.character.inventory.equipment.primaer_hand == sword, "Zu weiter Wurf verbraucht Gegenstand nicht")
	action.item_usage_mode.consumes_item = false
	var session := CombatSession.new()
	action.actor.side = CombatParticipantResolver.SIDE_ATTACKER
	action.targets[0].side = CombatParticipantResolver.SIDE_VICTIM
	session.participants.assign([action.actor, action.targets[0]])
	var turn := StateCombatTurn.new()
	turn.player = actor
	turn._session = session
	turn._participant = action.actor
	turn._vbox = VBoxContainer.new()
	turn.add_child(turn._vbox)
	turn._render_item_target_menu(sword, sword.usage_modes[0])
	var red_target := false
	for child in turn._vbox.get_children():
		if child is Button and child.text.contains("Außerhalb der Reichweite von Schwert"):
			red_target = child.disabled and child.get_theme_color("font_disabled_color") == NEColors.DANGER
	check(red_target, "Ziel vor Auswahl rot mit Waffenname und Reichweitenhinweis")
	turn._render_item_zone_menu(sword, sword.usage_modes[0], action.targets[0])
	var red_zone := false
	for child in turn._vbox.get_children():
		if child is Button and not child.is_queued_for_deletion() and child.text.contains("Außerhalb der Reichweite von Schwert"):
			red_zone = child.disabled and child.get_theme_color("font_disabled_color") == NEColors.DANGER
	check(red_zone, "Auch Trefferstellen zeigen roten Reichweitenhinweis")
	victim.position.x = 1
	turn._render_item_target_menu(sword, sword.usage_modes[0])
	var reachable := false
	for child in turn._vbox.get_children():
		if child is Button and not child.is_queued_for_deletion() and child.text != "Zurück":
			reachable = not child.disabled and not child.has_theme_color_override("font_disabled_color")
	check(reachable, "Erreichbares Ziel wieder normal auswählbar")
	# Nach Anzeige in Reichweite verändert sich die Position: Resolver prüft erneut.
	victim.position.x = 3
	check(CombatResolver.resolve_action(action).failed_reason == "out_of_range", "Positionsänderung nach Zielanzeige wird beim Angriff erkannt")
	var punch := AbilityCatalog.get_definition("fausthieb").duplicate(true) as AbilityDefinition
	punch.mana_cost = 1
	actor.mana = 5
	action.type = CombatAction.ActionType.ABILITY
	action.ability = punch
	result = CombatResolver.resolve_action(action)
	check(not result.success and result.failed_reason == "out_of_range" and actor.mana == 5, "Fausthieb außerhalb Reichweite scheitert vor Ressourcenverbrauch")
	turn._render_ability_target_menu(punch, CombatParticipantResolver.SIDE_VICTIM)
	var red_punch := false
	for child in turn._vbox.get_children():
		if child is Button and not child.is_queued_for_deletion() and child.text.contains("Außerhalb der Reichweite"):
			red_punch = child.disabled and child.get_theme_color("font_disabled_color") == NEColors.DANGER
	check(red_punch, "Fausthieb-Zielmenü warnt ebenfalls rot")
	turn._destroy_menu()
	turn.free()
	session.free()
	actor.free()
	victim.free()
	print("weapon_ranges: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
