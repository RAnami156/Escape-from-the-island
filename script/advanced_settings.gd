extends CanvasLayer


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tab"):
		_set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("esc"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(is_open: bool) -> void:
	visible = is_open
	get_tree().paused = is_open


func _exit_tree() -> void:
	if visible:
		get_tree().paused = false


func _on_tp_bong_pressed() -> void:
	Global.teleport_player_to(^"bong")


func _on_tp_panda_pressed() -> void:
	Global.teleport_player_to(^"panda")


func _on_tp_flycatcher_pressed() -> void:
	Global.teleport_player_to(^"flycather")


func _on_tp_ship_pressed() -> void:
	Global.teleport_player_to(^"ship", Vector2(-100, 0))


func _on_tp_baobab_pressed() -> void:
	Global.teleport_player_to(^"structures/Baobab100_byRavan", Vector2(0, 160))
