extends SceneTree
## Headless MVP regression: five layouts, atomic turns, shuffle and persistence.

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func counts(tiles: Array[MahjongTileState]) -> Dictionary:
	var result: Dictionary = {}
	for tile in tiles:
		if not tile.removed:
			result[tile.pet_id] = int(result.get(tile.pet_id, 0)) + 1
	return result

func _run() -> void:
	var dimensions := Vector2(103, 151)
	for level in range(8):
		var config: Dictionary = LevelCatalog.LEVELS[level]
		var pool := LevelCatalog.pet_ids_for(config, level)
		var elements: Dictionary = {}
		for id in pool:
			elements[PetCatalog.element_for(id)] = true
		check(elements.size() == 5, "Every level must cover five elements")
		for seed_value in range(1, 21):
			pool = LevelCatalog.pet_ids_for(config, seed_value)
			var tiles := BoardGenerator.create_level_layout(config, Vector2(107, 140), Vector2(-5, -10))
			var witness: Array = []
			check(tiles.size() == int(config.total_tiles), "Configured tile count")
			check(BoardGenerator.assign_solvable_pairs(tiles, dimensions, pool, seed_value, witness, LevelCatalog.pair_ids_for(config, pool, seed_value)), "Level generation")
			check(counts(tiles).size() == int(config.species), "Configured species count")
			for count in counts(tiles).values():
				check(int(count) >= 2 and int(count) % 2 == 0, "Paired species at deal")
			for pair in witness:
				check(BoardRules.can_match(tiles, pair[0], pair[1], dimensions), "Witness legal at replay")
				tiles[pair[0]].removed = true
				tiles[pair[1]].removed = true
			check(BoardRules.remaining_count(tiles) == 0, "Complete witness")
	# Pure effects: blocked lower tile, two top blockers and independent partners.
	var fixture: Array[MahjongTileState] = []
	for i in range(6):
		var tile := MahjongTileState.new(i, 0, i * 2, 0, Vector2(i * 220, 0))
		tile.pet_id = "001" if i >= 2 else "030"
		fixture.append(tile)
	fixture[2].position = fixture[0].position
	fixture[2].layer = 1
	fixture[3].position = fixture[1].position
	fixture[3].layer = 1
	check(ElementRules.blocker_target(fixture, dimensions, [], false) == -1, "Undiscovered fire targets protected")
	check(ElementRules.best_pair(fixture, dimensions, []).is_empty(), "Undiscovered lightning targets protected")
	check(ElementRules.blocker_target(fixture, dimensions, ["001"], false) in [2, 3], "Fire finds one blocker")
	check(ElementRules.blocker_target(fixture, dimensions, ["001"], true) in [2, 3], "Wind finds top blocker")
	var water := ElementRules.water_target(fixture, dimensions)
	check(water in [0, 1], "Water selects blocked target")
	fixture[water].liberated = true
	check(BoardRules.is_free(fixture, water, dimensions), "Water makes covered tile playable")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	game.recording_enabled = false
	game.all_regions_unlocked = false
	game.save_path = "user://test_mvp_progress.json"
	DirAccess.remove_absolute(game.save_path)
	root.add_child(game)
	# Base fire/wind remove exactly one, lightning exactly one legal pair.
	for element in ["fire", "wind", "lightning"]:
		for tile in fixture:
			tile.removed = false
			tile.liberated = false
		game.tiles = fixture
		game.board.display_board(game.tiles)
		game.discovered.assign(PetCatalog.IDS)
		game.combo_count = 1
		game._resolve_element(element)
		check(BoardRules.remaining_count(fixture) == (4 if element == "lightning" else 5), "Exact base removal count: " + element)
	game.new_game()
	check(game.tiles.size() == 28, "Start with first level")
	game.select_level(4)
	check(game.level_index == 0, "Locked levels rejected")
	game.unlocked_level = 7
	for level in range(8):
		game.select_level(level)
		for turn in range(6):
			var pair := BoardRules.first_available_pair(game.tiles, dimensions)
			if pair.is_empty():
				break
			var before: Dictionary = game._snapshot()
			game._on_tile_pressed(pair[0])
			game._on_tile_pressed(pair[1])
			if turn < 3:
				var remaining: int = game.undo_remaining
				game.undo_last_match()
				check(game._snapshot() == before, "Undo restores all local state")
				check(game.undo_remaining == remaining - 1, "Undo consumes one charge")
				game._on_tile_pressed(pair[0])
				game._on_tile_pressed(pair[1])
	# Explicit earth Combo tiers and no automatic lightning recursion.
	for element in ["fire", "wind", "water", "lightning", "earth"]:
		for strength in range(1, 6):
			game.new_game()
			game.discovered.assign(PetCatalog.IDS)
			game.combo_element = element
			game.combo_count = strength
			game._resolve_element(element)
			check(game.combo_count == strength, "Automatic effects do not increment Combo")
	game.new_game()
	game.combo_count = 3
	game.combo_element = "fire"
	var snapshot: Dictionary = game._snapshot()
	var original_counts := counts(game.tiles)
	game.shuffle_board()
	check(counts(game.tiles) == original_counts, "Shuffle preserves species multiplicity")
	check(game.combo_count == 0, "Shuffle resets Combo")
	check(not BoardRules.first_available_pair(game.tiles, dimensions).is_empty(), "Shuffle provides a pair")
	game.undo_last_match()
	check(game._snapshot() == snapshot, "Shuffle undo restores assignment and resources")
	game.toggle_pause()
	var paused: Dictionary = game._snapshot()
	game.shuffle_board()
	game.undo_last_match()
	var pair := BoardRules.first_available_pair(game.tiles, dimensions)
	game._on_tile_pressed(pair[0])
	check(game._snapshot() == paused and game.selected_id == -1, "Pause prevents board actions")
	game.toggle_pause()
	# Permanent discovery survives undo and reload; tests use isolated save files.
	game.discovered = PetCatalog.BASE_IDS.duplicate()
	game.tiles[pair[0]].pet_id = "029"
	game.tiles[pair[1]].pet_id = "029"
	game._on_tile_pressed(pair[0])
	game._on_tile_pressed(pair[1])
	check("029" in game.discovered, "Manual match discovers pet")
	game.undo_last_match()
	check("029" in game.discovered, "Discovery survives undo")
	var reloaded := scene.instantiate()
	# Isolate persistence from the user's real progress.
	reloaded.save_path = game.save_path
	root.add_child(reloaded)
	check("029" in reloaded.discovered, "Discovery survives restart")
	# A real even-count deadlock: both matching partners are blocked inside a row.
	game.new_game()
	game.tiles.clear()
	for i in range(4):
		var tile := MahjongTileState.new(i, 0, i, 0, Vector2(i * 107, 0))
		tile.pet_id = "001" if i < 2 else "002"
		game.tiles.append(tile)
	game.board.display_board(game.tiles)
	game.shuffle_remaining = 0
	game.protection = 1
	game._refresh()
	check(not game.has_failed, "Earth protection keeps deadlock recoverable")
	game.shuffle_board()
	check(game.protection == 0 and game.shuffle_remaining == 0, "Deadlock shuffle consumes protection")
	check(not BoardRules.first_available_pair(game.tiles, dimensions).is_empty(), "Protection shuffle resolves deadlock")
	game.undo_last_match()
	check(game.protection == 1, "Undo restores spent protection")
	game.protection = 0
	game._refresh()
	check(game.has_failed, "Deadlock with no resources fails")
	# An odd multiset can still be rearranged; no counterpart is manufactured.
	game.new_game()
	game.tiles.clear()
	for i in range(5):
		var tile := MahjongTileState.new(i, 0, i, 0, Vector2(i * 107, 0))
		tile.pet_id = ["001", "001", "001", "002", "030"][i]
		game.tiles.append(tile)
	game.board.display_board(game.tiles)
	game._refresh()
	var odd_before: Dictionary = game._snapshot()
	var odd_counts := counts(game.tiles)
	game.shuffle_board()
	check(counts(game.tiles) == odd_counts, "Odd shuffle preserves exact multiplicities")
	check(BoardRules.remaining_count(game.tiles) == 5, "Odd shuffle preserves total")
	check(not BoardRules.first_available_pair(game.tiles, dimensions).is_empty(), "Odd shuffle creates playable pair")
	game.undo_last_match()
	check(game._snapshot() == odd_before, "Odd shuffle undo restores identities and resources")
	for i in range(5):
		game.tiles[i].pet_id = PetCatalog.IDS[i]
	game.shuffle_remaining = 2
	game._refresh()
	check(game.has_failed, "All distinct remnants fail even with shuffle charges")
	game.shuffle_board()
	check(game.shuffle_remaining == 2, "Irrecoverable remnants do not consume charges")
	# Repeated manual elements advance Combo; different elements reset it.
	game.new_game()
	game.tiles.clear()
	for i in range(8):
		var tile := MahjongTileState.new(i, 0, i * 2, 0, Vector2(i * 220, 0))
		tile.pet_id = PetCatalog.EARTH_PLACEHOLDER_ID if i < 6 else "001"
		game.tiles.append(tile)
	game.board.display_board(game.tiles)
	for i in range(3):
		game._on_tile_pressed(i * 2)
		game._on_tile_pressed(i * 2 + 1)
		check(game.combo_count == i + 1, "Consecutive manual element advances Combo")
	game._process(10000.0)
	check(game.combo_count == 3, "Thinking time never expires Combo")
	game._on_tile_pressed(6)
	game._on_tile_pressed(7)
	check(game.combo_count == 1 and game.combo_element == "fire", "Different manual element resets Combo")
	game.undo_last_match()
	check(game.combo_count == 3 and game.combo_element == "earth", "Undo restores previous element Combo")
	game.unlocked_level = 0
	game.level_index = 0
	for tile in game.tiles:
		tile.removed = true
	game.has_won = false
	game._refresh()
	check(game.has_won and game.unlocked_level == 1, "Victory unlocks next level")
	DirAccess.remove_absolute(game.save_path)
	if errors.is_empty():
		print("MVP passed: 160 regional witnesses, five elements/tiers, protection, undo, shuffle, pause, discovery/save, unlock")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)
