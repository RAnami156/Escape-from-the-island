extends Camera2D

# =========================
# НАСТРОЙКИ ЗУМА
# =========================

@export var min_zoom: float = 0.15
@export var max_zoom: float = 5.0

# Скорость колесика мыши
@export var mouse_zoom_speed: float = 0.08

# Чувствительность Trackpad
# Чем меньше значение — тем больше нужно двигать пальцами
@export var trackpad_sensitivity: float = 0.25

# Плавность зума
@export var zoom_smoothness: float = 4.0


var target_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	target_zoom = zoom


func _process(delta: float) -> void:
	# Плавное приближение к целевому зуму
	var smooth_amount: float = 1.0 - exp(-zoom_smoothness * delta)

	zoom = zoom.lerp(
		target_zoom,
		smooth_amount
	)


func _unhandled_input(event: InputEvent) -> void:

	# =========================
	# КОЛЕСО МЫШИ
	# =========================

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_zoom(mouse_zoom_speed)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_zoom(-mouse_zoom_speed)


	# =========================
	# MAC TRACKPAD
	# ДВА ПАЛЬЦА
	# =========================

	elif event is InputEventMagnifyGesture:

		var amount: float = (event.factor - 1.0) * trackpad_sensitivity

		change_zoom(amount)


func change_zoom(amount: float) -> void:

	var new_zoom_value: float = target_zoom.x + amount

	# Ограничение зума
	new_zoom_value = clamp(
		new_zoom_value,
		min_zoom,
		max_zoom
	)

	target_zoom = Vector2(
		new_zoom_value,
		new_zoom_value
	)
