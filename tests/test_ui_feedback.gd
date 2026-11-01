extends SceneTree

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.save_path = "user://test_ui_progress.json"
	game.recording_enabled = false
	game.fixed_seed = 20261101
	root.add_child(game)
	var board: MahjongBoardView = game.board
	# Replay layouts using actual editor-configured spacing, not old constants.
	for config in LevelCatalog.LEVELS:
		for seed_value in range(1, 11):
			var tiles := BoardGenerator.create_level_layout(config, board.column_row_step, board.layer_offset)
			var witness: Array = []
			var pool := LevelCatalog.pet_ids_for(config, seed_value)
			check(BoardGenerator.assign_solvable_pairs(tiles, board.tile_size, pool, seed_value, witness, LevelCatalog.pair_ids_for(config, pool, seed_value)), "Scene geometry generates solution")
			for i in range(tiles.size()):
				var detail := BoardRules.blocking_details(tiles, i, board.tile_size)
				check(BoardRules.is_free(tiles, i, board.tile_size) == (detail.above.is_empty() and not detail.sides_locked), "Lock explanation matches legality")
			for pair in witness:
				check(BoardRules.can_match(tiles, pair[0], pair[1], board.tile_size), "Actual geometry witness replay")
				tiles[pair[0]].removed = true
				tiles[pair[1]].removed = true
			check(BoardRules.remaining_count(tiles) == 0, "Actual geometry clears")
	var fixture: Array[MahjongTileState] = []
	for i in range(3):
		var tile := MahjongTileState.new(i, 0, i, 0, Vector2(i * 107, 0))
		tile.pet_id = "001"
		fixture.append(tile)
	var upper := MahjongTileState.new(3, 1, 1, 0, Vector2(107, 0))
	upper.pet_id = "002"
	fixture.append(upper)
	game.tiles = fixture
	board.display_board(fixture)
	board.hovered_id = 1
	board._update_inspection()
	check(board.rendered_tiles[0].is_related_blocker and board.rendered_tiles[2].is_related_blocker and board.rendered_tiles[3].is_related_blocker, "Highlight upper and both side blockers")
	check("左右" in game.get_node("HUD/TileInfo").text and "上方" in game.get_node("HUD/TileInfo").text, "Explain combined locks")
	upper.removed = true
	fixture[0].removed = true
	board.refresh(-1, [])
	check(board.rendered_tiles[1].is_available, "Removing top and one side unlocks tile")
	fixture[1].liberated = true
	board.refresh(-1, [])
	check(board.rendered_tiles[1].liberated and board.rendered_tiles[1].is_available, "Water override is visually available")
	# Hit order follows layer, even when the model array is not layer-sorted.
	upper.removed = false
	upper.position = Vector2.ZERO
	fixture[0].removed = false
	var reordered: Array[MahjongTileState] = [upper, fixture[0]]
	board.display_board(reordered)
	check(board.tile_at_point(Vector2(50, 50)) == 0, "Highest rendered layer receives hit")
	fixture[0].liberated = true
	board.refresh(-1, [])
	check(board.tile_at_point(Vector2(50, 50)) == 1, "Water-freed lower tile receives hit above stack")
	# Actual three-pair win opens the modal, including after review and undo.
	game.select_playtest(3)
	for pair in [[4, 5], [2, 3], [0, 1]]:
		game._on_tile_pressed(pair[0])
		game._on_tile_pressed(pair[1])
	check(game.get_node("HUD/Victory").visible, "Win shows victory modal")
	check(not game.get_node("HUD/Victory/Panel/Actions/Next").visible, "Test win has no campaign next button")
	game.get_node("HUD/Victory/Panel/Actions/Review").pressed.emit()
	game._refresh()
	check(not game.get_node("HUD/Victory").visible, "Review dismissal survives refresh")
	game.undo_last_match()
	game._on_tile_pressed(0)
	game._on_tile_pressed(1)
	check(game.get_node("HUD/Victory").visible, "Rewinning after undo opens modal again")
	game.get_node("HUD/Victory/Panel/Actions/Restart").pressed.emit()
	check(not game.has_won and not game.get_node("HUD/Victory").visible, "Replay button restarts same test")
	game.unlocked_level = 7
	game.select_level(7)
	for tile in game.tiles:
		tile.removed = true
	game._refresh()
	check(not game.get_node("HUD/Victory/Panel/Actions/Next").visible, "Final region has no next button")
	game.select_level(0)
	for tile in game.tiles:
		tile.removed = true
	game._refresh()
	check(game.get_node("HUD/Victory/Panel/Actions/Next").visible, "Campaign win offers next region")
	game.get_node("HUD/Victory/Panel/Actions/Next").pressed.emit()
	check(game.level_index == 1 and not game.has_won and not game.get_node("HUD/Victory").visible, "Next-region button starts next board")
	DirAccess.remove_absolute(game.save_path)
	if errors.is_empty():
		print("UI feedback passed: 80 actual-geometry witnesses, lock reasons/highlights, layer hit order, water override, victory/review/undo/restart/next")
		quit(0)
	else:
		for message in errors:
			push_error(message)
		quit(1)
