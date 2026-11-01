extends SceneTree
## Run: godot --headless --path . --script res://tests/test_board.gd

func _initialize() -> void:
	var errors := 0
	var dimensions := Vector2(103, 151)
	var pool: Array[String] = PetCatalog.IDS.duplicate()
	pool.resize(9)
	for seed_value in range(1, 501):
		var tiles := BoardGenerator.create_layout(Vector2(103, 151), Vector2(107, 140), Vector2(-5, -10))
		var witness: Array = []
		if tiles.size() != 36:
			errors += 1
			continue
		if not BoardGenerator.assign_solvable_pairs(tiles, dimensions, pool, seed_value, witness):
			errors += 1
			continue
		var counts: Dictionary = {}
		for tile in tiles:
			counts[tile.pet_id] = int(counts.get(tile.pet_id, 0)) + 1
		if counts.size() != 9:
			errors += 1
		for count in counts.values():
			if count != 4:
				errors += 1
		if BoardRules.first_available_pair(tiles, Vector2(103, 151)).is_empty():
			errors += 1
		# Independently REPLAY every proposed removal against the actual rules.
		# A stored generation path is only valid if every move is legally matched.
		if not _replay_solution(tiles, dimensions, witness):
			errors += 1
	# Geometry regression checks (no above-layer blocker at first/last edge).
	var edge_tiles := BoardGenerator.create_layout(Vector2(103, 151), Vector2(107, 140), Vector2(-5, -10))
	if not BoardRules.is_free(edge_tiles, 0, Vector2(103, 151)):
		errors += 1
	if BoardRules.is_free(edge_tiles, 2, Vector2(103, 151)):
		errors += 1
	# Both sides occupied on the same layer -> blocked; either side removed -> free.
	var neighbors: Array[MahjongTileState] = [
		_mk(0, 0, 0, 0, Vector2.ZERO, "cat"),
		_mk(1, 0, 1, 0, Vector2(107, 0), "cat"),
		_mk(2, 0, 2, 0, Vector2(214, 0), "cat")
	]
	if BoardRules.is_free(neighbors, 1, dimensions):
		errors += 1
	neighbors[0].removed = true
	if not BoardRules.is_free(neighbors, 1, dimensions):
		errors += 1
	# Cross-layer matches ARE allowed if both are free and have the same face.
	var across_layers: Array[MahjongTileState] = [
		_mk(0, 0, 0, 0, Vector2.ZERO, "cat"),
		_mk(1, 1, 3, 0, Vector2(321, 0), "cat")
	]
	if not BoardRules.can_match(across_layers, 0, 1, dimensions):
		errors += 1
	across_layers.append(_mk(2, 2, 3, 0, Vector2(321, 0), "dog"))
	if BoardRules.can_match(across_layers, 0, 1, dimensions):
		errors += 1
	across_layers[2].removed = true
	if not BoardRules.can_match(across_layers, 0, 1, dimensions):
		errors += 1
	across_layers[1].pet_id = "dog"
	if BoardRules.can_match(across_layers, 0, 1, dimensions):
		errors += 1
	# An upper tile overlapping even a thin strip of the playable face blocks.
	# But overlap with the decorative jade side must not block.
	var lower := _mk(0, 0, 0, 0, Vector2.ZERO, "cat")
	var upper := _mk(1, 1, 1, 0, Vector2(90, 0), "dog")
	var two: Array[MahjongTileState] = [lower, upper]
	if not BoardRules.is_free(two, 0, dimensions):
		errors += 1
	upper.position.x = 79.0
	if BoardRules.is_free(two, 0, dimensions):
		errors += 1
	upper.removed = true
	if not BoardRules.is_free(two, 0, dimensions):
		errors += 1
	if BoardRules.can_match(two, 0, 1, dimensions):
		errors += 1
	if errors > 0:
		push_error("Board smoke tests failed: %d issues" % errors)
		quit(1)
	else:
		print("Board rules passed (500 fully replayed seeds + layer/side/face checks)")
		quit(0)

func _mk(id: int, layer: int, column: int, row: int, pos: Vector2, species: String) -> MahjongTileState:
	var tile := MahjongTileState.new(id, layer, column, row, pos)
	tile.pet_id = species
	return tile

func _replay_solution(tiles: Array[MahjongTileState], tile_size: Vector2, witness: Array) -> bool:
	if witness.size() != tiles.size() / 2:
		return false
	for pair in witness:
		if pair.size() != 2 or not BoardRules.can_match(tiles, pair[0], pair[1], tile_size):
			return false
		tiles[pair[0]].removed = true
		tiles[pair[1]].removed = true
	var succeeded := BoardRules.remaining_count(tiles) == 0
	for tile in tiles:
		tile.removed = false
	return succeeded
