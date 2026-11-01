class_name BoardRules
extends RefCounted
## Pure geometry / matching queries. No drawing, animation or input handling.

static func is_free(tiles: Array[MahjongTileState], index: int, tile_size: Vector2) -> bool:
	var tile := tiles[index]
	if tile.removed:
		return false
	var footprint := Rect2(tile.position, tile_size)
	for other in tiles:
		if other.removed or other.layer <= tile.layer:
			continue
		# Tiny edge intersections caused by the hand-painted layer offset
		# should not count as physically covering the tile.
		var overlap := footprint.intersection(Rect2(other.position, tile_size))
		if overlap.get_area() > tile_size.x * tile_size.y * 0.12:
			return false
	var blocked_left := false
	var blocked_right := false
	for other in tiles:
		if other.removed or other.layer != tile.layer or other.row != tile.row:
			continue
		if other.column == tile.column - 1:
			blocked_left = true
		elif other.column == tile.column + 1:
			blocked_right = true
	return not (blocked_left and blocked_right)

static func can_match(tiles: Array[MahjongTileState], first: int, second: int, tile_size: Vector2) -> bool:
	return first != second \
		and tiles[first].pet_id == tiles[second].pet_id \
		and is_free(tiles, first, tile_size) \
		and is_free(tiles, second, tile_size)

static func first_available_pair(tiles: Array[MahjongTileState], tile_size: Vector2) -> Array[int]:
	var first_by_pet: Dictionary = {}
	for i in range(tiles.size()):
		if not is_free(tiles, i, tile_size):
			continue
		var pet: String = tiles[i].pet_id
		if first_by_pet.has(pet):
			return [first_by_pet[pet], i]
		first_by_pet[pet] = i
	return []

static func remaining_count(tiles: Array[MahjongTileState]) -> int:
	var count := 0
	for tile in tiles:
		if not tile.removed:
			count += 1
	return count

