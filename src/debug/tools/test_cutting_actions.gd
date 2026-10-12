extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	var player := Playable.new()
	player.character = CharacterResource.new()
	player.character.ensure_equipment_slots()
	var knife := preload("res://src/resources/items/messer.tres")
	var other := ItemData.new()
	other.item_id = "Stein"
	for target in [Plant.new(), Busch2.new()]:
		player.equipment["primaer_hand"] = knife
		check(target.can_schneiden(player), "Ausgerüstete Messer-Resource erlaubt Schneiden")
		check(target.get_actions(player) == [{"label": "Schneiden", "action_id": "schneiden"}], "Menü bietet Schneiden an")
		player.equipment["primaer_hand"] = other
		check(target.get_actions(player).is_empty(), "Andere Resource bietet keine Aktion an")
		player.equipment["primaer_hand"] = null
		check(not target.can_schneiden(player), "Leerer Waffenplatz ohne Messer")
		player.add_item(knife)
		check(target.can_schneiden(player), "Messer im Inventar genügt")
		target.is_schneidbar = false
		check(target.get_actions(player).is_empty(), "Nicht schneidbares Ziel bleibt ausgeschlossen")
		target.is_schneidbar = true
		player.remove_item(knife)
		player.equipment["primaer_hand"] = "Messer"
		check(target.can_schneiden(player), "Legacy-String bleibt unterstützt")
		player.equipment["primaer_hand"] = "Stein"
		check(not target.can_schneiden(player), "Andere Legacy-Waffe genügt nicht")
		target.free()
	player.free()
	print("cutting_actions: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
