class_name MahjongTileState
extends RefCounted
## Mutable game state for a tile. Rendering nodes are deliberately separate.

var id: int
var layer: int
var column: int
var row: int
var position: Vector2
var pet_id: String = ""
var removed: bool = false
var liberated: bool = false

func _init(new_id: int, new_layer: int, new_column: int, new_row: int, new_position: Vector2) -> void:
	id = new_id
	layer = new_layer
	column = new_column
	row = new_row
	position = new_position

