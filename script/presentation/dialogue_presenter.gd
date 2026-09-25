class_name DialoguePresenter
extends RefCounted


var label: Label
var animated_sprite: AnimatedSprite2D

var typing_speed := 0.03
var max_characters := 180
var characters_per_line := 43


func setup(
	target_label: Label,
	sprite: AnimatedSprite2D,
	speed: float,
	max_length: int,
	line_length: int
) -> void:

	label = target_label
	animated_sprite = sprite

	typing_speed = speed
	max_characters = max_length
	characters_per_line = line_length


func prepare(value: String) -> String:

	value = value.strip_edges()

	value = value.replace("**", "")
	value = value.replace("__", "")

	value = value.replace("\r\n", "\n")
	value = value.replace("\r", "\n")
	value = value.replace("\n", " ")

	while value.contains("  "):
		value = value.replace("  ", " ")

	if value.length() > max_characters:

		value = value.substr(
			0,
			max_characters
		)

		var last_space := value.rfind(" ")

		if last_space > 20:
			value = value.substr(
				0,
				last_space
			)

		value = value.strip_edges()
		value += "…"

	return wrap_text(value)


func wrap_text(value: String) -> String:

	var words := value.split(
		" ",
		false
	)

	var result := ""
	var line := ""

	for word in words:

		if line.is_empty():

			line = word

		elif line.length() + 1 + word.length() <= characters_per_line:

			line += " " + word

		else:

			if not result.is_empty():
				result += "\n"

			result += line

			line = word

	if not line.is_empty():

		if not result.is_empty():
			result += "\n"

		result += line

	return result


func type_text(value: String) -> void:

	animated_sprite.play("Talking")

	label.text = ""

	for character in value:

		label.text += character

		await label.get_tree().create_timer(
			typing_speed
		).timeout

	animated_sprite.play("Idle")
