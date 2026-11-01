class_name ElementFeedback
extends Node2D
## Short procedural, flat feedback; never mutates the board model.

@export var duration := 0.65
@export_range(0.1, 0.8, 0.05) var preview_fraction := 0.4
@export var colors := {"fire": Color("d16a3c"), "wind": Color("619b77"), "water": Color("58aabc"), "lightning": Color("aa82ca"), "earth": Color("a47b4e")}
var element := ""
var origin := Vector2.ZERO
var targets: Array[Rect2] = []
var elapsed := 0.0

func start(kind: String, source: Vector2, rects: Array[Rect2]) -> void:
	element = kind
	origin = source
	targets = rects
	elapsed = 0.0
	show()
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	if elapsed >= duration:
		hide()
	queue_redraw()

func _draw() -> void:
	if element.is_empty():
		return
	var progress := clampf(elapsed / duration, 0, 1)
	var color: Color = colors.get(element, Color.WHITE)
	for rect in targets:
		draw_rect(rect.grow(-5), Color(color, 0.16), true)
		draw_rect(rect.grow(-5), Color(color, 0.9), false, 4)
	if progress < preview_fraction:
		return
	var t := (progress - preview_fraction) / (1 - preview_fraction)
	var centers: Array[Vector2] = []
	for rect in targets:
		centers.append(rect.get_center())
	if centers.is_empty():
		centers.append(origin)
	for center in centers:
		match element:
			"fire":
				for i in range(12):
					var direction := Vector2.from_angle(i * TAU / 12)
					draw_line(center + direction * (12 + t * 25), center + direction * (25 + t * 65), Color(color, 1 - t), 4, true)
			"wind":
				for i in range(3):
					draw_arc(center + Vector2(t * 25, i * 12 - 12), 25 + t * 40, PI * 0.15, PI * 1.55, 28, Color(color, 1 - t), 3, true)
			"water":
				for i in range(3):
					draw_arc(center, 15 + t * 55 + i * 12, 0, TAU, 32, Color(color, (1 - t) * 0.8), 3, true)
			"lightning":
				var points := PackedVector2Array([origin])
				for i in range(1, 6):
					points.append(origin.lerp(center, i / 6.0) + Vector2(0, (1 if i % 2 == 0 else -1) * 10))
				points.append(center)
				draw_polyline(points, Color(color, 1 - t), 5, true)
			"earth":
				draw_arc(center, 30 + t * 35, 0, TAU, 6, Color(color, 1 - t), 5, true)
				draw_string(ThemeDB.fallback_font, center + Vector2(-24, 7), "护佑", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(color, 1 - t))
