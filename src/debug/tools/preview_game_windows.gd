extends Node
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var game := preload("res://src/core/main_game/main_game.tscn").instantiate()
	add_child(game)
	for frame in 15: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/necota-overview.png")
	for page in [0,1,2,3]:
		game.game_windows.open_page(page)
		for frame in 5: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/necota-window-%d.png" % page)
	game.game_windows.close()
	await get_tree().process_frame
	get_tree().quit()
