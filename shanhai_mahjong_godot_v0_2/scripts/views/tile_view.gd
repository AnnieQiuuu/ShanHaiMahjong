@tool
class_name MahjongTileView
extends Node2D
## One tile's presentation only. Edit these @export values in Godot Inspector.

@export var tile_body: Texture2D = preload("res://assets/tile/handpainted_tile_v2.png"):
	set(value):
		tile_body = value
		queue_redraw()
@export var tile_size := Vector2(103, 151):
	set(value):
		tile_size = value
		queue_redraw()
@export var portrait_area := Rect2(12, 11, 79, 111):
	set(value):
		portrait_area = value
		queue_redraw()
@export var selection_color := Color("f2ba39"):
	set(value):
		selection_color = value
		queue_redraw()
@export var hint_color := Color("59c5a3"):
	set(value):
		hint_color = value
		queue_redraw()
@export_range(0.0, 0.6, 0.01) var blocked_overlay_opacity := 0.18:
	set(value):
		blocked_overlay_opacity = value
		queue_redraw()

var pet_texture: Texture2D
var is_selected := false
var is_hint := false
var is_available := true

func update_state(available: bool, selected: bool, hinted: bool) -> void:
	is_available = available
	is_selected = selected
	is_hint = hinted
	queue_redraw()

func _draw() -> void:
	if tile_body == null:
		return
	var rect := Rect2(Vector2.ZERO, tile_size)
	draw_texture_rect(tile_body, rect, false)
	if pet_texture != null:
		var ratio: float = minf(portrait_area.size.x / pet_texture.get_width(), portrait_area.size.y / pet_texture.get_height())
		var image_size := pet_texture.get_size() * ratio
		var image_pos := portrait_area.position + (portrait_area.size - image_size) * 0.5
		draw_texture_rect(pet_texture, Rect2(image_pos, image_size), false)
	if is_selected:
		draw_rect(rect.grow(-4), selection_color, false, 5.0)
	elif is_hint:
		draw_rect(rect.grow(-4), hint_color, false, 5.0)
	elif not is_available:
		draw_rect(rect.grow(-3), Color(0.24, 0.27, 0.3, blocked_overlay_opacity), true)

