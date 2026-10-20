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

func _actor() -> Playable:
	var actor := Playable.new()
	actor.character = CharacterResource.new()
	actor.character.ensure_initialized()
	actor.character.staerkepunkte = 1000
	return actor

func _run() -> void:
	GameState.reset_session()
	var actor := _actor()
	var target := _actor()
	add_child(actor)
	add_child(target)
	await get_tree().physics_frame
	actor.character.koerperkraft = 5
	actor.character.debug_add_skill("waffenloser_kampf", 2)
	target.character.robustheit = 0
	target.character.gewandheit = 0
	var action := CombatAction.new()
	action.actor = CombatParticipant.new(actor, &"a")
	action.targets = [CombatParticipant.new(target, &"b")]
	action.type = CombatAction.ActionType.ABILITY
	action.ability = AbilityCatalog.get_definition("fausthieb")
	var result := CombatResolver.resolve_action(action)
	check(result.outcomes[0].damage == 8, "Schlag: effektive Körperkraft 7 + halber Waffenlos-Bonus 1")
	var knife := load("res://src/resources/items/messer.tres").duplicate(true) as ItemData
	actor.character.debug_add_skill("kurze_klingen", 3)
	actor.character.inventory.equip("primaer_hand", knife)
	action.type = CombatAction.ActionType.ITEM
	action.item = knife
	action.item_usage_mode = knife.get_combat_usage_modes()[0]
	result = CombatResolver.resolve_action(action)
	check(result.outcomes[0].damage == 17, "Messer: Körperkraft 10 + Kampfwert 6 + halber Kurze-Klingen-Bonus 1")
	var bottle := ItemData.new()
	bottle.item_id = "test_bottle"
	bottle.item_name = "Testflasche"
	bottle.break_chance = 1.0
	actor.character.inventory.add_item(bottle, 2)
	actor.character.inventory.equip("nebenhand", bottle)
	action.item = bottle
	action.item_usage_mode = bottle.get_combat_usage_modes()[0]
	result = CombatResolver.resolve_action(action)
	check(result.outcomes[0].damage == 11, "Beliebiger Gegenstand addiert mindestens Kampfwert 1")
	check(actor.character.inventory.equipment.nebenhand == null, "Bruch entfernt ausgerüstetes Exemplar")
	check(actor.character.inventory.slots[0].count == 2, "Bruch berührt Rucksackstapel nicht")
	bottle.combat_value = 0
	check(bottle.get_combat_value() == 1, "Laufzeit begrenzt Kampfwert auf mindestens 1")
	bottle.combat_value = 1
	var view := load("res://src/ui/inventory/InventoryUI.tscn").instantiate() as InventoryUI
	add_child(view)
	view._inspect_item(bottle)
	check(not view._stats.text.contains("Kampfwert"), "Kampfwert 1 wird nicht angezeigt")
	view._inspect_item(knife)
	check(view._stats.text.contains("Kampfwert: 6"), "Höherer Kampfwert wird angezeigt")
	var turn := StateCombatTurn.new()
	turn.player = actor
	turn._vbox = VBoxContainer.new()
	turn.add_child(turn._vbox)
	turn._render_root()
	var offers_punch := false
	for child in turn._vbox.get_children():
		offers_punch = offers_punch or (child is Button and child.text == "Schlag")
	check(offers_punch, "Leere Hand bietet Schlag direkt im Kampfmenü")
	turn.free()
	action.item = knife
	action.item_usage_mode = knife.get_combat_usage_modes()[1]
	result = CombatResolver.resolve_action(action)
	check(result.outcomes[0].damage == 19, "Messerwurf addiert Körperkraft, Wurfwert und Kurze Klingen")
	check(actor.character.inventory.equipment.primaer_hand == null, "Messerwurf verbraucht das ausgerüstete Messer")
	var codec := WorldValueCodec.new()
	var encoded: Dictionary = codec.encode(knife)
	var restored := codec.decode(encoded) as ItemData
	check(restored != null and restored.combat_skill_id == "kurze_klingen" and restored.combat_value == 6, "Neue Itemwerte überleben Codec-Roundtrip")
	encoded.value.erase("combat_value")
	encoded.value.erase("combat_skill_id")
	encoded.value.erase("break_chance")
	encoded.value.erase("is_armor")
	var legacy := WorldValueCodec.new()
	legacy.migrate_legacy_combat_items = true
	legacy.migrate_legacy_armor_items = true
	restored = legacy.decode(encoded) as ItemData
	check(restored != null and restored.combat_value == 6 and restored.break_chance == 0.0, "Altes Messer erhält neue Felder bei Migration")
	var strict := WorldValueCodec.new()
	check(strict.decode(encoded) == null and strict.failed, "Neue Speicherstände dürfen Felder nicht auslassen")

	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	for i in 20: await get_tree().physics_frame
	var store := WorldSaveStore.new()
	var save_path := "/tmp/necota-combat-migration-test.json"
	check(store.write(GameState.world_state, save_path) == OK, "Speicherformat 10 schreibt gültigen Weltzustand")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	saved.version = 8
	_strip_combat_fields(saved.world)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	var migrated := store.read(save_path)
	check(migrated != null, "Vollständiger Version-8-Spielstand wird geladen")
	if migrated:
		var saved_knife: ItemData = migrated.characters.get_character("dannerman").inventory.slots[0].item
		check(saved_knife.combat_skill_id == "kurze_klingen" and saved_knife.combat_value == 6, "Version-8-Messer wird im Welt-Spielstand migriert")
	DirAccess.remove_absolute(save_path)
	var music := game.get_node("Systems/MusicSystem") as MusicSystem
	music.fade_seconds = 0.05
	check(music.level_player.stream is AudioStreamMP3 and music.level_player.stream.loop, "Levelmusik itcc läuft als Loop")
	await get_tree().create_timer(0.12).timeout
	var enemy := NPC.new()
	enemy.character = CharacterResource.new()
	enemy.character.ensure_initialized()
	enemy.use_character_registry = false
	game.level_root.add_child(enemy)
	enemy.battle_music_category = 1
	var session := CombatSession.new()
	session.set_process(false)
	game.get_node("Systems").add_child(session)
	var leader := CombatParticipant.new(game.party.leader, &"party")
	var hostile := CombatParticipant.new(enemy, &"enemy")
	session.participants = [leader, hostile]
	CombatManager.instance.active_session = session
	music._on_combat_started(session)
	music._on_participant_joined(hostile, session)
	await get_tree().create_timer(0.12).timeout
	check(music._mode == "battle" and music.level_player.stream_paused, "Kampfmusik pausiert Levelmusik nach Fade")
	var position := music.level_resume_position
	check(position > 0.0, "Unterbrechungsposition gespeichert")
	var battle := music.battle_players[music._battle_index]
	CombatManager.instance.active_session = null
	music._on_combat_ended(session, {})
	await get_tree().create_timer(0.12).timeout
	check(music._mode == "lingering" and is_equal_approx(battle.volume_db, music.lingering_volume_db), "Überlebender Gegner hält leise Kampfmusik nach Party-Flucht")
	check(music.level_player.stream_paused, "Levelmusik bleibt während Bedrohung pausiert")
	hostile.has_fled = true
	await get_tree().create_timer(0.12).timeout
	check(music._mode == "level" and not music.level_player.stream_paused, "Gegnerflucht setzt Levelmusik fort")
	check(music.level_player.get_playback_position() >= position, "Levelmusik setzt nicht bei 0 ein")
	check(not battle.playing, "Kampfmusik nach Rückblende gestoppt")
	# Mehrere Gegner: höchste Kategorie, Wechsel ohne Neustart desselben Lieds.
	var final_enemy := NPC.new()
	final_enemy.character = CharacterResource.new()
	final_enemy.character.ensure_initialized()
	final_enemy.use_character_registry = false
	final_enemy.battle_music_category = 3
	game.level_root.add_child(final_enemy)
	var final_participant := CombatParticipant.new(final_enemy, &"enemy")
	music.final_music_path = "res://assets/audio/music/itcc.mp3"
	music._threats.append(final_participant)
	music._refresh()
	check(music._battle_path == music.final_music_path, "Höchste Gegnerkategorie wählt das zugeordnete Lied")
	await get_tree().create_timer(0.12).timeout
	final_participant.has_fled = true
	await get_tree().create_timer(0.12).timeout
	# Erneute Bedrohung, Tod ohne aktive Kampfsitzung.
	hostile.has_fled = false
	music._threats.append(hostile)
	music._refresh()
	await get_tree().create_timer(0.12).timeout
	enemy.character.staerkepunkte = -enemy.character.get_staerkepunkte_basis()
	await get_tree().create_timer(0.12).timeout
	check(music._mode == "level", "Tod des zurückgelassenen Gegners beendet Musik")
	var level := game.level_manager.current_level
	level.music_loop = false
	music._on_level_loaded(level)
	check(not music.level_player.stream.loop, "Einmalige Levelmusik konfigurierbar")
	check(music.battle_players[1 - music._battle_index].playing, "Alte Levelmusik bleibt während der Überblendung hörbar")
	hostile.is_defeated = false
	enemy.character.staerkepunkte = 10
	music._threats.append(hostile)
	music._refresh()
	music._on_level_unloaded("test")
	check(music._threats.is_empty() and music._mode == "silence", "Levelverlassen entfernt sämtliche Musikbedrohungen")
	game.queue_free()
	actor.queue_free()
	target.queue_free()
	view.queue_free()
	await get_tree().process_frame
	print("combat_equipment_music: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _strip_combat_fields(value: Variant) -> void:
	if value is Dictionary:
		if value.get("kind") == "ItemData":
			for key in ["combat_value", "combat_skill_id", "break_chance", "is_armor"]:
				value.value.erase(key)
		for child in value.values():
			_strip_combat_fields(child)
	elif value is Array:
		for child in value:
			_strip_combat_fields(child)
