class_name MahjongBoardView
extends Node2D
## Owns tile nodes and hit testing. Does not decide whether a match is valid.

signal tile_pressed(index: int)
signal tile_inspected(index: int, details: Dictionary)

@export var tile_size := Vector2(103, 151)
@export var column_row_step := Vector2(107, 140)
@export var layer_offset := Vector2(-5, -10)
@export var tile_scene: PackedScene = preload("res://scenes/tile_view.tscn")
@export var board_area := Rect2(280, 100, 720, 620)

var tiles: Array[MahjongTileState] = []
var rendered_tiles: Array[MahjongTileView] = []
var hovered_id := -1
var last_mouse_position := Vector2.INF
@export_range(0.15, 1.5, 0.05) var effect_duration := 0.65
@export var effect_scene: PackedScene = preload("res://scenes/element_feedback.tscn")
@export var wind_slide_offset := Vector2(30, -16)
var input_enabled := true
var effect_layer: ElementFeedback

func show_element_feedback(element: String, sources: Array, target_ids: Array) -> void:
	if effect_layer == null:
		effect_layer = effect_scene.instantiate() as ElementFeedback
		effect_layer.z_index = 2000
		add_child(effect_layer)
	var origin := Vector2.ZERO
	for id in sources:
		origin += tiles[id].position + tile_size * 0.5
	if not sources.is_empty():
		origin /= sources.size()
	var rects: Array[Rect2] = []
	for id in target_ids:
		rects.append(Rect2(tiles[id].position, tile_size))
	effect_layer.duration = effect_duration
	effect_layer.start(element, origin, rects)
	if element == "wind":
		for id in target_ids:
			var view := rendered_tiles[id]
			var movement := view.create_tween()
			movement.tween_interval(effect_duration * effect_layer.preview_fraction)
			movement.tween_property(view, "position", view.position + wind_slide_offset, effect_duration * (1 - effect_layer.preview_fraction))

func clear_feedback() -> void:
	if effect_layer != null:
		effect_layer.hide()

func flash_released(ids: Array) -> void:
	for id in ids:
		if id >= 0 and id < rendered_tiles.size() and not tiles[id].removed:
			rendered_tiles[id].pulse_release()

func display_board(new_tiles: Array[MahjongTileState]) -> void:
	for view in rendered_tiles:
		view.queue_free()
	rendered_tiles.clear()
	tiles = new_tiles
	hovered_id = -1
	last_mouse_position = Vector2.INF
	_fit_board()
	for tile in tiles:
		var view := tile_scene.instantiate() as MahjongTileView
		add_child(view)
		view.position = tile.position
		view.tile_size = tile_size
		view.layer_number = tile.layer + 1
		view.is_earth_placeholder = tile.pet_id == PetCatalog.EARTH_PLACEHOLDER_ID
		view.pet_texture = PetCatalog.texture_for(tile.pet_id)
		rendered_tiles.append(view)
	refresh(-1, [])

func _fit_board() -> void:
	if tiles.is_empty():
		return
	var bounds := Rect2(tiles[0].position, tile_size)
	for tile in tiles:
		bounds = bounds.merge(Rect2(tile.position, tile_size))
	var factor := minf(1.0, minf(board_area.size.x / bounds.size.x, board_area.size.y / bounds.size.y))
	scale = Vector2.ONE * factor
	position = board_area.position + (board_area.size - bounds.size * factor) * 0.5 - bounds.position * factor

func refresh(selected_id: int, hinted_ids: Array[int]) -> void:
	for i in range(tiles.size()):
		var view := rendered_tiles[i]
		view.update_removed(tiles[i].removed)
		if not tiles[i].removed:
			view.position = tiles[i].position
			view.is_earth_placeholder = tiles[i].pet_id == PetCatalog.EARTH_PLACEHOLDER_ID
			view.pet_texture = PetCatalog.texture_for(tiles[i].pet_id)
			view.element = PetCatalog.element_for(tiles[i].pet_id)
			view.liberated = tiles[i].liberated
			view.z_index = 1000 + tiles[i].layer if tiles[i].liberated else tiles[i].layer
			view.update_state(BoardRules.is_free(tiles, i, tile_size), selected_id == i, i in hinted_ids)
	if hovered_id >= 0 and tiles[hovered_id].removed:
		hovered_id = -1
	_update_inspection()

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or not input_enabled:
		return
	var mouse := get_global_mouse_position()
	if mouse != last_mouse_position:
		last_mouse_position = mouse
		var index := tile_at_point(to_local(mouse))
		if index != hovered_id:
			hovered_id = index
			_update_inspection()

func tile_at_point(point: Vector2) -> int:
	var result := -1
	var highest := -1
	for i in range(tiles.size()):
		if tiles[i].removed or not Rect2(tiles[i].position, tile_size).has_point(point):
			continue
		var order := 1000 + tiles[i].layer if tiles[i].liberated else tiles[i].layer
		if order >= highest:
			highest = order
			result = i
	return result

func _update_inspection() -> void:
	var details: Dictionary = {}
	var blockers: Array = []
	if hovered_id >= 0:
		details = BoardRules.blocking_details(tiles, hovered_id, tile_size)
		blockers.append_array(details.above)
		if details.sides_locked:
			blockers.append_array(details.left)
			blockers.append_array(details.right)
	for i in range(rendered_tiles.size()):
		rendered_tiles[i].is_hovered = i == hovered_id
		rendered_tiles[i].is_related_blocker = i in blockers
		rendered_tiles[i].queue_redraw()
	tile_inspected.emit(hovered_id, details)

func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.INF
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = to_local(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		point = to_local(event.position)
	else:
		return
	if not visible or not input_enabled:
		return
	var index := tile_at_point(point)
	if index >= 0:
		hovered_id = index
		_update_inspection()
		if BoardRules.is_free(tiles, index, tile_size):
			tile_pressed.emit(index)
		get_viewport().set_input_as_handled()

