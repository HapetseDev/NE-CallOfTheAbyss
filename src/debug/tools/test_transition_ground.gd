extends Node

const LAIR := "res://src/world/levels/regions/MonsterLair-Level1/MonsterLair-Level1.tscn"
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	run.call_deferred()

func frame() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame

func run() -> void:
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	for leader_index in 2:
		if leader_index == 1:
			check(game.party.move_member(game.party.followers[0], -1), "Shalka übernimmt Steuerung")
		for source: String in [MainGame.DEFAULT_LEVEL, LAIR]:
			check(game.level_manager._load_level(source), "Ausgangslevel lädt")
			var target := LAIR if source == MainGame.DEFAULT_LEVEL else MainGame.DEFAULT_LEVEL
			var area := game.level_manager.current_level.get_node("Levelwechseln/Ausgang") as Area3D
			var shape := area.get_node("Ausgangshape") as CollisionShape3D
			var player := game.party.leader
			var center := shape.global_position
			# Beide Übergänge lassen sich auf ebenem Boden von rechts betreten.
			# Ausgangsposition außerhalb der Zone; nur WASD bewegt uns hinein.
			player.global_position = Vector3(center.x + 2.0, 0.0, center.z)
			player.velocity = Vector3.ZERO
			game.party.followers[0].global_position = player.global_position + Vector3(1.5, 0, 1.5)
			for index in 45: await frame()
			check(player.is_on_floor(), "Figur steht vor dem Ausgang auf dem Boden")
			check(not area.overlaps_body(player) and area._armed, "Ausgang ist vor Betreten scharf")
			Input.action_press("Left")
			for index in 160:
				await frame()
				if game.level_manager._transition_pending:
					break
			Input.action_release("Left")
			check(game.level_manager._transition_pending, "%s erreicht %s zu Fuß" % [player.get_display_name(), target])
			for index in 180:
				if not game.level_manager._transition_pending:
					break
				await frame()
			check(game.level_manager.current_level_path == target, "Ziellevel wird tatsächlich geladen")
			check(not GameState.is_player_input_locked() and not game.transition_root.get_node("FadeRect").visible, "Übergang gibt Bildschirm und Eingaben frei")
			check(game.party.leader == player, "Anführer bleibt derselbe")
			for index in 30: await frame()
			check(game.level_manager.current_level_path == target, "Kein sofortiger Rücksprung")
			if "--initial-only" in OS.get_cmdline_user_args():
				game.free()
				print("transition_ground: %d Checks, %d Fehler" % [checks, failures])
				get_tree().quit(1 if failures else 0)
				return
	game.free()
	print("transition_ground: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
