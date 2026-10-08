extends Node

## Godot --headless --path <projekt> res://src/debug/tools/test_character_registry.tscn
## Als Szene starten, damit die Projekt-Autoloads vor den Tests geladen sind.

var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_identity_and_initialization()
	_test_nested_isolation()
	_test_rejections()
	_test_reset()
	_test_external_resources()
	_test_bandit_respawn()
	_test_all_characters()
	await _test_session_lifecycle()
	_check(GameState.character_registry is CharacterRegistry, "GameState besitzt eine Registry")
	print("character_registry: %d Checks, %d Fehler" % [_checks, _failed])
	get_tree().quit(1 if _failed else 0)


func _test_identity_and_initialization() -> void:
	var registry := CharacterRegistry.new()
	var template := CharacterResource.new()
	template.resource_local_to_scene = true
	var character := registry.register_character("elara", template)
	_check(character != null and character != template, "Auch lokale Vorlagen werden kopiert")
	_check(character.character_id == "elara", "Laufzeit-ID wird gesetzt")
	_check(character.staerkepunkte == character.get_staerkepunkte_basis(), "Startwerte werden initialisiert")
	_check(template.character_id.is_empty() and template.inventory == null and template.staerkepunkte == 0, "Vorlage bleibt unverändert")
	character.staerkepunkte = 0
	character.konzentrationspunkte = 0
	character.gold = 17
	character.character_name = "Neuer Anzeigename"
	_check(registry.register_character("elara", template) == character, "Registrierung ist idempotent")
	_check(registry.get_character("elara") == character, "Abruf liefert dieselbe Instanz")
	_check(character.staerkepunkte == 0 and character.konzentrationspunkte == 0 and character.gold == 17, "Erneute Registrierung setzt keinen Zustand zurück")
	_check(registry.get_character("unbekannt") == null, "Unbekannte ID erzeugt keine Daten")
	var avatar := Node.new()
	avatar.set_meta("character", character)
	avatar.free()
	_check(registry.get_character("elara") == character, "Daten überleben den Abbau eines referenzierenden Nodes")


func _test_nested_isolation() -> void:
	var registry := CharacterRegistry.new()
	var template := _make_template()
	var first := registry.register_character("guard_01", template)
	var second := registry.register_character("guard_02", template)
	first.inventory.slots[0].count = 1
	first.inventory.slots[0].item.item_name = "Geändert"
	first.inventory.equipment["waffe"].weight = 42.0
	first.learned_skills[0].level = 9
	first.beziehungen[0].wertung = -5
	first.begleiter[0].details = "Geändert"
	first.faction_ids.append("weitere_fraktion")
	_check(first != second and first.inventory != second.inventory, "Charaktere und Inventare sind unabhängig")
	for untouched in [template, second]:
		_check(untouched.inventory.slots[0].count == 3, "Slotmengen sind unabhängig")
		_check(untouched.inventory.slots[0].item.item_name == "Testgegenstand", "Verschachtelte Items sind unabhängig")
		_check(untouched.inventory.equipment["waffe"].weight == 0.3, "Dictionary-Resources sind unabhängig")
		_check(untouched.learned_skills[0].level == 1, "Skills sind unabhängig")
		_check(untouched.beziehungen[0].wertung == 2, "Beziehungen sind unabhängig")
		_check(untouched.begleiter[0].details.is_empty(), "Begleiterdaten sind unabhängig")
		_check(untouched.faction_ids.size() == 1, "Werte-Arrays sind unabhängig")
	var changes: Array[int] = [0, 0, 0]
	first.inventory_changed.connect(func(): changes[0] += 1)
	second.inventory_changed.connect(func(): changes[1] += 1)
	template.inventory_changed.connect(func(): changes[2] += 1)
	first.inventory.remove_item(first.inventory.slots[0].item)
	_check(changes == [1, 0, 0], "Inventarsignale erreichen nur den zugehörigen Charakter")


func _test_rejections() -> void:
	var registry := CharacterRegistry.new()
	var reasons: Array[StringName] = []
	registry.registration_rejected.connect(func(_id: String, reason: StringName): reasons.append(reason))
	var template := CharacterResource.new()
	_check(registry.register_character("", template) == null, "Leere ID wird abgelehnt")
	_check(registry.register_character(" elara ", template) == null, "Uneindeutige ID wird abgelehnt")
	_check(registry.register_character("elara", null) == null, "Fehlende Vorlage wird abgelehnt")
	template.character_id = "elara"
	_check(registry.register_character("bandit", template) == null, "Widersprüchliche Vorlagen-ID wird abgelehnt")
	var character := registry.register_character("elara", template)
	character.gold = 99
	_check(registry.register_character("elara", CharacterResource.new()) == null, "Andere Vorlage für belegte ID wird abgelehnt")
	_check(registry.get_character("elara") == character and character.gold == 99, "Konflikt überschreibt keine Daten")
	_check(registry.get_character("bandit") == null, "Fehlgeschlagene Registrierung hinterlässt keinen Eintrag")
	_check(reasons == [&"invalid_id", &"invalid_id", &"missing_template", &"template_id_mismatch", &"conflicting_template"], "Fehlerursachen sind eindeutig")


func _test_reset() -> void:
	var registry := CharacterRegistry.new()
	var template := _make_template()
	var old := registry.register_character("guard", template)
	old.gold = 99
	old.inventory.slots[0].count = 1
	registry.clear()
	registry.clear()
	_check(registry.get_character("guard") == null, "Reset entfernt die Registrierung und ist wiederholbar")
	var fresh := registry.register_character("guard", template)
	_check(fresh != old and fresh.gold == template.gold and fresh.inventory.slots[0].count == 3, "Neue Sitzung erhält frische Startdaten")
	_check(old.gold == 99, "Reset mutiert keine alten externen Referenzen")
	registry.clear()
	_check(registry.register_character("guard", CharacterResource.new()) != null, "Reset entfernt auch die Vorlagenbindung")


func _test_external_resources() -> void:
	var template := load("res://src/resources/characters/sheets/bandit_01.tres") as CharacterResource
	var original_name := template.inventory.slots[0].item.item_name
	var registry := CharacterRegistry.new()
	var character := registry.register_character("bandit_01", template)
	_check(character.inventory.slots[0].item != template.inventory.slots[0].item, "Externe .tres-Items werden ebenfalls isoliert")
	character.inventory.slots[0].item.item_name = "Nur Laufzeit"
	_check(template.inventory.slots[0].item.item_name == original_name, "Geladene Itemvorlage bleibt unverändert")


func _test_bandit_respawn() -> void:
	GameState.character_registry.clear()
	var scene := load("res://src/gameplay/character/npc/EnemyNPC.tscn") as PackedScene
	var template := load("res://src/resources/characters/sheets/bandit_01.tres") as CharacterResource
	var original_count := template.inventory.slots[0].count
	var original_gold := template.gold
	var first := scene.instantiate() as NPC
	add_child(first)
	var character := first.character
	_check(character == GameState.character_registry.get_character("bandit_01"), "Bandit bindet die registrierte Instanz ohne zweite Kopie")
	_check(first.inventory_component.character == character, "Inventaradapter verwendet registrierte Daten")
	first.take_damage(first.health)
	first.mana = 0
	first.gold = 73
	var item := ItemData.new()
	item.item_id = "respawn_test"
	first.add_item(item, 2)
	var relationship := RelationshipEntry.new()
	relationship.target_id = "elara"
	relationship.wertung = -4
	character.add_beziehung(relationship)
	first.free()
	_check(character.inventory_changed.get_connections().is_empty(), "Entfernte Weltfigur hinterlässt keine Inventarlistener")
	var second := scene.instantiate() as NPC
	add_child(second)
	_check(second.character == character, "Erneut erzeugter Bandit verwendet denselben Datensatz")
	_check(second.health == 0 and second.mana == 0, "Respawn füllt 0/0-Punkte nicht auf")
	_check(second.gold == 73 and second.has_item("respawn_test"), "Gold und hinzugefügte Items überleben Respawn")
	_check(second.character.beziehungen.back().wertung == -4, "Beziehungen überleben Respawn")
	_check(second.character.inventory.slots.back().count == 2, "Itemmengen überleben Respawn")
	var changes: Array[int] = [0]
	second.inventar_geaendert.connect(func(): changes[0] += 1)
	second.bind_character(character)
	second.remove_item(item)
	_check(changes[0] == 1, "Erneutes Binden erzeugt keine doppelten Inventarsignale")
	_check(second.character == character and second.health == 0, "bind_character bewahrt registrierte Identität und Zustand")
	second.free()
	_check(template.gold == original_gold and template.inventory.slots.size() == 1 and template.inventory.slots[0].count == original_count and template.beziehungen.is_empty(), "Banditenvorlage bleibt unverändert")
	GameState.character_registry.clear()
	var fresh := scene.instantiate() as NPC
	add_child(fresh)
	_check(fresh.character != character and fresh.gold == original_gold and not fresh.has_item("respawn_test"), "Neue Sitzung erzeugt frischen Banditen")
	_check(fresh.health == fresh.get_max_health(), "Frischer Bandit erhält initiale Punkte")
	fresh.free()
	GameState.character_registry.clear()

	var merchant_scene := load("res://src/gameplay/character/npc/MerchantNPC.tscn") as PackedScene
	var merchant := merchant_scene.instantiate() as NPC
	add_child(merchant)
	_check(merchant.character != null and merchant.use_character_registry, "Migrierter Händler bleibt funktionsfähig")
	_check(GameState.character_registry.get_character(merchant.character.character_id) == merchant.character, "Händler verwendet registrierte Identität")
	merchant.free()
	GameState.reset_session()


func _test_all_characters() -> void:
	var paths := {
		"dannerman": "res://src/gameplay/character/player/dannerman/dannerman.tscn",
		"shalka": "res://src/gameplay/character/player/shalka/shalka.tscn",
		"merchant_01": "res://src/gameplay/character/npc/MerchantNPC.tscn",
		"quest_giver_01": "res://src/gameplay/character/npc/QuestNPC.tscn",
		"test_npc": "res://src/gameplay/character/npc/TestNPC.tscn",
	}
	for id in paths:
		GameState.reset_session()
		var scene := load(paths[id]) as PackedScene
		var first := scene.instantiate() as Playable
		add_child(first)
		var data := first.character
		_check(data == GameState.character_registry.get_character(id), id + ": registrierte Identität")
		data.staerkepunkte = 0
		data.konzentrationspunkte = 0
		data.gold = 123
		data.inventory.slots.clear()
		data.learned_skills[0].level = 7
		first.free()
		var second := scene.instantiate() as Playable
		add_child(second)
		_check(second.character == data, id + ": Identität überlebt Respawn")
		_check(second.health == 0 and second.mana == 0 and second.gold == 123, id + ": Werte bleiben erhalten")
		_check(second.inventory.is_empty(), id + ": leeres Inventar wird nicht aufgefüllt")
		_check(second.character.learned_skills[0].level == 7, id + ": Skills bleiben erhalten")
		second.free()
	GameState.reset_session()


func _test_session_lifecycle() -> void:
	# Test-Runner bleibt neben den echten aktuellen Szenen am Root erhalten.
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://src/core/main_game/main_game.tscn")
	await get_tree().scene_changed
	var game := get_tree().current_scene as MainGame
	var leader := game.party.leader.character
	var follower := game.party.followers[0].character
	var bandit := GameState.character_registry.get_character("bandit_01")
	var merchant := GameState.character_registry.get_character("merchant_01")
	var quest := GameState.character_registry.get_character("quest_giver_01")
	leader.gold = 321
	follower.gold = 234
	bandit.gold = 987
	merchant.gold = 876
	quest.gold = 765
	GameState.set_flag("quest_bandit_done", true)
	for i in 2:
		LevelManager.load_level(MainGame.DEFAULT_LEVEL)
		_check(game.party.leader.character == leader and game.party.followers[0].character == follower, "Levelwechsel erhält Partyidentität")
		_check(GameState.character_registry.get_character("bandit_01") == bandit and bandit.gold == 987, "Levelwechsel erhält Banditendaten")
		var npc := game.level_root.find_child("MerchantNPC", true, false) as NPC
		_check(npc.character == merchant and npc.gold == 876, "Levelwechsel bindet Händler erneut")
		_check(GameState.character_registry.get_character("quest_giver_01") == quest and quest.gold == 765, "Levelwechsel erhält Questgeberdaten")
		_check(GameState.get_flag("quest_bandit_done"), "Levelwechsel erhält Flags")
	var shop_template := load("res://src/resources/items/shop/shops/haendler_01.tres") as ShopData
	var stock := shop_template.entries[0].stock
	game.shop_manager.get_shop("haendler_01").entries[0].stock = 123
	_check(shop_template.entries[0].stock == stock, "Shopvorlage wird nicht verändert")
	ShopManager.open("haendler_01", game.party.leader)
	game.game_windows.open_page(5)
	_check(GameState.is_player_input_locked(), "Verschachtelte Menüs sperren Eingabe")
	game.game_windows._on_main_menu_pressed()
	await get_tree().scene_changed
	_check(MainGame.instance == null and CombatManager.instance == null and ShopManager.instance == null, "Alte Systeminstanzen werden entfernt")
	_check(not GameState.is_player_input_locked() and not GameState.has_flag("quest_bandit_done"), "Hauptmenü bereinigt Flags und sämtliche Sperren")
	_check(GameState.character_registry.get_character("dannerman") == null, "Sitzungsende leert Registrierung")
	var menu := get_tree().current_scene as MainMenu
	menu._on_start_pressed()
	await get_tree().scene_changed
	game = get_tree().current_scene as MainGame
	_check(game.party.leader.character != leader and game.party.leader.gold == 50, "Neues Spiel erzeugt frischen Dannerman")
	_check(game.party.followers[0].character != follower and game.party.followers[0].gold == 20, "Neues Spiel erzeugt frische Shalka")
	_check(game.party.leader.inventory.size() == 1, "Neues Spiel vergibt genau ein Startmesser")
	_check(GameState.character_registry.get_character("bandit_01") != bandit, "Neues Spiel erzeugt frische NPC-Daten")
	_check(game.shop_manager.get_shop("haendler_01").entries[0].stock == stock, "Neues Spiel stellt Händlerbestand wieder her")
	_check(not GameState.is_player_input_locked() and not GameState.has_flag("in_combat"), "Neues Spiel beginnt ohne alte Sperren oder Kampfflags")
	var enemy := game.level_root.find_child("EnemyNPC", true, false) as NPC
	CombatManager.trigger_attack(game.party.leader, enemy)
	var old_session := CombatManager.instance.active_session
	_check(old_session != null and GameState.get_flag("in_combat"), "Abbruchtest startet echten Kampf")
	var interaction := enemy.get_node("Interaction") as NPCInteraction
	DialogueSystem.start_npc_dialogue(interaction.data, game.party.leader, interaction)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(GameState.is_player_input_locked(), "Dialog während Kampf sperrt Eingabe")
	game.game_windows.open_page(5)
	game.game_windows._on_main_menu_pressed()
	await get_tree().scene_changed
	_check(not is_instance_valid(old_session) and DialogueSystem.instance == null, "Sitzungsende entfernt Kampf und Dialogsystem")
	_check(not GameState.is_player_input_locked() and not GameState.has_flag("in_combat"), "Kampf-/Dialogabbruch hinterlässt keine Sperren oder Flags")
	menu = get_tree().current_scene as MainMenu
	menu._on_start_pressed()
	await get_tree().scene_changed
	game = get_tree().current_scene as MainGame
	_check(not game.party.leader.is_in_combat_mode() and not GameState.is_player_input_locked(), "Zweiter Neustart nach Kampf/Dialog ist steuerbar")
	game.free()


func _make_template() -> CharacterResource:
	var template := CharacterResource.new()
	template.inventory = Inventory.new()
	var slot := InventorySlot.new()
	slot.item = ItemData.new()
	slot.item.item_name = "Testgegenstand"
	slot.count = 3
	template.inventory.slots.append(slot)
	template.inventory.equipment["waffe"] = ItemData.new()
	var skill := LearnedSkill.new()
	skill.skill_id = "nahkampfwaffen"
	skill.level = 1
	template.learned_skills.append(skill)
	var relationship := RelationshipEntry.new()
	relationship.target_id = "elara"
	relationship.wertung = 2
	template.beziehungen.append(relationship)
	template.begleiter.append(CompanionEntry.new())
	template.faction_ids.append("wache")
	return template


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		printerr("FAIL: " + message)
