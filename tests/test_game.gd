extends SceneTree
## Run after an editor import:
## godot --headless --path . --script res://tests/test_game.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	game.recording_enabled = false
	game.save_path = "user://test_game_progress.json"
	root.add_child(game)
	game.unlocked_level = 1
	game.select_level(1)
	var board: MahjongBoardView = game.get_node("MahjongBoard")
	if board.rendered_tiles.size() != 36:
		push_error("Expected 36 visual tile nodes")
		quit(1)
		return
	# A direct call (or a future UI bug) must not select a blocked tile.
	game.call("_on_tile_pressed", 2)
	game.call("_on_tile_pressed", -1)
	game.call("_on_tile_pressed", 999)
	if game.selected_id != -1 or BoardRules.remaining_count(game.tiles) != 36:
		push_error("Blocked/out-of-range selection must be rejected")
		quit(1)
		return
	var pair := BoardRules.first_available_pair(game.tiles, board.tile_size)
	if pair.size() != 2:
		push_error("Expected an initial available pair")
		quit(1)
		return
	game.call("_on_tile_pressed", pair[0])
	game.call("_on_tile_pressed", pair[1])
	if BoardRules.remaining_count(game.tiles) > 34:
		push_error("Matching should remove at least the manual pair")
		quit(1)
		return
	game.undo_last_match()
	if BoardRules.remaining_count(game.tiles) != 36:
		push_error("Undo should restore the pair")
		quit(1)
		return
	game.new_game()
	if BoardRules.remaining_count(game.tiles) != 36 or board.rendered_tiles.size() != 36:
		push_error("New game should rebuild 36 cards")
		quit(1)
		return
	print("Game smoke test passed (load, match, undo, restart)")
	DirAccess.remove_absolute(game.save_path)
	quit(0)
