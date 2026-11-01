extends Control
## A tiny pixel arrow; it does not depend on the font containing arrow glyphs.

var direction := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var pixels := [Rect2(10, 5, 4, 3), Rect2(7, 8, 10, 3), Rect2(4, 11, 16, 3), Rect2(10, 14, 4, 9)]
	for pixel: Rect2 in pixels:
		if direction < 0:
			pixel.position.y = 28.0 - pixel.end.y
		draw_rect(pixel, Color.WHITE)
