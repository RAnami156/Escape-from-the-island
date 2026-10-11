extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var transitioning: bool = false


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("new_animation")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("esc"):
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_SPACE:
				get_viewport().set_input_as_handled()
				_go_to_game()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"new_animation":
		_go_to_game()


func _go_to_game() -> void:
	if transitioning:
		return

	transitioning = true
	animation_player.stop()

	get_tree().change_scene_to_file.call_deferred(
		"res://scene/main.tscn"
	)
