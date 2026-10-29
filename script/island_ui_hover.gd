extends Button
## A short visual transition; button input and signals remain native.

var _surface: StyleBoxFlat
var _rest: StyleBoxFlat
var _over: StyleBoxFlat
var _tween: Tween
var _pointer_inside := false


func _ready() -> void:
	_rest = get_theme_stylebox("normal") as StyleBoxFlat
	_over = get_theme_stylebox("hover") as StyleBoxFlat
	if _rest == null or _over == null:
		return
	_surface = _rest.duplicate() as StyleBoxFlat
	add_theme_stylebox_override("normal", _surface)
	add_theme_stylebox_override("hover", _surface)
	mouse_entered.connect(func() -> void: _pointer_inside = true; _refresh())
	mouse_exited.connect(func() -> void: _pointer_inside = false; _refresh())
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)


func _refresh() -> void:
	if disabled or not is_inside_tree():
		return
	if _tween != null:
		_tween.kill()
	var target := _over if _pointer_inside or has_focus() else _rest
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_surface, "bg_color", target.bg_color, 0.14)
	_tween.tween_property(_surface, "border_color", target.border_color, 0.14)
