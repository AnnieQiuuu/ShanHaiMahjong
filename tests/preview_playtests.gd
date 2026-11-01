extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.save_path = "user://preview_diagnostics_progress.json"
	game.recording_enabled = false
	game.fixed_seed = 20261101
	root.add_child(game)
	for i in range(3):
		game.select_playtest(i + 1)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/playtest_%d.png" % i)
	quit()
