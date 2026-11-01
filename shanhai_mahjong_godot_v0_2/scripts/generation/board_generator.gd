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

static func assign_solvable_pairs(tiles: Array[MahjongTileState], tile_size: Vector2, pet_ids: Array[String], seed_value: int) -> bool:
	if tiles.size() % 2 != 0 or pet_ids.size() < 9 or tiles.size() != 36:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var removal_order: Array[Array] = []
	for attempt in range(100):
		for tile in tiles:
			tile.removed = false
		removal_order.clear()
		while removal_order.size() < tiles.size() / 2:
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
		if removal_order.size() == tiles.size() / 2:
			break
	if removal_order.size() != tiles.size() / 2:
		for tile in tiles:
			tile.removed = false
		return false
	var pool: Array[String] = pet_ids.duplicate()
	_shuffle(pool, rng)
	var pair_species: Array[String] = []
	for i in range(9):
		pair_species.append(pool[i])
		pair_species.append(pool[i])
	_shuffle(pair_species, rng)
	for i in range(removal_order.size()):
		for index in removal_order[i]:
			tiles[index].pet_id = pair_species[i]
	for tile in tiles:
		tile.removed = false
	return true

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[j]
		items[j] = temp

