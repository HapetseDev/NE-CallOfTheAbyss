extends "res://src/debug/tools/test_npc_combat_ai.gd"

func add_full_armor(target: CombatParticipant) -> void:
	var armor := ItemData.new()
	armor.item_id = "TacticsTestArmor"
	armor.is_armor = true
	armor.equipment_slot = "rumpf"
	armor.armor_protection = {"slash": 26, "blunt": 26}
	for zone in CombatAnatomy.profile(target.playable.character).zones:
		armor.armor_zones.append(zone.zone_id)
	target.playable.equip("rumpf", armor)

func _run() -> void:
	setup()
	var bot := actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	var target := actor(Vector3(0, 0, 1.4), CombatParticipantResolver.SIDE_ATTACKER)
	target.playable.character.gewandheit = 0
	target.playable.face_world_position(Vector3.ZERO)
	bot.playable.equip("primaer_hand", load("res://src/resources/items/schwert.tres"))
	await settle()
	check(PLANNER.choose(session, bot, PROFILE).kind == "attack", "Ohne lohnenden Vorteil wird sofort angegriffen")
	add_full_armor(target)
	var immediate := PLANNER.best_attack(bot, [target], PLANNER.attack_options(bot), PROFILE, bot.playable.global_position)
	check(not immediate.is_empty() and immediate.damage > 0, "Frontalangriff bleibt grundsätzlich möglich")
	var plan := PLANNER.choose(session, bot, PROFILE)
	check(not plan.is_empty() and plan.kind == "move" and plan.get("tactical", false), "Starker Frontschutz führt trotz gültigem Angriff zur Flanke")
	check(bot.ai_reposition_cooldown == 0 and bot.playable.global_position.z < 0.1, "Planung verändert weder Position noch Abklingzeit")
	if plan.kind == "move":
		var future := PLANNER.best_attack(bot, [target], PLANNER.attack_options(bot), PROFILE, plan.path[-1])
		var length := 0.0
		for index in range(1, plan.path.size()): length += plan.path[index - 1].distance_to(plan.path[index])
		check(not future.is_empty() and future.score - length * PROFILE.reposition_path_cost > immediate.score * PROFILE.reposition_attack_multiplier + PROFILE.reposition_min_gain, "Tatsächlicher Weg und entgangener Angriff sind eingerechnet")
		check(CombatAnatomy.direction_from_position(plan.path[-1], target.playable) != "front", "Zielpunkt liegt an einer schwächer geschützten Richtung")
	var before := target.playable.health
	start_turn(bot)
	await finish_turn()
	check(target.playable.health == before and ended == 1, "Flankenbewegung verbraucht einen eigenen Zug ohne Angriff")
	check(bot.ai_reposition_cooldown == PROFILE.reposition_cooldown_turns, "Ausgeführter Flankenversuch setzt die Abklingzeit")
	# Der Gegner darf sich zwischen den Zügen drehen; die KI soll dann nicht endlos kreisen.
	target.playable.face_world_position(bot.playable.global_position)
	check(PLANNER.choose(session, bot, PROFILE).kind == "attack", "Abklingzeit erzwingt Entscheidung zum Angriff statt erneutem Umkreisen")
	start_turn(bot)
	await finish_turn()
	check(target.playable.health < before and ended == 2 and bot.ai_reposition_cooldown == 0, "Folgezug greift tatsächlich an und verbraucht die Abklingzeit")
	await cleanup()
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 1.4), CombatParticipantResolver.SIDE_ATTACKER)
	target.playable.character.gewandheit = 0
	target.playable.face_world_position(Vector3.ZERO)
	bot.playable.equip("primaer_hand", load("res://src/resources/items/schwert.tres"))
	add_full_armor(target)
	await settle()
	var profile := PROFILE.duplicate()
	profile.tactical_reposition_enabled = false
	check(PLANNER.choose(session, bot, profile).kind == "attack", "Profil kann taktisches Umpositionieren ausschalten")
	profile.tactical_reposition_enabled = true
	profile.reposition_path_cost = 100.0
	check(PLANNER.choose(session, bot, profile).kind == "attack", "Zu teure Wege werden zugunsten des Angriffs verworfen")
	target.playable.health = 1
	check(PLANNER.choose(session, bot, PROFILE).kind == "move", "Erreichen von null SP wird nicht mit tatsächlichem Ausscheiden verwechselt")
	target.playable.health = 1 - target.playable.get_max_health()
	check(PLANNER.choose(session, bot, PROFILE).kind == "attack", "Möglicher sofortiger KO hat Vorrang vor Positionswechsel")
	target.playable.health = 1000
	# Niedrige Mauern blockieren die Bewegung, aber nicht Sicht und Waffenlinie.
	box(Vector3(0.6, 0.15, 0), Vector3(0.1, 0.3, 1.3))
	box(Vector3(-0.6, 0.15, 0), Vector3(0.1, 0.3, 1.3))
	box(Vector3(0, 0.15, 0.6), Vector3(1.3, 0.3, 0.1))
	box(Vector3(0, 0.15, -0.6), Vector3(1.3, 0.3, 0.1))
	await settle()
	check(PLANNER.choose(session, bot, PROFILE).kind == "attack", "Unerreichbare Flanken verhindern verfügbaren Frontalangriff nicht")
	bot.ai_reposition_cooldown = 2
	bot.has_fled = true
	check(session.admit(bot.playable, bot.side) == bot and bot.ai_reposition_cooldown == 0, "Wiedereintritt nach Flucht verwirft alte KI-Abklingzeit")
	await cleanup()
	print("npc_tactics: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
