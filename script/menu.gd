extends Node2D

@onready var language_option: OptionButton = $OptionButton


func _ready() -> void:
	for index in language_option.item_count:
		if language_option.get_item_text(index) == Global.language:
			language_option.select(index)
			break


func _on_option_button_item_selected(index: int) -> void:
	Global.language = language_option.get_item_text(index)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		get_viewport().set_input_as_handled()
		get_tree().quit()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")
