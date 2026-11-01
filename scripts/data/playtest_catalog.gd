class_name PlaytestCatalog
extends RefCounted
## Hand-authored diagnostic boards, separate from campaign content and save data.

const NAMES := ["基础五行", "Combo练习", "孤牌残局", "水开路", "土护佑救局"]
const HELP := [
	"先重开，再分别尝试火、风、水、雷、土的一对。对照操作记录查看目标与释放牌数。",
	"连续配掉五对土牌，观察×1至×5；也可中途消火牌，比较Combo重置。",
	"先消火：会留下孤牌。先消风→水→火：可清空。可洗牌或撤回来比较。",
	"水→火→风可以清空。勾选关闭元素后重开，消水后会卡住；本局没有洗牌。",
	"先消土，获得护佑后洗牌，再消剩余两对。关闭元素重试：没有护佑可救局。本局没有普通洗牌。"
]

static func create(index: int, step: Vector2, offset: Vector2) -> Array[MahjongTileState]:
	var tiles: Array[MahjongTileState] = []
	if index == 0:
		for i in range(PetCatalog.BASE_IDS.size()):
			for j in range(2):
				_add(tiles, 0, (i % 3) * 3 + j, (i / 3) * 2, PetCatalog.BASE_IDS[i], step, offset)
		for layer in range(2):
			for col in [0, 2]:
				_add(tiles, layer, col, 4, "030" if layer == 0 else "002", step, offset)
	elif index == 1:
		for i in range(6):
			for j in range(2):
				_add(tiles, 0, (i % 3) * 3 + j, (i / 3) * 2, PetCatalog.EARTH_PLACEHOLDER_ID if i < 5 else "001", step, offset)
	elif index == 2:
		for col in [0, 2]:
			_add(tiles, 0, col, 0, "001", step, offset)
		for layer in range(2):
			for col in [0, 2]:
				_add(tiles, layer, col, 2, "030" if layer == 0 else "002", step, offset)
	elif index == 3:
		_add(tiles, 0, 0, 0, "030", step, offset)
		_add(tiles, 0, 2, 0, "030", step, offset)
		_add(tiles, 0, 0, 2, "001", step, offset)
		_add(tiles, 1, 2, 2, "001", step, offset)
		_add(tiles, 1, 0, 2, "002", step, offset)
		_add(tiles, 0, 2, 2, "002", step, offset)
	elif index == 4:
		for col in [0, 2]:
			_add(tiles, 0, col, 0, PetCatalog.EARTH_PLACEHOLDER_ID, step, offset)
		for col in range(4):
			_add(tiles, 0, col, 2, "002" if col < 2 else "030", step, offset)
	return tiles

static func _add(tiles: Array[MahjongTileState], layer: int, col: int, row: int, pet: String, step: Vector2, offset: Vector2) -> void:
	var tile := MahjongTileState.new(tiles.size(), layer, col, row, Vector2(col, row) * step + offset * layer)
	tile.pet_id = pet
	tiles.append(tile)
