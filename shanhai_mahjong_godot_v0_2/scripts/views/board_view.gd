class_name MahjongBoardView
extends Node2D
## Owns tile nodes and hit testing. Does not decide whether a match is valid.

signal tile_pressed(index: int)

@export var tile_size := Vector2(103, 151)
@export var column_row_step := Vector2(107, 140)
@export var layer_offset := Vector2(-5, -10)
@export var tile_scene: PackedScene = preload("res://scenes/tile_view.tscn")

var tiles: Array[MahjongTileState] = []
var rendered_tiles: Array[MahjongTileView] = []

func display_board(new_tiles: Array[MahjongTileState]) -> void:
	for view in rendered_tiles:
		view.queue_free()
	rendered_tiles.clear()
	tiles = new_tiles
	for tile in tiles:
		var view := tile_scene.instantiate() as MahjongTileView
		add_child(view)
		view.position = tile.position
		view.tile_size = tile_size
		view.pet_texture = PetCatalog.texture_for(tile.pet_id)
		rendered_tiles.append(view)
	refresh(-1, [])

func refresh(selected_id: int, hinted_ids: Array[int]) -> void:
	for i in range(tiles.size()):
		var view := rendered_tiles[i]
		view.visible = not tiles[i].removed
		if view.visible:
			view.update_state(BoardRules.is_free(tiles, i, tile_size), selected_id == i, i in hinted_ids)

func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.INF
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = to_local(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		point = to_local(event.position)
	else:
		return
	for i in range(tiles.size() - 1, -1, -1):
		if tiles[i].removed:
			continue
		if Rect2(tiles[i].position, tile_size).has_point(point):
			if BoardRules.is_free(tiles, i, tile_size):
				tile_pressed.emit(i)
			get_viewport().set_input_as_handled()
			return

