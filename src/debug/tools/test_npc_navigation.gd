extends "res://src/debug/tools/test_npc_combat_ai.gd"

const GRID := preload("res://src/world/combat/combat_grid.gd")

func path_cost(path: PackedVector3Array) -> float:
	var result := 0.0
	for index in range(1, path.size()):
		result += path[index - 1].distance_to(path[index])
	return result

func _run() -> void:
	# Sackgasse: Der erste notwendige Schritt führt vom sichtbaren Gegner weg.
	setup()
	var bot := actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	var target := actor(Vector3(0, 0, 4), CombatParticipantResolver.SIDE_ATTACKER)
	bot.playable.character.gewandheit = 1
	target.playable.character.gewandheit = 0
	bot.playable.equip("primaer_hand", load("res://src/resources/items/schwert.tres"))
	box(Vector3(0, 0.2, 1), Vector3(3.2, 0.4, 0.15))
	box(Vector3(-1.5, 0.2, -0.25), Vector3(0.15, 0.4, 2.5))
	box(Vector3(1.5, 0.2, -0.25), Vector3(0.15, 0.4, 2.5))
	await settle()
	check(PLANNER.perceived_enemies(session, bot, PROFILE).has(target), "Niedrige Hindernisse lassen Gegner sichtbar")
	var plan := PLANNER.choose(session, bot, PROFILE)
	check(plan.get("kind") == "move" and plan.get("reason") == "approach_attack", "KI plant einen mehrzügigen Umweg aus der Sackgasse")
	if plan.get("kind") == "move":
		check(plan.path[-1].distance_to(target.playable.global_position) > bot.playable.global_position.distance_to(target.playable.global_position), "Notwendige erste Bewegung darf den Luftlinienabstand vergrößern")
		check(path_cost(plan.path) <= GRID.budget(bot.playable) + 0.001, "Vorausschau erweitert nicht das Bewegungsbudget")
	var start_health := target.playable.health
	var visited: Dictionary = {}
	var reached_attack := false
	for turn in 16:
		plan = PLANNER.choose(session, bot, PROFILE)
		if "--trace-navigation" in OS.get_cmdline_user_args():
			print("TURN ", turn, " at ", bot.playable.global_position, " plan ", plan.get("kind"), " ", plan.get("reason"), " path ", plan.get("path"))
		if plan.get("kind") == "attack":
			reached_attack = true
			break
		if plan.get("kind") != "move":
			break
		var key := GRID.cell(bot.playable.global_position)
		check(not visited.has(key), "Umweg pendelt nicht zwischen bereits besuchten Feldern")
		visited[key] = true
		start_turn(bot)
		await finish_turn()
		check(GRID.is_centered(bot.playable.global_position) and target.playable.health == start_health, "Jeder Umweg-Zug endet auf einem Feld ohne verfrühten Angriff")
	check(reached_attack, "KI erreicht über mehrere Züge eine echte Angriffsmöglichkeit")
	if reached_attack:
		start_turn(bot)
		await finish_turn()
		check(target.playable.health < start_health, "Nach dem Umweg greift die KI tatsächlich an")
	await cleanup()
	# Wahrnehmung merken, danach ausschließlich den letzten Sichtkontakt verfolgen.
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	PLANNER.update_observations(session, bot, PROFILE)
	var id := target.playable.get_instance_id()
	check(bot.ai_last_seen.has(id) and bot.ai_last_seen[id].age == 0, "Tatsächlich sichtbares Ziel wird flüchtig gemerkt")
	var remembered: Vector3 = bot.ai_last_seen[id].position
	box(Vector3(0, 1.5, 2), Vector3(1.0, 3, 0.2))
	target.playable.global_position = Vector3(0, 0, 8)
	await settle()
	PLANNER.update_observations(session, bot, PROFILE)
	check(PLANNER.perceived_enemies(session, bot, PROFILE).is_empty(), "Wand verdeckt den aktuellen Gegnerstandort")
	check(bot.ai_last_seen[id].position == remembered and bot.ai_last_seen[id].age == 1, "Sichtverlust aktualisiert keine unbekannte Position")
	plan = PLANNER.choose(session, bot, PROFILE)
	check(plan.get("kind") == "move" and plan.get("reason") == "last_seen", "KI bewegt sich zum letzten Sichtkontakt statt stehen zu bleiben")
	var memory_before := bot.ai_last_seen.duplicate(true)
	var first_path: PackedVector3Array = plan.get("path", PackedVector3Array())
	target.playable.global_position = Vector3(-0.5, 0, 8)
	await settle()
	var second := PLANNER.choose(session, bot, PROFILE)
	check(second.get("path", PackedVector3Array()) == first_path, "Andere verdeckte Zielposition verrät der KI keinen neuen Standort")
	check(bot.ai_last_seen == memory_before, "Reine Planung verändert das Sichtgedächtnis nicht")
	var profile := PROFILE.duplicate()
	profile.target_memory_turns = 0
	check(PLANNER.choose(session, bot, profile).is_empty(), "Profil kann Verfolgung nach Sichtverlust abschalten")
	for turn in PROFILE.target_memory_turns:
		PLANNER.update_observations(session, bot, PROFILE)
	check(bot.ai_last_seen.is_empty() and PLANNER.choose(session, bot, PROFILE).is_empty(), "Veralteter Sichtkontakt verfällt nach begrenzten eigenen Zügen")
	bot.ai_last_seen[id] = {"position": remembered, "age": 0}
	var origin := bot.playable.global_position
	start_health = target.playable.health
	start_turn(bot)
	await finish_turn()
	check(bot.playable.global_position.distance_to(origin) > 0.5 and GRID.is_centered(bot.playable.global_position) and target.playable.health == start_health, "Verfolgung läuft physisch als eigener Bewegungszug ohne blinden Angriff")
	PLANNER.update_observations(session, bot, PROFILE)
	check(bot.ai_last_seen.has(id) and bot.ai_last_seen[id].age == 0 and bot.ai_last_seen[id].position == target.playable.global_position, "Erneuter Sichtkontakt aktualisiert die Zielposition")
	target.has_fled = true
	PLANNER.update_observations(session, bot, PROFILE)
	check(bot.ai_last_seen.is_empty(), "Geflohenes Ziel wird nicht weiter verfolgt")
	bot.ai_last_seen[id] = {"position": remembered, "age": 0}
	bot.has_fled = true
	session.admit(bot.playable, bot.side)
	check(bot.ai_last_seen.is_empty(), "Rückkehr nach Flucht verwirft eigenes altes Sichtgedächtnis")
	await cleanup()
	# Ein naher Sichtkontakt hinter einer Wand ist noch kein abgesuchter Standort.
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 3), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	PLANNER.update_observations(session, bot, PROFILE)
	id = target.playable.get_instance_id()
	bot.playable.global_position = Vector3(0, 0, 2)
	target.playable.global_position = Vector3(0, 0, 10)
	box(Vector3(0, 1.5, 2.5), Vector3(1.0, 3, 0.2))
	await settle()
	PLANNER.update_observations(session, bot, PROFILE)
	check(bot.ai_last_seen.has(id), "Nahe Suchposition hinter einer Wand gilt noch nicht als überprüft")
	check(PLANNER.choose(session, bot, PROFILE).get("reason") == "last_seen", "Auch bei nahem Sichtkontakt wird die verdeckende Wand umrundet")
	await cleanup()
	# Vollständig versperrt: keine sinnlose Bewegung und kein gesperrter Zug.
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	box(Vector3(0.6, 0.2, 0), Vector3(0.1, 0.4, 1.3))
	box(Vector3(-0.6, 0.2, 0), Vector3(0.1, 0.4, 1.3))
	box(Vector3(0, 0.2, 0.6), Vector3(1.3, 0.4, 0.1))
	box(Vector3(0, 0.2, -0.6), Vector3(1.3, 0.4, 0.1))
	await settle()
	check(PLANNER.choose(session, bot, PROFILE).is_empty(), "Ohne begehbaren Weg wartet die KI")
	start_turn(bot)
	await finish_turn()
	check(ended == 1 and announced == 0 and bot.playable._path_motion.owner_id == 0, "Unmögliche Bewegung gibt den Zug sauber frei")
	await cleanup()
	print("npc_navigation: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
