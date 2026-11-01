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

@export var earth_placeholder_color := Color("95633f"):
	set(value):
		earth_placeholder_color = value
		queue_redraw()

var is_earth_placeholder := false
@export var element_colors: Dictionary = {
	"fire": Color("c75935"), "water": Color("408dba"),
	"lightning": Color("9875bb"), "wind": Color("65976a"), "earth": Color("95633f")
}
@export var element_badge_area := Rect2(64, 96, 26, 25)
@export var liberated_color := Color("52b5ce")
var element := ""
var liberated := false
var pet_texture: Texture2D
@export_range(0.0, 0.5, 0.01) var removal_duration := 0.18
var rendered_removed := false
var removal_tween: Tween
var is_selected := false
var is_hint := false
var is_available := true
@export var shadow_offset := Vector2(5, 7)
@export var shadow_color := Color(0.22, 0.15, 0.10, 0.25)
@export var layer_badge_area := Rect2(13, 12, 24, 21)
@export var lock_badge_area := Rect2(15, 96, 25, 25)
@export var layer_badge_color := Color("775c42")
@export var blocker_color := Color("d68439")
@export var available_color := Color("42836a")
@export var locked_face_area := Rect2(11, 13, 78, 115)
var layer_number := 1
var is_hovered := false
var is_related_blocker := false
var release_glow := 0.0:
	set(value):
		release_glow = value
		queue_redraw()
var release_tween: Tween

func pulse_release() -> void:
	if release_tween != null:
		release_tween.kill()
	release_glow = 1.0
	release_tween = create_tween()
	release_tween.tween_property(self, "release_glow", 0.0, 1.0)

func update_removed(removed: bool) -> void:
	if removed == rendered_removed:
		return
	rendered_removed = removed
	if removal_tween != null:
		removal_tween.kill()
	if not removed:
		modulate.a = 1.0
		show()
	else:
		removal_tween = create_tween()
		removal_tween.tween_property(self, "modulate:a", 0.0, removal_duration)
		removal_tween.tween_callback(hide)

func update_state(available: bool, selected: bool, hinted: bool) -> void:
	is_available = available
	is_selected = selected
	is_hint = hinted
	queue_redraw()

func _draw() -> void:
	if tile_body == null:
		return
	var rect := Rect2(Vector2.ZERO, tile_size)
	draw_texture_rect(tile_body, Rect2(shadow_offset, tile_size), false, shadow_color)
	draw_texture_rect(tile_body, rect, false)
	if pet_texture != null:
		var ratio: float = minf(portrait_area.size.x / pet_texture.get_width(), portrait_area.size.y / pet_texture.get_height())
		var image_size := pet_texture.get_size() * ratio
		var image_pos := portrait_area.position + (portrait_area.size - image_size) * 0.5
		draw_texture_rect(pet_texture, Rect2(image_pos, image_size), false)
	elif is_earth_placeholder:
		# Temporary earth token; preserve the approved tile body and pet artwork.
		var center := portrait_area.get_center()
		draw_circle(center, minf(portrait_area.size.x, portrait_area.size.y) * 0.38, earth_placeholder_color)
		var font := ThemeDB.fallback_font
		var text_size := font.get_string_size("土", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		draw_string(font, center + Vector2(-text_size.x * 0.5, 8), "土", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("fff3d6"))
	if not element.is_empty():
		draw_rect(element_badge_area, element_colors.get(element, earth_placeholder_color))
		draw_string(ThemeDB.fallback_font, element_badge_area.position + Vector2(3, 20), PetCatalog.ELEMENT_NAMES.get(element, ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("fff3d6"))
	if not is_available:
		draw_style_box(_locked_style(), locked_face_area)
	# Flat UI overlays leave original textures untouched.
	draw_style_box(_badge_style(layer_badge_color), layer_badge_area)
	draw_string(ThemeDB.fallback_font, layer_badge_area.position + Vector2(6, 16), str(layer_number), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("fff3d6"))
	var badge_center := lock_badge_area.get_center()
	if not is_available:
		draw_style_box(_badge_style(layer_badge_color), lock_badge_area)
		draw_arc(badge_center + Vector2(0, -3), 5, PI, TAU, 12, Color("fff3d6"), 2, true)
		draw_rect(Rect2(badge_center + Vector2(-7, -2), Vector2(14, 11)), Color("fff3d6"))
		draw_circle(badge_center + Vector2(0, 3), 1.7, layer_badge_color)
	else:
		draw_circle(badge_center, 9, available_color)
		draw_polyline(PackedVector2Array([badge_center + Vector2(-5, 0), badge_center + Vector2(-1, 4), badge_center + Vector2(5, -4)]), Color("fff3d6"), 2, true)
	if is_related_blocker:
		draw_rect(rect.grow(-6), blocker_color, false, 4.0)
	if release_glow > 0:
		draw_rect(rect.grow(-6), Color(liberated_color, release_glow), false, 5)
	if is_hovered:
		draw_rect(rect.grow(-3), Color("bd9c6c"), false, 2.0)
	if liberated:
		draw_rect(rect.grow(-7), liberated_color, false, 3.0)
	if is_selected:
		draw_rect(rect.grow(-4), selection_color, false, 5.0)
	elif is_hint:
		draw_rect(rect.grow(-4), hint_color, false, 5.0)

func _badge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style

func _locked_style() -> StyleBoxFlat:
	var style := _badge_style(Color(0.30, 0.23, 0.17, blocked_overlay_opacity))
	return style

