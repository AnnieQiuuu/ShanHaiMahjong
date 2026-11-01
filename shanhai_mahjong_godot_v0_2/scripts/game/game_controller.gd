extends Node2D
## Coordinates one game. No tile rendering or geometry calculations here.

@onready var board: MahjongBoardView = $MahjongBoard
@onready var counter_label: Label = $HUD/Counter
@onready var feedback_label: Label = $HUD/Feedback

var tiles: Array[MahjongTileState] = []
var selected_id := -1
var move_history: Array[Array] = []
var hinted_ids: Array[int] = []
var hint_expires_at := 0
var has_won := false

func _ready() -> void:
	board.tile_pressed.connect(_on_tile_pressed)
	new_game()

func new_game() -> void:
	selected_id = -1
	move_history.clear()
	hinted_ids.clear()
	has_won = false
	tiles = BoardGenerator.create_layout(board.tile_size, board.column_row_step, board.layer_offset)
	if not BoardGenerator.assign_solvable_pairs(tiles, board.tile_size, PetCatalog.IDS, Time.get_ticks_usec()):
		feedback_label.text = "生成牌局失败，请按 R 重试"
		push_error("Failed to generate solvable layout")
		return
	board.display_board(tiles)
	_update_status()

func _on_tile_pressed(index: int) -> void:
	if has_won:
		return
	if selected_id == index:
		selected_id = -1
	elif selected_id < 0:
		selected_id = index
	elif BoardRules.can_match(tiles, selected_id, index, board.tile_size):
		move_history.append([selected_id, index])
		tiles[selected_id].removed = true
		tiles[index].removed = true
		selected_id = -1
		hinted_ids.clear()
	else:
		selected_id = index
	board.refresh(selected_id, hinted_ids)
	_update_status()

func undo_last_match() -> void:
	if move_history.is_empty():
		return
	var pair: Array = move_history.pop_back()
	for index in pair:
		tiles[index].removed = false
	selected_id = -1
	hinted_ids.clear()
	has_won = false
	board.refresh(selected_id, hinted_ids)
	_update_status()

func show_hint() -> void:
	hinted_ids = BoardRules.first_available_pair(tiles, board.tile_size)
	hint_expires_at = Time.get_ticks_msec() + 2300
	board.refresh(selected_id, hinted_ids)
	_update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: new_game()
			KEY_Z: undo_last_match()
			KEY_H: show_hint()

func _process(_delta: float) -> void:
	if not hinted_ids.is_empty() and Time.get_ticks_msec() >= hint_expires_at:
		hinted_ids.clear()
		board.refresh(selected_id, hinted_ids)

func _update_status() -> void:
	var remaining := BoardRules.remaining_count(tiles)
	counter_label.text = "剩余 %d / 36" % remaining
	has_won = remaining == 0
	if has_won:
		feedback_label.text = "恭喜通关！按 R 再玩一局"
	elif BoardRules.first_available_pair(tiles, board.tile_size).is_empty():
		feedback_label.text = "暂无合法配对 · 按 Z 撤销或 R 重开"
	else:
		feedback_label.text = ""

