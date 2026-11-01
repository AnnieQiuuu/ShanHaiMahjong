extends SceneTree
## Graphics-enabled animation verification and UI captures.

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.save_path = "user://preview_release_progress.json"
	game.fixed_seed = 20261101
	game.recording_enabled = false
	root.add_child(game)
	await process_frame
	await capture("release_clean")
	game.toggle_test_panel()
	game.select_playtest(1)
	game._on_tile_pressed(4)
	game._on_tile_pressed(5)
	check(game.is_resolving and not game.board.input_enabled, "Preview gates board input")
	check(game.get_node("HUD/Combo").text == "水 ×1", "Combo display updates before effect preview")
	check(game.get_node("HUD/Counter").text == "剩余 12 / 14", "Counter reflects manual pair during preview")
	var before: Dictionary = game._snapshot()
	game.undo_last_match()
	game.shuffle_board()
	check(game._snapshot() == before, "Undo/shuffle cannot race element preview")
	check(not game.board.rendered_tiles[10].liberated, "Water target retains pre-effect visual during preview")
	await create_timer(0.12).timeout
	await capture("release_water_preview")
	await create_timer(game.board.effect_duration).timeout
	check(not game.is_resolving and game.board.input_enabled, "Preview completion restores input")
	check(game.board.rendered_tiles[10].liberated and game.board.rendered_tiles[10].release_glow > 0, "Water result and newly-free flash applied")
	await capture("release_water_result")
	game.select_playtest(1)
	game._on_tile_pressed(2)
	game._on_tile_pressed(3)
	await create_timer(0.45).timeout
	check(game.board.rendered_tiles[12].position != game.tiles[12].position, "Wind visibly slides selected target")
	await capture("release_wind")
	game.new_game()
	var restarted: Dictionary = game._snapshot()
	await create_timer(0.75).timeout
	check(game._snapshot() == restarted and not game.is_resolving, "Restart cancels old animation completion")
	game.select_playtest(5)
	game._on_tile_pressed(0)
	game._on_tile_pressed(1)
	await create_timer(game.board.effect_duration + 0.12).timeout
	check(game.get_node("HUD/Deadlock").visible, "Earth recovery modal appears after feedback")
	await capture("release_deadlock_recoverable")
	game.get_node("HUD/Deadlock/Panel/Actions/Shuffle").pressed.emit()
	check(game.protection == 0 and not game.get_node("HUD/Deadlock").visible, "Recovery action uses protection and closes modal")
	game.get_node("HUD/TestPanel/DisableSkills").set_pressed_no_signal(true)
	game.select_playtest(4)
	game._on_tile_pressed(0)
	game._on_tile_pressed(1)
	check(game.has_failed, "Disabled water loses actual scenario")
	await capture("release_deadlock_failed")
	DirAccess.remove_absolute(game.save_path)
	if errors.is_empty():
		print("Graphics feedback passed: preview/input gating, water reveal, wind slide, restart cancellation, recovery modal, disabled-water comparison")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)
