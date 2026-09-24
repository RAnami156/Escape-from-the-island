extends LineEdit

var initial_width: float
var center_x: float


func _ready() -> void:
	initial_width = size.x
	center_x = position.x + size.x / 2.0

	text_changed.connect(_on_text_changed)
	_on_text_changed(text)


func _on_text_changed(new_text: String) -> void:
	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")

	var text_width: float = font.get_string_size(
		new_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	).x

	var new_width: float = max(initial_width, text_width + 30.0)

	size.x = new_width
	position.x = center_x - new_width / 2.0
