extends Node
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	for path in [MainGame.DEFAULT_LEVEL, "res://src/world/levels/regions/MonsterLair-Level1/MonsterLair-Level1.tscn"]:
		LevelManager.load_level(path)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var level := game.level_manager.current_level
		var leader := game.party.leader
		var follower := game.party.followers[0]
		var enemy := level.find_child("EnemyNPC", true, false) as NPC
		leader.global_position = enemy.global_position + Vector3(0, 0, 2)
		follower.global_position = leader.global_position + Vector3(1, 0, 0)
		for index in 30: await get_tree().physics_frame
		CombatManager.trigger_attack(enemy, leader)
		var session := CombatManager.instance.active_session
		session.set_process(false)
		for actor: Playable in [leader, follower]:
			var before := actor.global_position
			session.mark_fled(session.get_participant(actor))
			check(actor.global_position == before, "Flucht teleportiert nicht")
			check(not actor.flee_path.is_empty(), "Begehbarer Fluchtweg gefunden")
			await finish_run(actor)
			var area := level.get_node("Fluchtbereiche/Party") as Area3D
			check(absf(actor.global_position.x - area.global_position.x) < 2 and absf(actor.global_position.z - area.global_position.z) < 2, path + ": Party landet im Partybereich")
		check(leader.global_position.distance_to(follower.global_position) > 0.8, "Getrennte Plätze für Party")
		check(not CombatManager.instance.is_in_combat(), "Partyflucht beendet Kampf")
		CombatManager.trigger_attack(leader, enemy)
		session = CombatManager.instance.active_session
		var enemy_destination := level.get_node("Fluchtbereiche/Gegner") as Area3D
		enemy_destination.position.y += 100
		session.mark_fled(session.get_participant(enemy))
		check(enemy.flee_path.is_empty() and not session.get_participant(enemy).has_fled, "Unerreichbares Ziel lässt Gegner im Kampf")
		check(CombatManager.instance.is_in_combat(), "Fehlender Fluchtweg beendet Kampf nicht")
		enemy_destination.position.y -= 100
		session.mark_fled(session.get_participant(enemy))
		check(not enemy.flee_path.is_empty(), "Gegner findet Fluchtweg")
		await finish_run(enemy)
		var enemy_area := level.get_node("Fluchtbereiche/Gegner") as Area3D
		check(absf(enemy.global_position.x - enemy_area.global_position.x) < 2 and absf(enemy.global_position.z - enemy_area.global_position.z) < 2, path + ": Gegner landet im Gegnerbereich")
		check(not CombatManager.instance.is_in_combat(), "Gegnerflucht beendet Kampf")
		check(not enemy.character.is_defeated, "Geflohener Gegner ist nicht besiegt")
		for index in 30: await get_tree().physics_frame
		check(enemy.global_position.y > -2 and leader.global_position.y > -2, "Fluchtziele haben Boden")
	game.free()
	print("flee_areas: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func finish_run(actor: Playable) -> void:
	var before := actor.global_position
	for index in 1200:
		await get_tree().physics_frame
		check(actor.global_position.distance_to(before) < 0.3, "Bewegung erfolgt ohne Sprung")
		before = actor.global_position
		if actor.flee_path.is_empty():
			break
	check(actor.flee_path.is_empty(), "Fluchtlauf endet rechtzeitig")
