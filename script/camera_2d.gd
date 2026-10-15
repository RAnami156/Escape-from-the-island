extends Camera2D

const MIN_ZOOM: float = 2.0
const MAX_ZOOM: float = 5.0

@export var mouse_zoom_speed: float = 0.08
@export var trackpad_sensitivity: float = 0.25
@export var zoom_smoothness: float = 4.0

var target_zoom: float = MAX_ZOOM


func _ready() -> void:
	target_zoom = clampf(zoom.x, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * target_zoom


func _process(delta: float) -> void:
	var weight: float = 1.0 - exp(
		-maxf(zoom_smoothness, 0.01) * delta
	)

	var current_zoom: float = clampf(
		zoom.x, MIN_ZOOM, MAX_ZOOM
	)

	zoom = Vector2.ONE * lerpf(
		current_zoom, target_zoom, weight
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not event.pressed:
			return

		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				change_zoom(mouse_zoom_speed)
				get_viewport().set_input_as_handled()

			MOUSE_BUTTON_WHEEL_DOWN:
				change_zoom(-mouse_zoom_speed)
				get_viewport().set_input_as_handled()

	elif event is InputEventMagnifyGesture:
		change_zoom(
			(event.factor - 1.0) * trackpad_sensitivity
		)
		get_viewport().set_input_as_handled()


func change_zoom(amount: float) -> void:
	target_zoom = clampf(
		target_zoom + amount,
		MIN_ZOOM,
		MAX_ZOOM
	)
