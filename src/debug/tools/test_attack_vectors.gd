extends Node3D

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func _actor(at: Vector3, layer: int) -> Playable:
	var actor := Playable.new()
	actor.character = CharacterResource.new()
	actor.character.ensure_initialized()
	actor.collision_layer = layer
	actor.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.0
	shape.shape = capsule
	shape.position.y = 0.5
	actor.add_child(shape)
	add_child(actor)
	actor.position = at
	actor.set_physics_process(false)
	actor.character.staerkepunkte = 1000
	actor.character.koerperkraft = 20
	actor.character.gewandheit = 0
	actor.character.robustheit = 0
	return actor

func _sync() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

func _run() -> void:
	var actor := _actor(Vector3.ZERO, 1)
	var ally := _actor(Vector3(2, 0, 0), 1)
	var second := _actor(Vector3(3, 0, 0), 256)
	var enemy := _actor(Vector3(4, 0, 0), 256)
	var session := CombatSession.new()
	add_child(session)
	session.set_process(false)
	var attacker := session.admit(actor, CombatParticipantResolver.SIDE_ATTACKER)
	var friend := session.admit(ally, CombatParticipantResolver.SIDE_ATTACKER)
	var middle := session.admit(second, CombatParticipantResolver.SIDE_VICTIM)
	var aimed := session.admit(enemy, CombatParticipantResolver.SIDE_VICTIM)
	var bow := load("res://src/resources/items/bogen.tres").duplicate(true) as ItemData
	actor.character.inventory.equip("primaer_hand", bow)
	actor.character.inventory.add_item(load("res://src/resources/items/pfeil.tres"), 10)
	var action := CombatAction.new()
	action.actor = attacker
	action.type = CombatAction.ActionType.ITEM
	action.targets = [aimed]
	action.item = bow
	action.item_usage_mode = bow.usage_modes[0]
	await _sync()
	check(CombatLineOfSight.get_attack_body(actor, enemy) == ally, "Körpermitte trifft vorhandene 1-m-Kapsel")
	check(CombatResolver.get_item_attack_target(attacker, aimed, action.item_usage_mode) == friend, "Vorschau erkennt Verbündeten")
	var enemy_health := enemy.health
	var ally_health := ally.health
	var result := CombatResolver.resolve_action(action)
	check(result.outcomes.size() == 1 and result.outcomes[0].target == friend, "Erste Figur wird getroffen, unabhängig von Seite")
	check(ally.health < ally_health and enemy.health == enemy_health, "Schaden nur beim Abfänger")
	check(actor.character.inventory.slots[0].count == 9, "Genau ein Pfeil bei abgefangenem Schuss")
	check(action.targets[0] == aimed, "Gewähltes Ziel bleibt für Feedback erhalten")
	var turn := StateCombatTurn.new()
	turn.player = actor
	turn._session = session
	turn._participant = attacker
	turn._vbox = VBoxContainer.new()
	turn.add_child(turn._vbox)
	turn._render_item_target_menu(bow, bow.usage_modes[0])
	var warned := false
	for child in turn._vbox.get_children():
		if child is Button and child.text.contains("trifft zuerst:") and not child.disabled:
			warned = true
	check(warned, "Menü warnt vor Abfänger, Angriff bleibt wählbar")
	check(is_instance_valid(turn._attack_line), "Zielwahl erzeugt Vektorvorschau")
	turn._clear_vbox()
	check(turn._attack_line == null and turn._preview_target == null, "Menüwechsel bereinigt Vorschau")
	turn.free()
	ally.position.z = 2
	await _sync()
	check(CombatResolver.get_item_attack_target(attacker, aimed, action.item_usage_mode) == middle, "Nächster Körper auf Linie wird getroffen")
	second.position.z = 2
	await _sync()
	check(CombatResolver.get_item_attack_target(attacker, aimed, action.item_usage_mode) == aimed, "Freie Linie trifft gewähltes Ziel")
	ally.position = Vector3(2, 3, 0)
	await _sync()
	check(CombatResolver.get_item_attack_target(attacker, aimed, action.item_usage_mode) == aimed, "Figur auf anderer Höhe fängt nicht ab")
	ally.position = Vector3(2, 0, 0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 16
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2, 2)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	add_child(wall)
	wall.position = Vector3(1, 0.5, 0)
	await _sync()
	result = CombatResolver.resolve_action(action)
	check(not result.success and result.failed_reason == "no_line_of_sight", "Wand vor Figur blockiert")
	check(actor.character.inventory.slots[0].count == 9, "Blockierter Schuss verbraucht keine Munition")
	wall.position.x = 3
	await _sync()
	check(CombatResolver.get_item_attack_target(attacker, aimed, action.item_usage_mode) == friend, "Figur vor Wand fängt Angriff ab")
	friend.side = CombatParticipantResolver.SIDE_NEUTRAL
	check(CombatResolver.get_item_attack_target(attacker, aimed, action.item_usage_mode) == friend, "Neutraler Teilnehmer fängt ebenfalls ab")
	friend.side = CombatParticipantResolver.SIDE_ATTACKER
	friend.is_defeated = true
	check(CombatResolver.get_item_attack_target(attacker, aimed, action.item_usage_mode) == null, "Ausgeschiedener Körper blockiert ohne erneuten Schaden")
	friend.is_defeated = false
	wall.queue_free()
	enemy.position.x = 25
	await _sync()
	result = CombatResolver.resolve_action(action)
	check(not result.success and result.failed_reason == "out_of_range" and result.outcomes.is_empty(), "Naher Abfänger erlaubt kein gewähltes Ziel außerhalb der Reichweite")
	check(actor.character.inventory.slots[0].count == 9, "Entferntes gewähltes Ziel verbraucht trotz Abfänger keinen Pfeil")
	var sword := load("res://src/resources/items/schwert.tres") as ItemData
	action.item = sword
	action.item_usage_mode = sword.usage_modes[0]
	actor.character.inventory.equip("primaer_hand", sword)
	ally.position.x = 1
	enemy.position.x = 2
	await _sync()
	result = CombatResolver.resolve_action(action)
	check(result.success and result.outcomes[0].target == friend, "Schwert trifft ebenfalls erste Figur auf Vektor")
	ally.position.x = 3
	enemy.position.x = 3.5
	await _sync()
	result = CombatResolver.resolve_action(action)
	check(not result.success and result.failed_reason == "out_of_range", "Schwert kann entfernten Abfänger nicht treffen")
	ally.position.x = 1
	ally.character.gewandheit = 100
	action.item = bow
	action.item_usage_mode = bow.usage_modes[0]
	actor.character.inventory.equip("primaer_hand", bow)
	await _sync()
	var rng := RandomNumberGenerator.new()
	for candidate_seed in range(100):
		rng.seed = candidate_seed
		var saved_state := rng.state
		if rng.randf() < CombatBalance.EVADE_CAP:
			rng.state = saved_state
			break
	result = CombatResolver.resolve_action(action, rng)
	check(result.outcomes.size() == 1 and result.outcomes[0].evaded, "Abfänger darf regulär ausweichen")
	check(enemy.health == enemy_health, "Ausweichen leitet Angriff nicht zum nächsten Körper weiter")
	ally.character.gewandheit = 0
	ally.health = 1
	result = CombatResolver.resolve_action(action)
	check(result.defeated_targets.has(friend) and not result.defeated_targets.has(aimed), "Niederlage betrifft tatsächlichen Empfänger")
	print("attack_vectors: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
