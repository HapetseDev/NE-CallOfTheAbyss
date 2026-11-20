extends Node3D

const PLANNER := preload("res://src/gameplay/combat/ai/combat_ai_planner.gd")
const PROFILE := preload("res://src/resources/combat/ai/melee_default.tres")
var checks := 0
var failures := 0
var ended := 0
var announced := 0
var rig: Node3D
var session: CombatSession

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _ready() -> void:
	_run.call_deferred()

func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 16
	var shape := CollisionShape3D.new()
	var resource := BoxShape3D.new()
	resource.size = size
	shape.shape = resource
	body.add_child(shape)
	body.position = at
	rig.add_child(body)
	return body

func actor(at: Vector3, side: StringName) -> CombatParticipant:
	var body := NPC.new()
	body.use_character_registry = false
	body.character = CharacterResource.new()
	body.character.ensure_initialized()
	body.collision_layer = 256
	body.collision_mask = 16 | 256
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.18
	capsule.height = 1.0
	shape.shape = capsule
	shape.position.y = 0.5
	body.add_child(shape)
	body.position = at
	rig.add_child(body)
	body.character.koerperkraft = 8
	body.character.gewandheit = 3
	body.character.robustheit = 0
	body.health = 1000
	return session.admit(body, side)

func setup() -> void:
	rig = Node3D.new()
	add_child(rig)
	box(Vector3(0, -0.1, 0), Vector3(30, 0.2, 30))
	session = CombatSession.new()
	rig.add_child(session)
	session.set_process(false)
	ended = 0
	announced = 0
	session.turn_ended.connect(func(_p): ended += 1)
	session.action_resolved.connect(func(_p, _a, _r): announced += 1)

func runner_count() -> int:
	var count := 0
	for child in session.get_children():
		if child.name.begins_with("NPCCombatTurn_"):
			count += 1
	return count

func start_turn(p: CombatParticipant) -> void:
	session.turn_queue.assign([p])
	session._advance_turn_queue()
	NPCCombatBrain.take_turn(session, p)

func settle() -> void:
	for index in 4:
		await get_tree().physics_frame

func finish_turn() -> void:
	for index in 1000:
		if session.get_active_participant() == null:
			break
		await get_tree().physics_frame
	check(session.get_active_participant() == null, "KI-Zug endet innerhalb der Prüffrist")
	await get_tree().process_frame

func cleanup() -> void:
	rig.free()
	await get_tree().process_frame

func _run() -> void:
	check(PROFILE.behavior_tree.get_root_task().get_child_count() == 2, "Separater LimboAI-Verhaltensbaum geladen")
	setup()
	var bot := actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	var target := actor(Vector3(0, 0, 1.4), CombatParticipantResolver.SIDE_ATTACKER)
	target.playable.character.gewandheit = 0
	bot.playable.character.inventory.equip("primaer_hand", load("res://src/resources/items/bogen.tres"))
	bot.playable.character.inventory.equip("nebenhand", load("res://src/resources/items/schwert.tres"))
	await settle()
	var selected := PLANNER.choose(session, bot, PROFILE)
	check(not selected.is_empty() and selected.kind == "attack" and selected.action.item.item_id == "Schwert", "KI überspringt Bogen ohne Munition und wählt nutzbare Waffe")
	var before := target.playable.health
	start_turn(bot)
	NPCCombatBrain.take_turn(session, bot)
	check(runner_count() == 1, "Doppelter Aufruf erzeugt nur einen Zug-Runner")
	await finish_turn()
	check(target.playable.health < before and ended == 1 and announced == 1, "Genau ein gültiger Angriff und ein Zugabschluss")
	await cleanup()
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	target.playable.character.gewandheit = 0
	bot.playable.character.gewandheit = 2
	bot.playable.character.inventory.equip("primaer_hand", load("res://src/resources/items/schwert.tres"))
	await settle()
	var origin := bot.playable.global_position
	before = target.playable.health
	start_turn(bot)
	check(bot.playable.global_position == origin, "KI-Bewegung teleportiert beim Start nicht")
	var previous := origin
	var stepped := true
	var bounded := true
	for index in 1000:
		if session.get_active_participant() == null:
			break
		await get_tree().physics_frame
		var current := bot.playable.global_position
		stepped = stepped and Vector2(current.x - previous.x, current.z - previous.z).length() < 0.08
		bounded = bounded and Vector2(current.x - origin.x, current.z - origin.z).length() <= 2.05
		previous = current
	check(stepped and bounded, "Bewegung läuft physisch in kleinen Schritten innerhalb der Gewandheitsreichweite")
	check(bot.playable.global_position.z > 0.5 and target.playable.health == before, "Annähern statt Fernschlag; Bewegung ist eigener Zug")
	check(session.get_active_participant() == null and ended == 1 and announced == 1, "Bewegungszug beendet sich genau einmal")
	await cleanup()
	# Ein Verbündeter vor dem Ziel darf weder als Ziel noch als Abfänger Schaden nehmen.
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	var ally := actor(Vector3(0, 0, 1.0), CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 2.0), CombatParticipantResolver.SIDE_ATTACKER)
	target.playable.character.gewandheit = 0
	bot.playable.character.inventory.equip("primaer_hand", load("res://src/resources/items/schwert.tres"))
	await settle()
	selected = PLANNER.choose(session, bot, PROFILE)
	check(not selected.is_empty() and selected.kind == "move", "Verbündeter in Angriffslinie führt zur Neupositionierung")
	before = ally.playable.health
	var target_before := target.playable.health
	start_turn(bot)
	await finish_turn()
	check(ally.playable.health == before and target.playable.health == target_before, "Positionswechsel verursacht keinen verfrühten oder freundlichen Treffer")
	selected = PLANNER.choose(session, bot, PROFILE)
	check(not selected.is_empty() and selected.kind == "attack", "Nach Positionswechsel ist eine freie Angriffslinie verfügbar")
	start_turn(bot)
	await finish_turn()
	check(ally.playable.health == before and target.playable.health < target_before, "Folgezug trifft Gegner ohne freundlichen Schaden")
	# Ein verspäteter Callback darf keinen neuen Zug erzeugen.
	NPCCombatBrain.take_turn(session, bot)
	check(runner_count() == 0, "Veralteter Zugaufruf wird ignoriert")
	var action := CombatAction.new()
	action.actor = bot
	action.type = CombatAction.ActionType.MOVE
	action.move_target_position = Vector3(10, 0, 10)
	var old_position := bot.playable.global_position
	check(not CombatResolver.resolve_action(action).success and bot.playable.global_position == old_position, "MOVE-Resolver erlaubt keine Teleportation")
	await cleanup()
	# Wände und Wahrnehmungsgrenze: kein Hellsehen und kein endloser Zug.
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	box(Vector3(0, 1.5, 2.5), Vector3(8, 3, 0.4))
	await settle()
	check(PLANNER.choose(session, bot, PROFILE).is_empty(), "Wand verdeckt Gegner")
	start_turn(bot)
	await finish_turn()
	check(ended == 1 and announced == 0, "Ohne wahrgenommenes Ziel wird der Zug einmal freigegeben")
	target.playable.position = Vector3(0, 0, 12)
	await settle()
	check(PLANNER.perceived_enemies(session, bot, PROFILE).is_empty(), "Entfernte Gegner außerhalb der Wahrnehmung werden ignoriert")
	await cleanup()
	# Zielverlust während der Bewegung räumt genau den eigenen Bewegungsauftrag auf.
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	start_turn(bot)
	for index in 15: await get_tree().physics_frame
	check(bot.playable._path_motion.owner_id != 0, "Asynchroner Bewegungsauftrag läuft")
	session.mark_defeated(target)
	await get_tree().process_frame
	check(bot.playable._path_motion.owner_id == 0 and runner_count() == 0, "Ziel-KO stoppt Bewegung und entfernt Runner")
	check(ended == 1, "Abbruch beendet eigenen Zug genau einmal")
	await cleanup()
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	start_turn(bot)
	for index in 15: await get_tree().physics_frame
	bot.playable.free()
	await get_tree().process_frame
	check(runner_count() == 0 and ended == 1, "Entfernter Actor hinterlässt keinen Runner oder gesperrten Zug")
	await cleanup()
	# Ein nach der Planung hinzukommendes Hindernis beendet Bewegung ohne Teleport.
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	start_turn(bot)
	for index in 15: await get_tree().physics_frame
	box(Vector3(0, 1, 1), Vector3(10, 2, 0.4))
	await finish_turn()
	check(bot.playable.global_position.z < 0.8 and ended == 1, "Neues Hindernis stoppt Bewegung und gibt Zug frei")
	check(bot.playable._path_motion.owner_id == 0, "Blockierter Weg hinterlässt keinen Bewegungsbesitzer")
	await cleanup()
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	start_turn(bot)
	for index in 15: await get_tree().physics_frame
	session.end_turn(bot)
	await get_tree().process_frame
	check(bot.playable._path_motion.owner_id == 0 and runner_count() == 0 and ended == 1, "Externes Zugende räumt nur eigenen Runner und Weg auf")
	await cleanup()
	# Besitzerwechsel zur Flucht ist vor alten KI-Aufräumaktionen geschützt.
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	await settle()
	var points := PackedVector3Array([bot.playable.global_position, Vector3(0, 0, 2)])
	check(bot.playable.begin_combat_path(42, points, 1.0, Callable()), "Eigener Wegauftrag startet")
	bot.playable.cancel_combat_path(43)
	check(bot.playable._path_motion.owner_id == 42, "Fremder Besitzer kann Weg nicht abbrechen")
	bot.playable.begin_flee(points, Callable())
	bot.playable.cancel_combat_path(42)
	check(not bot.playable.flee_path.is_empty(), "Alter KI-Auftrag kann neue Flucht nicht stoppen")
	bot.playable._finish_flee(false)
	await cleanup()
	# Integration mit echtem Level, CombatManager und registrierten NPC-Daten.
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	LevelManager.load_level("res://src/world/levels/regions/MonsterLair-Level1/MonsterLair-Level1.tscn")
	var enemy := game.level_root.find_child("EnemyNPC", true, false) as NPC
	var leader := game.party.leader
	leader.global_position = enemy.global_position + Vector3(0, 0, 4)
	game.party.followers[0].global_position = leader.global_position + Vector3(-1.5, 0, 0)
	for index in 30: await get_tree().physics_frame
	CombatManager.trigger_attack(leader, enemy)
	session = CombatManager.instance.active_session
	session.set_process(false)
	var npc_participant := session.get_participant(enemy)
	origin = enemy.global_position
	session.turn_queue.assign([npc_participant])
	session._advance_turn_queue()
	# CombatManager startet den Runner selbst über seinen deferred Hook.
	await get_tree().process_frame
	await finish_turn()
	check(enemy.global_position.distance_to(origin) > 0.5, "Echter NPC nähert sich über CombatManager im vorhandenen Level")
	check(GameState.character_registry.get_character(enemy.character.character_id) == enemy.character, "KI verwendet weiterhin autoritative Registry-Daten")
	session.mark_defeated(npc_participant)
	await get_tree().process_frame
	check(not CombatManager.instance.is_in_combat(), "Normales Kampfende gibt KI-Session frei")
	game.free()
	await get_tree().process_frame
	print("npc_combat_ai: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
