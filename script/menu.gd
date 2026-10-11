extends Node2D


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("esc"):
		get_tree().quit()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/start.tscn")
