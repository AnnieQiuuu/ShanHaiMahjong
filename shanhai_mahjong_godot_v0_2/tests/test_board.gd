extends SceneTree
## Run: godot --headless --path . --script res://tests/test_board.gd

func _initialize() -> void:
	var errors := 0
	for seed_value in range(1, 51):
		var tiles := BoardGenerator.create_layout(Vector2(103, 151), Vector2(107, 140), Vector2(-5, -10))
		if tiles.size() != 36:
			errors += 1
			continue
		if not BoardGenerator.assign_solvable_pairs(tiles, Vector2(103, 151), PetCatalog.IDS, seed_value):
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
	# Geometry regression checks (no above-layer blocker at first/last edge).
	var edge_tiles := BoardGenerator.create_layout(Vector2(103, 151), Vector2(107, 140), Vector2(-5, -10))
	if not BoardRules.is_free(edge_tiles, 0, Vector2(103, 151)):
		errors += 1
	if BoardRules.is_free(edge_tiles, 2, Vector2(103, 151)):
		errors += 1
	if errors > 0:
		push_error("Board smoke tests failed: %d issues" % errors)
		quit(1)
	else:
		print("Board smoke tests passed (50 seeds + geometry checks)")
		quit(0)
