extends Node2D
## 36-tile Shanghai Solitaire. No skills, progression, or formal UI yet.

const CARD_W := 103.0
const CARD_H := 151.0
const STEP_X := 107.0
const STEP_Y := 140.0
const LAYER_OFFSET := Vector2(-5.0, -10.0)
const BOARD_CENTER := Vector2(640, 430)
const PET_IDS := ["001", "002", "008", "010", "011", "013", "018", "021", "023", "030", "032", "034", "035", "038"]
const FONT_COLOR := Color("433128")

var tile_body: Texture2D
var pet_textures: Dictionary = {}
var element_textures: Dictionary = {}
var tiles: Array[Dictionary] = []
var selected_id := -1
var selected_history: Array[Array] = []
var remaining := 36
var won := false
var hint_pair: Array[int] = []
var hint_until := 0
var randomizer := RandomNumberGenerator.new()

func _ready() -> void:
	randomizer.randomize()
	tile_body = load("res://assets/tile/handpainted_tile_v2.png")
	for pet_id in PET_IDS:
		pet_textures[pet_id] = load("res://assets/pets/no_%s_icon.png" % pet_id)
	for element in ["earth", "fire", "lightning", "water", "wind"]:
		element_textures[element] = load("res://assets/elements/%s.png" % element)
	start_new_game()

func start_new_game() -> void:
	tiles.clear()
	selected_history.clear()
	selected_id = -1
	remaining = 36
	won = false
	hint_pair.clear()
	# 24 + 8 + 4 tiles, centered and visibly stacked.
	for row in range(4):
		for col in range(6):
			_add_slot(0, col, row)
	for row in range(1, 3):
		for col in range(1, 5):
			_add_slot(1, col, row)
	for row in range(1, 3):
		for col in range(2, 4):
			_add_slot(2, col, row)
	if not _assign_solvable_pairs():
		push_error("Could not generate a solvable board")
	queue_redraw()

func _add_slot(layer: int, col: int, row: int) -> void:
	tiles.append({
		"id": tiles.size(), "layer": layer, "col": col, "row": row,
		"pet": "", "removed": false,
		"pos": Vector2(BOARD_CENTER.x - 3.0 * STEP_X + col * STEP_X,
			BOARD_CENTER.y - 2.0 * STEP_Y + row * STEP_Y) + layer * LAYER_OFFSET
	})

func _assign_solvable_pairs() -> bool:
	# Generate a legal removal path from geometry alone, then fill its pairs.
	# Every resulting board has at least this full solution path.
	var order: Array[Array] = []
	for attempt in range(80):
		for i in range(tiles.size()):
			tiles[i]["removed"] = false
		order.clear()
		while order.size() < 18:
			var candidates: Array[int] = []
			for i in range(tiles.size()):
				if _is_free(i):
					candidates.append(i)
			if candidates.size() < 2:
				break
			candidates.shuffle()
			var first := candidates[0]
			var second := candidates[1]
			order.append([first, second])
			tiles[first]["removed"] = true
			tiles[second]["removed"] = true
		if order.size() == 18:
			break
	if order.size() != 18:
		return false
	var deck: Array[String] = []
	# Nine different creatures, each used four times (two distinct pairs).
	var all_pets := PET_IDS.duplicate()
	all_pets.shuffle()
	for j in range(9):
		deck.append(all_pets[j])
		deck.append(all_pets[j])
	deck.shuffle()
	for i in range(18):
		for slot_id in order[i]:
			tiles[slot_id]["pet"] = deck[i]
	for i in range(tiles.size()):
		tiles[i]["removed"] = false
	return true

func _is_free(index: int) -> bool:
	var t := tiles[index]
	if t["removed"]:
		return false
	# Any upper-layer rectangle overlapping the face blocks this tile.
	var my_rect := Rect2(t["pos"], Vector2(CARD_W, CARD_H))
	for other in tiles:
		if other["removed"] or other["layer"] <= t["layer"]:
			continue
		var other_rect := Rect2(other["pos"], Vector2(CARD_W, CARD_H))
		if my_rect.intersects(other_rect):
			return false
	var left_blocked := false
	var right_blocked := false
	for other in tiles:
		if other["removed"] or other["layer"] != t["layer"] or other["row"] != t["row"]:
			continue
		if other["col"] == t["col"] - 1:
			left_blocked = true
		if other["col"] == t["col"] + 1:
			right_blocked = true
	return not (left_blocked and right_blocked)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				start_new_game()
			KEY_Z:
				undo_pair()
			KEY_H:
				show_hint()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_click(get_global_mouse_position())
	if event is InputEventScreenTouch and event.pressed:
		_on_click(event.position)

func _on_click(point: Vector2) -> void:
	if won:
		return
	# Highest layer and latest-drawn tile receives the click.
	for i in range(tiles.size() - 1, -1, -1):
		var t := tiles[i]
		if t["removed"]:
			continue
		if Rect2(t["pos"], Vector2(CARD_W, CARD_H)).has_point(point):
			if _is_free(i):
				_select_tile(i)
			return

func _select_tile(index: int) -> void:
	if selected_id == index:
		selected_id = -1
	elif selected_id < 0:
		selected_id = index
	elif tiles[selected_id]["pet"] == tiles[index]["pet"]:
		selected_history.append([selected_id, index])
		tiles[selected_id]["removed"] = true
		tiles[index]["removed"] = true
		remaining -= 2
		selected_id = -1
		hint_pair.clear()
		won = remaining == 0
	else:
		selected_id = index
	queue_redraw()

func undo_pair() -> void:
	if selected_history.is_empty():
		return
	var last: Array = selected_history.pop_back()
	for index in last:
		tiles[index]["removed"] = false
	remaining += 2
	won = false
	selected_id = -1
	hint_pair.clear()
	queue_redraw()

func show_hint() -> void:
	var free_by_pet := {}
	for i in range(tiles.size()):
		if not _is_free(i):
			continue
		var pet: String = tiles[i]["pet"]
		if free_by_pet.has(pet):
			hint_pair = [free_by_pet[pet], i]
			hint_until = Time.get_ticks_msec() + 2300
			queue_redraw()
			return
		free_by_pet[pet] = i
	hint_pair.clear()
	queue_redraw()

func _process(_delta: float) -> void:
	if not hint_pair.is_empty() and Time.get_ticks_msec() > hint_until:
		hint_pair.clear()
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("d6ddbb"))
	# Understated painterly table mat, deliberately simple while UI is deferred.
	draw_circle(Vector2(150, 125), 165, Color("c4d6ab"))
	draw_circle(Vector2(1100, 660), 220, Color("c4d6ab"))
	draw_rect(Rect2(260, 75, 760, 664), Color("f4eaca"), true)
	draw_rect(Rect2(270, 85, 740, 644), Color("e8d7b5"), false, 5.0)
	for tile in tiles:
		if not tile["removed"]:
			_draw_tile(tile)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(50, 50), "山海麻将  ·  Shanghai Solitaire", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, FONT_COLOR)
	draw_string(font, Vector2(880, 50), "剩余 %d / 36" % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, FONT_COLOR)
	draw_string(font, Vector2(35, 774), "R 重新开始     Z 撤销     H 提示", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, FONT_COLOR)
	if won:
		draw_rect(Rect2(370, 320, 540, 150), Color("f9f0d9", 0.95), true)
		draw_string(font, Vector2(510, 382), "恭喜通关！", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, FONT_COLOR)
		draw_string(font, Vector2(500, 427), "按 R 再玩一局", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, FONT_COLOR)

func _draw_tile(tile: Dictionary) -> void:
	var pos: Vector2 = tile["pos"]
	var card_rect := Rect2(pos, Vector2(CARD_W, CARD_H))
	draw_texture_rect(tile_body, card_rect, false)
	var pet_texture: Texture2D = pet_textures[tile["pet"]]
	var bounds := Vector2(79, 111)
	var scale_factor: float = minf(bounds.x / pet_texture.get_width(), bounds.y / pet_texture.get_height())
	var rendered := Vector2(pet_texture.get_size()) * scale_factor
	var pet_pos := pos + Vector2((CARD_W - rendered.x) / 2.0, 11.0 + (bounds.y - rendered.y) / 2.0)
	draw_texture_rect(pet_texture, Rect2(pet_pos, rendered), false)
	if tile["id"] == selected_id:
		draw_rect(card_rect.grow(-4), Color("f2ba39"), false, 5.0)
	elif tile["id"] in hint_pair:
		draw_rect(card_rect.grow(-4), Color("59c5a3"), false, 5.0)
	elif not _is_free(tile["id"]):
		draw_rect(card_rect.grow(-3), Color(0.24, 0.27, 0.30, 0.18), true)
