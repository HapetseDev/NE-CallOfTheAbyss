extends Node

const VISUAL := preload("res://src/resources/items/item_visual.gd")
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
	for key in ["dolch", "schwert", "speer", "messer", "pfeil"]:
		var item := load("res://src/resources/items/%s.tres" % key) as ItemData
		var model := VISUAL.create(item)
		var bounds := AABB()
		var first := true
		for child in model.get_children():
			if child is MeshInstance3D:
				var box: AABB = child.transform * child.get_aabb()
				bounds = box if first else bounds.merge(box)
				first = false
		check(is_equal_approx(bounds.size.y, VISUAL.length_meters(item)), key + ": sichtbare Länge entspricht Nahkampfreichweite")
		check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), key + ": Handansicht erzeugt keine Physikobjekte")
		model.free()
		var world_item := load("res://src/world/objects/items/basic_item.tscn").instantiate() as BasicItem
		world_item.item_data = item
		add_child(world_item)
		check(world_item.get_node("WeaponVisual").get_meta("length_meters") == VISUAL.length_meters(item) and is_equal_approx(world_item.get_node("CollisionShape3D").shape.size.y, VISUAL.length_meters(item)), key + ": abgelegte Ansicht und Kollisionsform verwenden dieselbe Länge")
		world_item.free()
	check(VISUAL.length_meters(load("res://src/resources/items/bogen.tres")) == 1.2, "Bogen behält eigene Größe statt 20 m")
	GameState.reset_session()
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame
	for member in game.party.get_all_members():
		var held: Node = member.get_node("HeldItemVisuals")
		var sword := load("res://src/resources/items/schwert.tres") as ItemData
		var spear := load("res://src/resources/items/speer.tres") as ItemData
		var inventory := member.character.inventory
		var world_objects := GameState.world_state.objects.size()
		inventory.equip("primaer_hand", sword)
		inventory.equip("nebenhand", spear)
		for frame in 4:
			await get_tree().process_frame
		check(held._sockets.primaer_hand is BoneAttachment3D and held._sockets.primaer_hand.bone_name == "RightHand", member.name + ": primäre Hand am rechten Handknochen")
		check(held._sockets.nebenhand is BoneAttachment3D and held._sockets.nebenhand.bone_name == "LeftHand", member.name + ": Nebenhand am linken Handknochen")
		check(held._visuals.primaer_hand.get_meta("item_id") == "Schwert" and held._visuals.nebenhand.get_meta("item_id") == "Speer", member.name + ": getrennte Handdarstellungen")
		check(held._visuals.primaer_hand.global_basis.get_scale().is_equal_approx(Vector3.ONE), member.name + ": GLB-Skalierung verkleinert die Waffe nicht")
		check(held._visuals.nebenhand.global_position.is_equal_approx(held._sockets.nebenhand.global_position), member.name + ": Waffengriff folgt der Hand")
		check(GameState.world_state.objects.size() == world_objects, "Handdarstellung erzeugt keine persistenten Gegenstandsduplikate")
		var old_visual: Node = held._visuals.primaer_hand
		inventory.equip("primaer_hand", load("res://src/resources/items/bogen.tres"))
		await get_tree().process_frame
		await get_tree().process_frame
		check(not is_instance_valid(old_visual) and held._visuals.primaer_hand.get_meta("item_id") == "Bogen", "Ausrüstungswechsel ersetzt nur die betroffene Handansicht")
		inventory.unequip("nebenhand")
		check(not held._visuals.has("nebenhand"), "Leere Hand entfernt ihre Waffe sofort")
		inventory.consume_combat_item(inventory.equipment.primaer_hand)
		check(held._visuals.is_empty(), "Verbrauch/Bruch entfernt die Handansicht")
		inventory.equip("guertel_1", spear)
		check(held._visuals.is_empty(), "Gürtel erzeugt keine zusätzliche Handwaffe")
	game.free()
	await get_tree().process_frame
	print("held_weapons: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
