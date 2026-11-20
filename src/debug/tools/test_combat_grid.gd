extends "res://src/debug/tools/test_npc_combat_ai.gd"

const GRID := preload("res://src/world/combat/combat_grid.gd")
const GRID_DISPLAY := preload("res://src/world/combat/combat_grid_display.gd")

func same_standpoint(a: Vector3, b: Vector3) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < GRID.EPSILON

func same_camera_pose(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.001 and a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()) < 0.001

func create_combat_camera() -> CameraSystem:
	var system := CameraSystem.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	system.add_child(camera)
	rig.add_child(system)
	await get_tree().process_frame
	system._combat_active = true
	system._combat_focus = Vector3.ZERO
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(6, 6, 8)).looking_at(Vector3.ZERO, Vector3.UP)
	return system

func preview(bot: CombatParticipant, target: CombatParticipant) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11
	camera.position = Vector3(7, 10, 10)
	rig.add_child(camera)
	camera.look_at(Vector3(0, 0, 1))
	camera.current = true
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_material.albedo_color = NEColors.PANEL
	floor_mesh.material_override = floor_material
	rig.add_child(floor_mesh)
	for participant in [bot, target]:
		var model := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.18
		capsule.height = 1.0
		model.mesh = capsule
		model.position.y = 0.5
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = NEColors.SUCCESS if participant == bot else NEColors.DANGER
		model.material_override = material
		participant.playable.add_child(model)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.combat-grid-preview.png")

func _run() -> void:
	setup()
	var bot := actor(Vector3(0.2, 0, 0.2), CombatParticipantResolver.SIDE_VICTIM)
	var target := actor(Vector3(0.4, 0, 0.4), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	check(GRID.is_centered(bot.playable.global_position) and GRID.is_centered(target.playable.global_position), "Kampfeintritt ordnet beide Figuren auf Zellmitten ein")
	check(GRID.cell(bot.playable.global_position) != GRID.cell(target.playable.global_position), "Kampfeintritt reserviert verschiedene Felder")
	check(GRID.cell(Vector3(-1.1, 0, -2.1)) == Vector2i(-1, -2), "Raster funktioniert auch bei negativen Weltkoordinaten")
	var old_participant := target
	target.has_fled = true
	target.playable.global_position = Vector3(2.3, 0, 0.2)
	check(session.admit(target.playable, target.side) == old_participant and GRID.is_centered(target.playable.global_position), "Rückkehr nach Flucht ordnet denselben Teilnehmer erneut ein")
	await cleanup()
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 4), CombatParticipantResolver.SIDE_ATTACKER)
	bot.playable.character.gewandheit = 2
	await settle()
	var fields := GRID.reachable(bot.playable, session)
	check(fields.has(Vector2i(2, 0)) and is_equal_approx(fields[Vector2i(2, 0)].cost, 2.0), "Zwei gerade Schritte kosten genau zwei Meter")
	check(fields.has(Vector2i(1, 1)) and is_equal_approx(fields[Vector2i(1, 1)].cost, sqrt(2.0)), "Diagonaler Schritt kostet Wurzel zwei Meter")
	check(not fields.has(Vector2i(2, 1)), "Wegkosten statt bloßem Zielabstand begrenzen Bewegung")
	check(not fields.has(GRID.cell(target.playable.global_position)), "Belegtes Feld ist kein Bewegungsziel")
	var wall := box(Vector3(0.5, 0.5, 0), Vector3(0.1, 1, 0.7))
	await settle()
	fields = GRID.reachable(bot.playable, session)
	check(not fields.has(Vector2i(1, 0)), "Dünne Wand zwischen zwei freien Zellmitten blockiert den Schritt")
	check(fields.has(Vector2i(1, 1)) and fields[Vector2i(1, 1)].cost >= 2.0, "Blockierte Kante erfordert zwei gerade Schritte statt diagonaler Abkürzung")
	wall.free()
	box(Vector3(1, 0.5, 0), Vector3(0.8, 1, 0.8))
	box(Vector3(0, 0.5, 1), Vector3(0.8, 1, 0.8))
	await settle()
	fields = GRID.reachable(bot.playable, session)
	check(not fields.has(Vector2i(1, 1)), "Kein diagonales Durchschlüpfen zwischen zwei blockierten Feldern")
	await cleanup()
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(1, 0, 0), CombatParticipantResolver.SIDE_ATTACKER)
	bot.playable.equip("primaer_hand", load("res://src/resources/items/dolch.tres"))
	await settle()
	var dagger := load("res://src/resources/items/dolch.tres") as ItemData
	check(dagger.usage_modes[0].is_in_range(bot.playable, target.playable), "Dolch erreicht ein direkt benachbartes Feld")
	target.playable.global_position = Vector3(1, bot.playable.global_position.y, 1)
	check(not dagger.usage_modes[0].is_in_range(bot.playable, target.playable), "Dolch mit einem Meter Reichweite erreicht diagonales Nachbarfeld nicht")
	target.playable.global_position = Vector3(2, bot.playable.global_position.y, 0)
	var options := PLANNER.attack_options(bot)
	var projected := PLANNER.best_attack(bot, [target], options, PROFILE, Vector3(1, bot.playable.global_position.y, 0))
	check(not projected.is_empty(), "KI prüft angrenzenden Dolchangriff am geplanten Standpunkt")
	await cleanup()
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	bot.playable.equip("primaer_hand", load("res://src/resources/items/schwert.tres"))
	await settle()
	var plan := PLANNER.choose(session, bot, PROFILE)
	check(not plan.is_empty() and plan.kind == "move" and GRID.is_centered(plan.path[-1]), "KI wählt dasselbe Raster wie der Spieler")
	var length := 0.0
	if plan.get("kind") == "move":
		for i in range(1, plan.path.size()):
			length += plan.path[i - 1].distance_to(plan.path[i])
	check(length <= GRID.budget(bot.playable) + 0.01, "KI-Weg hält das gesamte Bewegungsbudget ein")
	start_turn(bot)
	await finish_turn()
	check(GRID.is_centered(bot.playable.global_position) and ended == 1, "Physische KI-Bewegung endet exakt auf einer Zellmitte")
	await cleanup()
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	session.turn_queue.assign([bot])
	session._advance_turn_queue()
	var states := Node.new()
	rig.add_child(states)
	for title in ["CombatWait", "CombatTurn"]:
		var state := State.new()
		state.name = title
		states.add_child(state)
	var move := StateCombatMove.new()
	move.player = bot.playable
	states.add_child(move)
	var camera_system := await create_combat_camera()
	var camera_before := camera_system.camera.global_transform
	move.enter()
	check(camera_system.is_combat_camera_held(move.get_instance_id()), "Feldwahl hält die Kampfkamera mit eigenem Besitzer")
	camera_system._combat_focus = Vector3(15, 0, 0)
	camera_system._update_combat_camera(1.0)
	check(same_camera_pose(camera_system.camera.global_transform, camera_before), "Kamera bleibt während der Feldwahl trotz geändertem Kampfschwerpunkt stehen")
	var origin := bot.playable.global_position
	var right := InputEventAction.new()
	right.action = "Right"
	right.pressed = true
	move.handle_input(right)
	check(move._selected == Vector2i(1, 0), "WASD wählt ein erreichbares Nachbarfeld")
	var input_camera := Camera3D.new()
	input_camera.position = Vector3(5, 8, 8)
	rig.add_child(input_camera)
	input_camera.look_at(Vector3.ZERO)
	input_camera.current = true
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = input_camera.unproject_position(Vector3(0, 0, 1))
	move._unhandled_input(click)
	check(move._selected == Vector2i(0, 1), "Mausstrahl wählt das angeklickte erreichbare Bodenfeld")
	click.position = input_camera.unproject_position(target.playable.global_position)
	move._unhandled_input(click)
	check(move._selected == Vector2i(0, 1), "Klick auf ein unerreichbares Feld verändert die Auswahl nicht")
	move._selected = Vector2i(1, 0)
	move._refresh()
	var grid_mesh := session.grid_display.mesh as ImmediateMesh
	check(grid_mesh != null and grid_mesh.get_surface_count() == 2 and GRID_DISPLAY.SELECTED_FILL_ALPHA > GRID_DISPLAY.REACHABLE_ALPHA and GRID_DISPLAY.SELECTED_LINE_ALPHA > GRID_DISPLAY.REACHABLE_ALPHA, "Ausgewähltes Feld erhält helle Fläche und stärkeren Rand")
	if "--preview-grid" in OS.get_cmdline_user_args():
		await preview(bot, target)
	check(same_standpoint(bot.playable.global_position, origin) and session.grid_display.preview.has(Vector2i(1, 0)), "Feldauswahl zeigt erreichbare Felder ohne vorzeitige Bewegung")
	move._on_cancel_pressed()
	check(same_standpoint(bot.playable.global_position, origin) and ended == 0 and session.get_active_participant() == bot, "Abbrechen verbraucht keinen Zug und benötigt keinen Rückteleport")
	move.exit()
	check(not camera_system.is_combat_camera_held(), "Verlassen der Bewegungswahl gibt die Kamera frei")
	camera_system._update_combat_camera(1.0)
	check(not same_camera_pose(camera_system.camera.global_transform, camera_before), "Kamera folgt dem Kampf wieder nach der Bewegungswahl")
	check(session.grid_display.preview.is_empty(), "Verlassen der Feldauswahl bereinigt Markierungen")
	move.enter()
	camera_before = camera_system.camera.global_transform
	move._selected = Vector2i(1, 0)
	var newcomer := actor(Vector3(1, 0, 0), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	move._on_confirm_pressed()
	check(not move._moving, "Neu belegtes Zielfeld wird vor der Ausführung erneut geprüft")
	newcomer.playable.free()
	await settle()
	move._on_confirm_pressed()
	check(same_standpoint(bot.playable.global_position, origin) and move._moving, "Bestätigen startet physische Bewegung ohne Teleport")
	camera_system._combat_focus = Vector3(-15, 0, 0)
	camera_system._update_combat_camera(1.0)
	check(same_camera_pose(camera_system.camera.global_transform, camera_before), "Kamera bleibt auch während des physischen Bewegungswegs stehen")
	await finish_turn()
	check(GRID.cell(bot.playable.global_position) == Vector2i(1, 0) and GRID.is_centered(bot.playable.global_position), "Spielerbewegung erreicht die gewählte Zellmitte")
	check(ended == 1 and announced == 1, "Spielerbewegung verbraucht genau einen Zug")
	move.exit()
	var invalid := CombatAction.new()
	invalid.actor = bot
	invalid.type = CombatAction.ActionType.MOVE
	bot.playable.global_position.x = 1.25
	invalid.move_target_position = bot.playable.global_position
	check(not CombatResolver.resolve_action(invalid).success, "MOVE weist eine Position zwischen Rasterfeldern zurück")
	session.state = CombatSession.SessionState.ENDED
	bot.playable.exit_combat_mode()
	bot.playable.global_position = Vector3(0.35, 0, 0.45)
	await settle()
	check(not GRID.is_centered(bot.playable.global_position) and absf(bot.playable.global_position.x - 0.35) < 0.001, "Außerhalb des Kampfes werden Positionen nicht gerastert")
	check(not session.grid_display.visible, "Raster verschwindet bei Kampfende")
	check(GRID.reachable(bot.playable, session).is_empty(), "Beendeter Kampf bietet keine Rasterwege an")
	await cleanup()
	setup()
	bot = actor(Vector3.ZERO, CombatParticipantResolver.SIDE_VICTIM)
	target = actor(Vector3(0, 0, 5), CombatParticipantResolver.SIDE_ATTACKER)
	await settle()
	session.turn_queue.assign([bot])
	session._advance_turn_queue()
	states = Node.new()
	rig.add_child(states)
	for title in ["CombatWait", "CombatTurn"]:
		var state := State.new()
		state.name = title
		states.add_child(state)
	move = StateCombatMove.new()
	move.player = bot.playable
	states.add_child(move)
	move.enter()
	move._selected = Vector2i(2, 0)
	move._on_confirm_pressed()
	box(Vector3(0.5, 0.5, 0), Vector3(0.1, 1, 1))
	await finish_turn()
	check(ended == 1 and bot.playable._path_motion.owner_id == 0 and GRID.is_centered(bot.playable.global_position), "Neue Blockierung beendet Bewegung und lässt keine Zwischenposition oder gesperrten Zug zurück")
	move.exit()
	await cleanup()
	print("combat_grid: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
