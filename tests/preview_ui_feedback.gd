extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func capture_file(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func _capture() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.recording_enabled = false
	game.save_path = "user://preview_ui_feedback_progress.json"
	game.fixed_seed = 20261101
	root.add_child(game)
	game.unlocked_level = 7
	game.select_level(7)
	await process_frame
	await process_frame
	game.board.hovered_id = 1
	game.board._update_inspection()
	await capture_file("ui_stack")
	game.select_playtest(3)
	for pair in [[4, 5], [2, 3], [0, 1]]:
		game._on_tile_pressed(pair[0])
		game._on_tile_pressed(pair[1])
	await capture_file("ui_victory_test")
	game.select_level(0)
	for tile in game.tiles:
		tile.removed = true
	game._refresh()
	await capture_file("ui_victory")
	DirAccess.remove_absolute(game.save_path)
	quit()
