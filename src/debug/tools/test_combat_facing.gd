extends Node

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
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	LevelManager.load_level("res://src/world/levels/regions/MonsterLair-Level1/MonsterLair-Level1.tscn")
	var player := game.party.leader
	var enemy := game.level_root.find_child("EnemyNPC", true, false) as NPC
	var ally := game.party.followers[0]
	player.global_position = enemy.global_position + Vector3(0, 0, 1.2)
	ally.global_position = enemy.global_position + Vector3(-3, 0, 3)
	for frame in 4: await get_tree().physics_frame
	enemy.character.gewandheit = 0
	enemy.health = 1000
	enemy.face_world_position(enemy.global_position + Vector3.RIGHT)
	var enemy_facing := enemy.facing_direction
	player.face_world_position(player.global_position + Vector3.RIGHT)
	var before := player.facing_direction
	CombatManager.trigger_attack(player, enemy)
	var session := CombatManager.instance.active_session
	session.set_process(false)
	var participant := session.get_participant(player)
	var target := session.get_participant(enemy)
	var sword := load("res://src/resources/items/schwert.tres") as ItemData
	player.equip("primaer_hand", sword)
	session.turn_queue.assign([participant])
	session._advance_turn_queue()
	var turn := player.get_node("StateMachine/CombatTurn") as StateCombatTurn
	var changes := [0]
	player.direction_changed.connect(func(_direction): changes[0] += 1)
	turn._preview_attack(target, sword.usage_modes[0])
	check(player.facing_direction == before, "Zielvorschau dreht den Charakter nicht")
	turn._on_item_target_chosen(sword, sword.usage_modes[0], target)
	var expected := enemy.global_position - player.global_position
	expected.y = 0
	expected = expected.normalized()
	check(player.facing_direction.is_equal_approx(expected), "Spieler dreht sich beim Waffenangriff zum Empfänger")
	check(changes[0] == 1, "Blickrichtungswechsel wird an bestehende Listener gemeldet")
	check(is_equal_approx(player.model_root.rotation.y, player.get_facing_yaw()), "3D-Modell übernimmt neue Blickrichtung")
	check(enemy.facing_direction == enemy_facing, "Getroffener dreht sich nicht automatisch zum Angreifer")
	for frame in 8: await get_tree().process_frame
	check(player.get_node("StateMachine").current_state is StateCombatWait and player.facing_direction.is_equal_approx(expected), "Blickrichtung bleibt nach Zugende im Wartestatus erhalten")
	# Abgelehnte Waffenangriffe dürfen keine kostenlose Drehung ermöglichen.
	var action := CombatAction.new()
	action.actor = participant
	action.type = CombatAction.ActionType.ITEM
	action.item = sword
	action.item_usage_mode = sword.usage_modes[0].duplicate()
	action.item_usage_mode.range_meters = 0.1
	action.targets = [target]
	player.face_world_position(player.global_position + Vector3.RIGHT)
	before = player.facing_direction
	check(not CombatResolver.resolve_action(action).success and player.facing_direction == before, "Außer Reichweite bleibt Blickrichtung erhalten")
	action.item_usage_mode.range_meters = 2.0
	action.item_usage_mode.ammunition_item_id = "missing_test_ammunition"
	check(not CombatResolver.resolve_action(action).success and player.facing_direction == before, "Fehlende Munition dreht nicht")
	# Reguläres Kampfende vor dem Fixture-Abbau.
	session.mark_defeated(target)
	await get_tree().process_frame
	game.free()
	await get_tree().process_frame
	# Fähigkeiten und Simulationen mit Actors außerhalb des Szenenbaums.
	var actor := Playable.new()
	actor.character = CharacterResource.new()
	actor.character.ensure_initialized()
	var victim := Playable.new()
	victim.character = CharacterResource.new()
	victim.character.ensure_initialized()
	victim.position = Vector3(2, 0, 0)
	victim.character.gewandheit = 100
	victim.health = 1000
	var ability := AbilityDefinition.new()
	ability.effect_type = AbilityDefinition.EffectType.DAMAGE
	ability.requires_line_of_sight = false
	ability.power = 1
	action = CombatAction.new()
	action.type = CombatAction.ActionType.ABILITY
	action.actor = CombatParticipant.new(actor)
	action.targets = [CombatParticipant.new(victim)]
	action.ability = ability
	var rng := RandomNumberGenerator.new()
	for candidate in 100:
		rng.seed = candidate
		if rng.randf() < 0.1:
			rng.seed = candidate
			break
	var result := CombatResolver.resolve_action(action, rng)
	check(result.outcomes.size() == 1 and result.outcomes[0].evaded and actor.facing_direction.is_equal_approx(Vector3.RIGHT), "Auch ausgewichener Fähigkeitsangriff dreht zum Ziel")
	actor.face_world_position(Vector3.BACK)
	before = actor.facing_direction
	ability.mana_cost = 1
	actor.mana = 0
	check(not CombatResolver.resolve_action(action).success and actor.facing_direction == before, "Fehlende Konzentration dreht nicht")
	ability.mana_cost = 0
	ability.effect_type = AbilityDefinition.EffectType.HEAL
	check(CombatResolver.resolve_action(action).success and actor.facing_direction == before, "Heilung verändert die letzte Angriffsrichtung nicht")
	ability.effect_type = AbilityDefinition.EffectType.DAMAGE
	action.targets = [action.actor]
	CombatResolver.resolve_action(action)
	check(actor.facing_direction == before and actor.facing_direction.is_finite(), "Gleiche Position erzeugt keine ungültige Richtung")
	actor.free()
	victim.free()
	_finish.call_deferred()

func _finish() -> void:
	await get_tree().process_frame
	print("combat_facing: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
