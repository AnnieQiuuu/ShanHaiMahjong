class_name BoardGenerator
extends RefCounted
## Builds a 24 + 8 + 4 layout and assigns matched pairs along a legal path.
## This guarantees at least one INITIAL solution, not every player move.

static func create_layout(tile_size: Vector2, step: Vector2, layer_offset: Vector2) -> Array[MahjongTileState]:
	var result: Array[MahjongTileState] = []
	for row in range(4):
		for column in range(6):
			_add(result, 0, column, row, step, layer_offset)
	for row in range(1, 3):
		for column in range(1, 5):
			_add(result, 1, column, row, step, layer_offset)
	for row in range(1, 3):
		for column in range(2, 4):
			_add(result, 2, column, row, step, layer_offset)
	return result

static func _add(tiles: Array[MahjongTileState], layer: int, column: int, row: int, step: Vector2, offset: Vector2) -> void:
	var pos := Vector2(column * step.x, row * step.y) + offset * layer
	tiles.append(MahjongTileState.new(tiles.size(), layer, column, row, pos))

static func create_level_layout(config: Dictionary, step: Vector2, offset: Vector2) -> Array[MahjongTileState]:
	var result: Array[MahjongTileState] = []
	for layer in range(config.layers.size()):
		var shapes: Array = config.layers[layer]
		if not shapes[0] is Array:
			shapes = [shapes]
		for shape in shapes:
			for row in range(int(shape[3]), int(shape[3]) + int(shape[1])):
				for column in range(int(shape[2]), int(shape[2]) + int(shape[0])):
					_add(result, layer, column, row, step, offset)
	return result

static func assign_solvable_pairs(tiles: Array[MahjongTileState], tile_size: Vector2, pet_ids: Array[String], seed_value: int, solution_out: Array = [], configured_pairs: Array[String] = []) -> bool:
	solution_out.clear()
	if tiles.is_empty() or tiles.size() % 2 != 0 or pet_ids.is_empty() or pet_ids.size() > tiles.size() / 2:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array[String] = pet_ids.duplicate()
	_shuffle(pool, rng)
	var pairs: Array[String] = []
	# Every selected species gets a pair; distribute extra pairs evenly.
	for i in range(tiles.size() / 2):
		pairs.append(pool[i % pool.size()])
	if not configured_pairs.is_empty():
		if configured_pairs.size() != tiles.size() / 2:
			return false
		for id in pet_ids:
			if id not in configured_pairs:
				return false
		for id in configured_pairs:
			if id not in pet_ids:
				return false
		pairs = configured_pairs.duplicate()
	return _assign_remaining(tiles, tile_size, pairs, rng, solution_out)

static func shuffle_remaining(tiles: Array[MahjongTileState], tile_size: Vector2, seed_value: int) -> bool:
	if not can_shuffle_remaining(tiles, tile_size):
		return false
	var active: Array[int] = []
	var identities: Array[String] = []
	var free: Array[int] = []
	for i in range(tiles.size()):
		if not tiles[i].removed:
			active.append(i)
			identities.append(tiles[i].pet_id)
			if BoardRules.is_free(tiles, i, tile_size):
				free.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_shuffle(identities, rng)
	_shuffle(free, rng)
	var pair_id := ""
	for id in identities:
		if identities.count(id) >= 2:
			pair_id = id
			break
	identities.erase(pair_id)
	identities.erase(pair_id)
	tiles[free[0]].pet_id = pair_id
	tiles[free[1]].pet_id = pair_id
	for index in active:
		if index != free[0] and index != free[1]:
			tiles[index].pet_id = identities.pop_back()
	return true

static func can_shuffle_remaining(tiles: Array[MahjongTileState], tile_size: Vector2) -> bool:
	var counts: Dictionary = {}
	var free_count := 0
	var has_pair := false
	for i in range(tiles.size()):
		if tiles[i].removed:
			continue
		var id := tiles[i].pet_id
		counts[id] = int(counts.get(id, 0)) + 1
		has_pair = has_pair or counts[id] >= 2
		if BoardRules.is_free(tiles, i, tile_size):
			free_count += 1
	return has_pair and free_count >= 2

static func _assign_remaining(tiles: Array[MahjongTileState], tile_size: Vector2, pairs: Array[String], rng: RandomNumberGenerator, solution_out: Array) -> bool:
	var original: Array[bool] = []
	for tile in tiles:
		original.append(tile.removed)
	var removal_order: Array[Array] = []
	for attempt in range(100):
		for i in range(tiles.size()):
			tiles[i].removed = original[i]
		removal_order.clear()
		while removal_order.size() < pairs.size():
			var free_tiles: Array[int] = []
			for index in range(tiles.size()):
				if BoardRules.is_free(tiles, index, tile_size):
					free_tiles.append(index)
			if free_tiles.size() < 2:
				break
			_shuffle(free_tiles, rng)
			var first := free_tiles[0]
			var second := free_tiles[1]
			removal_order.append([first, second])
			tiles[first].removed = true
			tiles[second].removed = true
		if removal_order.size() == pairs.size():
			break
	for i in range(tiles.size()):
		tiles[i].removed = original[i]
	if removal_order.size() != pairs.size():
		return false
	_shuffle(pairs, rng)
	for i in range(removal_order.size()):
		for index in removal_order[i]:
			tiles[index].pet_id = pairs[i]
	for pair in removal_order:
		solution_out.append(pair.duplicate())
	return true

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[j]
		items[j] = temp

