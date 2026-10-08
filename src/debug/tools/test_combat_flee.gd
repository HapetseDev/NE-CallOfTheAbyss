extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	for swap_leader in [false, true]:
		for approach in [Vector3(2, 0.1, 0), Vector3(0, 0.1, 2)]:
			await run_case(swap_leader, approach)
	print("combat_flee: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func run_case(swap_leader: bool, approach: Vector3) -> void:
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	LevelManager.load_level("res://src/world/levels/regions/MonsterLair-Level1/MonsterLair-Level1.tscn")
	if swap_leader:
		check(game.party.move_member(game.party.followers[0], -1), "Shalka übernimmt Führung")
	var leader := game.party.leader
	var follower := game.party.followers[0]
	var bandit := game.level_root.find_child("EnemyNPC", true, false) as NPC
	leader.global_position = bandit.global_position + approach
	follower.global_position = leader.global_position + Vector3(1, 0, 0)
	for index in 30:
		await get_tree().physics_frame
	CombatManager.trigger_attack(leader, bandit)
	var session := CombatManager.instance.active_session
	session.set_process(false)
	check(session.get_participant(follower) != null, "Begleiter nimmt am Kampf teil")
	for member: Player in [leader, follower]:
		var participant := session.get_participant(member)
		var machine := member.get_node("StateMachine") as PlayerStateMachine
		var turn := machine.get_node("CombatTurn") as StateCombatTurn
		session.turn_queue.assign([participant])
		session._advance_turn_queue()
		check(machine.current_state == turn, "Nächster Teilnehmer erhält seinen Kampfzug")
		# Derselbe Fluchtknopf wie im Spiel; deterministisch erfolgreicher Wurf.
		var successful_seed := 0
		while true:
			seed(successful_seed)
			if randf() < CombatBalance.FLEE_CHANCE_MIN:
				break
			successful_seed += 1
		seed(successful_seed)
		turn._on_flee_pressed()
		var escaped_position := member.global_position
		turn._on_flee_pressed()
		check(member.global_position == escaped_position, "Doppelklick führt nicht zu erneuter Flucht")
		for frame_index in 1200:
			if member.flee_path.is_empty():
				break
			await get_tree().physics_frame
		check(member.flee_path.is_empty(), "Fluchtbereich wird laufend erreicht")
		check(participant.has_fled, "%s ist geflohen" % member.get_display_name())
		var query := PhysicsRayQueryParameters3D.create(member.global_position + Vector3.UP, member.global_position + Vector3.DOWN * 2, 1)
		query.exclude = [leader.get_rid(), follower.get_rid(), bandit.get_rid()]
		check(not member.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Flucht endet über begehbarem Boden")
		if member == leader:
			check(CombatManager.instance.is_in_combat(), "Kampf wartet auf verbleibenden Begleiter")
			await get_tree().process_frame
			await get_tree().process_frame
	check(not CombatManager.instance.is_in_combat(), "Nach Flucht der Party endet der Kampf")
	for index in 120:
		await get_tree().physics_frame
	check(leader.global_position.y > -2 and follower.global_position.y > -2, "Beide Figuren bleiben in der Spielwelt")
	check(not leader.is_in_combat_mode() and not follower.is_in_combat_mode(), "Beide Figuren verlassen Kampfmodus")
	check(leader.get_node("StateMachine").current_state.name == "Idle", "Anführer ist wieder steuerbar")
	check(game._combat_order_hud._session == null, "Kampfanzeige schließt")
	check(not GameState.get_flag("defeated_bandit"), "Flucht gilt nicht als Sieg")
	check(game.level_manager.save_world("/tmp/necota-flee-save.json") == OK, "Speichern ist nach Flucht wieder möglich")
	game.free()
