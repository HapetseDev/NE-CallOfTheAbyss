extends Node

var checks := 0
var failures := 0
const SAVE := "/tmp/necota-shop-test.json"
func _ready() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func _run() -> void:
	GameState.reset_session()
	var packed := load("res://src/core/main_game/main_game.tscn") as PackedScene
	var game := packed.instantiate() as MainGame
	add_child(game)
	var player := game.party.leader
	player.gold = 200
	var manager := ShopManager.instance
	var shop := manager.get_shop("haendler_01")
	var entry := shop.entries[0]
	var initial_stock := entry.stock
	var template := load("res://src/resources/items/shop/shops/haendler_01.tres") as ShopData
	check(shop == GameState.world_state.shops.haendler_01 and shop != template, "WorldState besitzt isolierten Händler")
	ShopManager.open("haendler_01", player)
	ShopManager.open("haendler_01", player)
	var ui := manager._shop_ui
	var observed: Array = []
	var on_changed := func(): observed.append([player.gold, entry.stock])
	player.character.inventory.contents_changed.connect(on_changed)
	ui._on_shop_item_selected(0)
	check(observed == [[170, initial_stock - 1]], "Inventarsignal sieht bereits Gold und Bestand des Kaufs")
	player.character.inventory.contents_changed.disconnect(on_changed)
	check(player.gold == 170 and entry.stock == initial_stock - 1 and player.inventory.back().item.item_id == entry.item.item_id, "Echtes Fenster übernimmt Kauf gemeinsam")
	check(template.entries[0].stock == initial_stock, "Vorlage bleibt unverändert")
	check(GameState.world_state.events.has_event("item_bought", {"shop_id": "haendler_01", "character_id": "dannerman", "item_id": entry.item.item_id}), "Kauf erzeugt strukturiertes Ereignis")
	ui._on_player_item_selected(player.inventory.size() - 1)
	check(player.gold == 182 and entry.stock == initial_stock - 1 and player.inventory.size() == 1, "Verkauf zahlt Preis ohne Wiederauffüllung")
	check(GameState.world_state.events.has_event("item_sold", {"shop_id": "haendler_01", "character_id": "dannerman"}), "Verkauf erzeugt strukturiertes Ereignis")
	var buy := {"type": "shop_buy", "character_id": "dannerman", "shop_id": "haendler_01", "item_id": entry.item.item_id, "count": 1}
	var old_slot := player.inventory[0]
	check(not GameState.apply_effects([buy, {"type": "unknown"}]) and player.gold == 182 and entry.stock == initial_stock - 1 and player.inventory[0] == old_slot, "Später Fehler erhält Gold, Bestand und Slotidentität")
	player.gold = 0
	ui._on_shop_item_selected(0)
	check(entry.stock == initial_stock - 1 and player.inventory.size() == 1, "Fehlendes Gold erzeugt keinen Gegenstand")
	player.gold = 200
	entry.stock = 0
	check(not GameState.apply_effects([buy]) and player.gold == 200, "Ausverkauft lehnt Kauf ab")
	entry.stock = 1
	check(not GameState.apply_effects([buy, buy]) and entry.stock == 1 and player.gold == 200, "Zwei Käufe des letzten Stücks rollen vollständig zurück")
	var weight := entry.item.weight
	entry.item.weight = 100000
	check(not GameState.apply_effects([buy]) and entry.stock == 1 and player.gold == 200, "Übergewicht erhält Gold und Bestand")
	entry.item.weight = weight
	entry.buy_price = -1
	check(not GameState.apply_effects([buy]) and player.gold == 200, "Negative Preise abgelehnt")
	entry.buy_price = 30
	entry.stock = -1
	check(GameState.apply_effects([buy, buy]) and entry.stock == -1 and player.gold == 140, "Unbegrenztes Angebot bleibt unbegrenzt")
	entry.stock = 3
	# Ein eindeutiger Weltgegenstand darf verkauft, aber nicht vervielfältigt werden.
	var potion := game.level_root.find_child("Heiltrank", true, false) as BasicItem
	potion.perform_action("pickup", player)
	ui._refresh()
	var before := player.gold
	ui._on_player_item_selected(player.inventory.size() - 1)
	check(player.gold == before + 12 and GameState.world_state.get_object_owner("level1_potion_1").is_empty() and GameState.world_state.objects.level1_potion_1.removed, "Verkauf von Weltinstanz entfernt Besitz und erhält Tombstone")
	var unique_sell := {"type": "shop_sell", "character_id": "dannerman", "shop_id": "haendler_01", "world_object_id": "level1_potion_1", "count": 1}
	check(not GameState.apply_effects([unique_sell]) and player.gold == before + 12, "Wiederholter Verkauf zahlt nichts")
	player.gold = 2147483647
	var sell := {"type": "shop_sell", "character_id": "dannerman", "shop_id": "haendler_01", "item_id": entry.item.item_id, "count": 1}
	check(not GameState.apply_effects([sell]) and player.inventory.size() == 2, "Goldüberlauf entzieht keinen Gegenstand")
	var odd := ItemData.new()
	odd.item_id = "unlisted"
	odd.weight = 0.7
	player.gold = 100
	player.add_item(odd)
	ui._refresh()
	ui._on_player_item_selected(player.inventory.size() - 1)
	check(player.gold == 107, "Nicht gelisteter Gegenstand nutzt bisherigen Gewichtspreis")
	player.gold = 100
	ui.close()
	check(not GameState.is_player_input_locked(), "Einmaliges Schließen gibt Sperre frei")
	ui._on_shop_item_selected(0)
	check(player.gold == 100, "Geschlossenes Fenster kauft nicht")
	LevelManager.load_level(MainGame.DEFAULT_LEVEL)
	check(manager.get_shop("haendler_01") == shop and entry.stock == 3, "Levelwechsel erhält Händleridentität und Bestand")
	check(game.level_manager.save_world(SAVE) == OK, "Händlerzustand speicherbar")
	var store := WorldSaveStore.new()
	var restored := store.read(SAVE)
	check(restored != null and restored.shops.haendler_01.entries[0].stock == 3, "Bestand übersteht JSON-Rundlauf")
	_test_files(store)
	game.free()
	check(GameState.install_world(restored), "Gespeicherte Welt installierbar")
	game = packed.instantiate() as MainGame
	add_child(game)
	check(ShopManager.instance.get_shop("haendler_01").entries[0].stock == 3, "MainGame überschreibt geladenen Bestand nicht")
	game.free()
	var legacy := store.read(SAVE + ".legacy")
	check(GameState.install_world(legacy), "Migrierte Version 3 installierbar")
	game = packed.instantiate() as MainGame
	add_child(game)
	check(ShopManager.instance.get_shop("haendler_01").entries[0].stock == initial_stock, "Älterer Spielstand erhält Vorlagenbestand")
	game.free()
	game = packed.instantiate() as MainGame
	add_child(game)
	check(ShopManager.instance.get_shop("haendler_01").entries[0].stock == initial_stock, "Neues Spiel stellt Startbestand her")
	game.free()
	print("shop_rules: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_files(store: WorldSaveStore) -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	for mutation in ["missing", "stock", "price", "identity"]:
		var bad := original.duplicate(true)
		var fields: Dictionary = bad.world.value.shops.value.haendler_01.value
		match mutation:
			"missing": bad.world.value.erase("shops")
			"stock": fields.entries[0].value.stock = -2
			"price": fields.entries[0].value.buy_price = -1
			"identity": fields.shop_id = "wrong"
		var file := FileAccess.open(SAVE + ".bad", FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		check(store.read(SAVE + ".bad") == null, "Ungültige Händlerdaten abgelehnt: " + mutation)
	var legacy := original.duplicate(true)
	legacy.version = 3
	legacy.world.value.erase("shops")
	var file := FileAccess.open(SAVE + ".legacy", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated := store.read(SAVE + ".legacy")
	check(migrated != null and migrated.shops.is_empty() and migrated.characters.get_character("dannerman").gold == 100, "Version 3 migriert ohne Verlust vorhandener Daten")

	var broken := store.read(SAVE)
	broken.shops.haendler_01.entries[0].stock = -2
	check(store.write(broken, SAVE) != OK and store.read(SAVE).shops.haendler_01.entries[0].stock == 3, "Fehlerhaftes Speichern erhält letzten gültigen Händlerstand")
