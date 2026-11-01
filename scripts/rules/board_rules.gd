class_name BoardRules
extends RefCounted
## Pure geometry / matching queries. No drawing, animation or input handling.

# Only the upper face of a mahjong tile counts as covering another tile.
# The jade-green right/bottom edges are decorative thickness, not face area.
# Coordinates are proportions of the rendered tile rectangle (x, y, w, h).
const FACE_RECT := Rect2(0.10, 0.08, 0.78, 0.79)

static func face_rect(tile: MahjongTileState, tile_size: Vector2) -> Rect2:
	return Rect2(tile.position + FACE_RECT.position * tile_size, FACE_RECT.size * tile_size)

static func is_free(tiles: Array[MahjongTileState], index: int, tile_size: Vector2) -> bool:
	var tile := tiles[index]
	if tile.removed:
		return false
	if tile.liberated:
		return true
	var footprint := face_rect(tile, tile_size)
	for other in tiles:
		if other.removed or other.layer <= tile.layer:
			continue
		# Any positive overlap between *faces* blocks the lower tile.
		# No arbitrary percentage threshold: an exposed sliver is not free.
		if footprint.intersects(face_rect(other, tile_size)):
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

static func blocking_details(tiles: Array[MahjongTileState], index: int, tile_size: Vector2) -> Dictionary:
	var above: Array[int] = []
	var left: Array[int] = []
	var right: Array[int] = []
	var tile := tiles[index]
	if not tile.removed and not tile.liberated:
		for i in range(tiles.size()):
			var other := tiles[i]
			if i == index or other.removed:
				continue
			if other.layer > tile.layer and face_rect(tile, tile_size).intersects(face_rect(other, tile_size)):
				above.append(i)
			if other.layer == tile.layer and other.row == tile.row:
				if other.column == tile.column - 1:
					left.append(i)
				elif other.column == tile.column + 1:
					right.append(i)
	return {"above": above, "left": left, "right": right, "sides_locked": not left.is_empty() and not right.is_empty()}

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

