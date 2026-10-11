extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var final_animation: StringName = &"new_animation"
var returning_to_menu: bool = false


func _ready() -> void:
	# Во втором финале нужная анимация называется иначе.
	if scene_file_path == "res://scene/final2_leave.tscn":
		final_animation = &"new_animation_2"

	animation_player.animation_finished.connect(_on_animation_finished)

	# Применяем начальное состояние всех объектов.
	if animation_player.has_animation(&"RESET"):
		animation_player.play(&"RESET")
		animation_player.advance(0.0)

	animation_player.play(final_animation)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != final_animation:
		return

	if returning_to_menu:
		return

	returning_to_menu = true
	Global.player_can_move = true

	get_tree().change_scene_to_file.call_deferred(
		"res://scene/menu.tscn"
	)
