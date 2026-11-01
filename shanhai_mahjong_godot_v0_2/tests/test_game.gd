extends SceneTree
## Run after an editor import:
## godot --headless --path . --script res://tests/test_game.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	var board: MahjongBoardView = game.get_node("MahjongBoard")
	if board.rendered_tiles.size() != 36:
		push_error("Expected 36 visual tile nodes")
		quit(1)
		return
	var pair := BoardRules.first_available_pair(game.tiles, board.tile_size)
	if pair.size() != 2:
		push_error("Expected an initial available pair")
		quit(1)
		return
	game.call("_on_tile_pressed", pair[0])
	game.call("_on_tile_pressed", pair[1])
	if BoardRules.remaining_count(game.tiles) != 34:
		push_error("Matching should remove exactly two tiles")
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
	quit(0)
