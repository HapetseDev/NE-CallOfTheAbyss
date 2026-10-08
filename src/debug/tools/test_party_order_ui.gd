extends Node
var failures := 0
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var game := load("res://src/core/main_game/main_game.tscn").instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame
	var ui := game.game_windows
	var first_size := Vector2.ZERO
	for cycle in range(5):
		game._on_top_bar_party_pressed()
		for frame in range(5): await get_tree().process_frame
		if cycle == 0: first_size = ui._panel.size
		if not ui.visible or ui._panel.size != first_size or ui._panel.position.y < 0:
			failures += 1
		if cycle % 2 == 0:
			ui.close()
		else:
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			ui._unhandled_input(escape)
		await get_tree().process_frame
		if ui.visible or GameState.is_player_input_locked(): failures += 1
	game.free()
	await get_tree().process_frame
	print("party_order_ui: %d Fehler" % failures)
	get_tree().quit(1 if failures else 0)
