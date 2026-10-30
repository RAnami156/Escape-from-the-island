extends Control
## Sparse white pixel origami passing behind the loading interface.

const PAPER := Color(0.96, 0.96, 0.94)
const PIXEL := 3.0

var _time := 0.0
var _frames: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for wing_height: float in [0.0, 3.0, 6.0]:
		_frames.append(_make_crane(wing_height))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _frames.is_empty():
		return
	var unit := minf(size.x / 1920.0, size.y / 1080.0)
	var canvas := size / unit
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * unit)
	# Upper and lower flight paths leave both the title and loading text clear.
	_draw_flight(canvas, fposmod(_time + 1.6, 21.0), 1.0, 0.21, 0.88)
	_draw_flight(canvas, fposmod(_time + 12.5, 25.0), -1.0, 0.91, 0.45)


func _draw_flight(canvas: Vector2, age: float, direction: float, height: float, opacity: float) -> void:
	const DURATION := 15.0
	if age > DURATION:
		return
	var progress := age / DURATION
	var x := lerpf(-100.0, canvas.x + 100.0, progress)
	if direction < 0.0:
		x = canvas.x - x
	var y := canvas.y * height + sin(progress * TAU + height * 5.0) * 18.0
	var origin := (Vector2(x, y) / PIXEL).floor() * PIXEL
	var fade := smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.86, 1.0, progress))
	var pose: int = [0, 1, 2, 1][int(_time * 2.8) % 4]
	for cell: Dictionary in _frames[pose]:
		var position: Vector2 = cell.position
		position.x *= direction
		draw_rect(Rect2(origin + position * PIXEL, Vector2.ONE * PIXEL), Color(PAPER, opacity * fade * float(cell.shade)))
	# Two broken, square-ended dashes suggest a passing breath of wind.
	for index in 2:
		var length := 9.0 - index * 3.0
		var trail := origin + Vector2((-19.0 - index * 17.0) * direction, 27.0)
		if direction < 0.0:
			trail.x -= length
		draw_rect(Rect2(trail, Vector2(length, PIXEL)), Color(PAPER, opacity * fade * (0.26 - index * 0.10)))


func _make_crane(wing_height: float) -> Array:
	# Rasterize a small origami silhouette once. Its stepped edges are actual
	# square pixels, not antialiased curves or a particle emitter.
	var paper: Array = [
		{"shape": PackedVector2Array([Vector2(1, 7), Vector2(9, 8), Vector2(12, 10), Vector2(7, 10)]), "shade": 0.55},
		{"shape": PackedVector2Array([Vector2(10, 8), Vector2(5, 1 + wing_height), Vector2(14, 7)]), "shade": 0.65},
		{"shape": PackedVector2Array([Vector2(6, 7), Vector2(13, 7), Vector2(16, 9), Vector2(12, 11)]), "shade": 1.0},
		{"shape": PackedVector2Array([Vector2(13, 8), Vector2(17, 3), Vector2(21, 3), Vector2(23, 4), Vector2(19, 4), Vector2(16, 9)]), "shade": 1.0},
		{"shape": PackedVector2Array([Vector2(11, 9), Vector2(13, wing_height), Vector2(17, 7), Vector2(14, 10)]), "shade": 0.9},
	]
	var cells: Array = []
	for y in 12:
		for x in 24:
			var shade := 0.0
			for layer: Dictionary in paper:
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), layer.shape):
					shade = float(layer.shade)
			if shade > 0.0:
				cells.append({"position": Vector2(x, y), "shade": shade})
	return cells
