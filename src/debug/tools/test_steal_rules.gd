extends Node

class ControlledStealUI extends StealUI:
	var succeeds := true
	var rolls := 0
	func _roll_success() -> bool:
		rolls += 1
		return succeeds

var checks := 0
var failures := 0
func _ready() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func _run() -> void:
	GameState.reset_session()
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	var thief := game.party.leader
	var victim := game.level_root.find_child("MerchantNPC", true, false) as NPC
	var manager := StealManager.instance
	var ui := ControlledStealUI.new()
	manager.add_child(ui)
	manager._steal_ui = ui
	ui.closed.connect(manager._on_steal_ui_closed)
	victim.character.inventory.slots.clear()
	var item := ItemData.new()
	item.item_id = "steal_test"
	item.max_stack = 3
	victim.add_item(item, 2)
	victim.character.is_defeated = true
	StealManager.open(thief, victim)
	check(not ui.visible and not GameState.is_player_input_locked(), "Besiegtes Opfer öffnet kein Diebstahlfenster")
	victim.character.is_defeated = false
	StealManager.open(thief, victim)
	check(GameState.is_player_input_locked(), "Fenster sperrt Eingabe")
	StealManager.open(thief, victim)
	ui._on_item_selected(0)
	check(victim.inventory[0].count == 1 and thief.inventory.back().item == item, "Erfolg überträgt genau eine Einheit")
	check(ui.visible and not CombatManager.instance.is_in_combat(), "Erfolg hält Fenster offen ohne Kampf")
	item.weight = 100000
	ui._on_item_selected(0)
	check(ui.rolls == 1 and victim.inventory[0].count == 1, "Übergewicht verändert nichts und würfelt nicht")
	item.weight = 0.3
	victim.remove_item(item)
	ui._on_item_selected(0)
	check(ui.rolls == 1, "Veralteter Listeneintrag löst keinen Versuch aus")
	var potion := game.level_root.find_child("Heiltrank", true, false) as BasicItem
	potion.perform_action("pickup", victim)
	ui._refresh()
	var unique := victim.inventory[0].item
	thief.add_item(unique)
	var attempts_before := ui.rolls
	ui._on_item_selected(0)
	check(ui.rolls == attempts_before and victim.inventory.size() == 1 and not CombatManager.instance.is_in_combat(), "Ungültiger Doppelbesitz wird vor dem Würfeln abgelehnt")
	thief.remove_item(unique)
	ui._on_item_selected(0)
	check(GameState.world_state.get_object_owner("level1_potion_1") == "dannerman", "Eindeutiger Gegenstand wechselt Besitzer")
	ui.close()
	check(not GameState.is_player_input_locked(), "Schließen löst Sperre auch nach erneutem Öffnungsversuch")
	check(game.level_manager.save_world("/tmp/necota-steal-test.json") == OK, "Diebesgut speicherbar")
	var restored := WorldSaveStore.new().read("/tmp/necota-steal-test.json")
	check(restored != null and restored.get_object_owner("level1_potion_1") == "dannerman", "Gespeicherter Besitz bleibt eindeutig")
	victim.add_item(item)
	StealManager.open(thief, victim)
	var events_before := GameState.world_state.events.snapshot()
	check(GameState.world_state.events.has_event("item_stolen", {"character_id": "dannerman", "target_id": "merchant_01", "world_object_id": "level1_potion_1"}), "Diebstahlereignis benennt Dieb, Opfer und Weltinstanz")
	ui.succeeds = false
	var count_before := thief.inventory.size()
	ui._on_item_selected(0)
	check(victim.inventory.size() == 1 and thief.inventory.size() == count_before, "Entdeckung überträgt nichts")
	check(not ui.visible and not GameState.is_player_input_locked(), "Entdeckung schließt Fenster und entsperrt Eingabe")
	check(GameState.world_state.events.snapshot() == events_before, "Entdeckung erzeugt keine erfolgreiche Übergabehistorie")
	var session := CombatManager.instance.active_session
	check(session != null and session.get_participant(victim).side == CombatParticipantResolver.SIDE_ATTACKER, "Opfer startet Kampf gegen Dieb")
	var rolls_before := ui.rolls
	ui._on_item_selected(0)
	check(ui.rolls == rolls_before, "Geschlossenes Fenster verarbeitet keinen weiteren Klick")
	game.free()
	check(not GameState.is_player_input_locked(), "Neustartbereinigung nach Entdeckung")
	print("steal_rules: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
