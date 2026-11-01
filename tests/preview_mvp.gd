extends SceneTree
## Optional rendered QA capture; use a graphics-enabled Godot invocation.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.save_path = "user://preview_mvp_progress.json"
	root.add_child(game)
	game.unlocked_level = 7
	game.select_level(7)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/mvp_board.png")
	game.get_node("HUD/CollectionPanel").show()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/mvp_collection.png")
	quit()
