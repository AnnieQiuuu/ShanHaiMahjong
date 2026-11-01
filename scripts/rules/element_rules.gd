class_name ElementRules
extends RefCounted
## Pure target selection. Geometry is measured in newly available tiles.

static func available_count(tiles: Array[MahjongTileState], size: Vector2) -> int:
	var count := 0
	for i in range(tiles.size()):
		if BoardRules.is_free(tiles, i, size):
			count += 1
	return count

static func best_pair(tiles: Array[MahjongTileState], size: Vector2, discovered: Array) -> Array[int]:
	var result: Array[int] = []
	var best := -1
	for i in range(tiles.size()):
		if tiles[i].pet_id not in discovered or not BoardRules.is_free(tiles, i, size):
			continue
		for j in range(i + 1, tiles.size()):
			if not BoardRules.can_match(tiles, i, j, size):
				continue
			tiles[i].removed = true
			tiles[j].removed = true
			var score := available_count(tiles, size)
			tiles[i].removed = false
			tiles[j].removed = false
			if score > best:
				best = score
				result = [i, j]
	return result

static func blocker_target(tiles: Array[MahjongTileState], size: Vector2, discovered: Array, prefer_height: bool) -> int:
	var result := -1
	var best := -2147483648
	var baseline := available_count(tiles, size)
	for i in range(tiles.size()):
		if tiles[i].removed or tiles[i].pet_id not in discovered:
			continue
		tiles[i].removed = true
		var released := available_count(tiles, size) - baseline
		# Removing a free tile also removes it from the availability count.
		tiles[i].removed = false
		if BoardRules.is_free(tiles, i, size):
			released += 1
		if prefer_height:
			var covered := false
			for other in tiles:
				if not other.removed and other.layer > tiles[i].layer and BoardRules.face_rect(other, size).intersects(BoardRules.face_rect(tiles[i], size)):
					covered = true
			if covered:
				continue
		var covered_count := 0
		for other in tiles:
			if not other.removed and other.layer < tiles[i].layer and BoardRules.face_rect(other, size).intersects(BoardRules.face_rect(tiles[i], size)):
				covered_count += 1
		if released <= 0 and covered_count == 0:
			continue
		var score := covered_count * 10000 + released * 100 + tiles[i].layer
		if prefer_height:
			score = tiles[i].layer * 100 + released
		var copies := 0
		for other in tiles:
			if not other.removed and other.pet_id == tiles[i].pet_id:
				copies += 1
		# Prefer clearing an existing orphan; avoid destroying a last intact pair.
		if copies == 1:
			score += 1000000
		elif copies == 2:
			score -= 1000000
		elif copies % 2 == 0:
			score -= 2000
		if score > best:
			best = score
			result = i
	return result

static func water_target(tiles: Array[MahjongTileState], size: Vector2) -> int:
	var result := -1
	var best := -1
	for i in range(tiles.size()):
		if tiles[i].removed or BoardRules.is_free(tiles, i, size):
			continue
		var score := tiles[i].layer
		for j in range(tiles.size()):
			if i != j and tiles[j].pet_id == tiles[i].pet_id and BoardRules.is_free(tiles, j, size):
				score += 100
		if score > best:
			best = score
			result = i
	return result
