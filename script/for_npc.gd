extends Node2D


func _ready() -> void:
	# Layer 4 is reserved for Michael. Players and other NPCs do not trigger remarks.
	for child: Node in get_children():
		if child is Area2D:
			child.collision_layer = 0
			child.collision_mask = 8
			child.monitoring = true


func _entered(zone: String, body: Node2D) -> void:
	if body.is_in_group("guide_companion"):
		body.enter_observation_zone(zone)


func _exited(zone: String, body: Node2D) -> void:
	if body.is_in_group("guide_companion"):
		body.exit_observation_zone(zone)


func _on_bong_body_entered(body: Node2D) -> void:
	_entered("bong", body)


func _on_bong_body_exited(body: Node2D) -> void:
	_exited("bong", body)


func _on_flycatcher_body_entered(body: Node2D) -> void:
	_entered("flycatcher", body)


func _on_flycatcher_body_exited(body: Node2D) -> void:
	_exited("flycatcher", body)


func _on_panda_body_entered(body: Node2D) -> void:
	_entered("panda", body)


func _on_panda_body_exited(body: Node2D) -> void:
	_exited("panda", body)


func _on_baobab_body_entered(body: Node2D) -> void:
	_entered("baobab", body)


func _on_baobab_body_exited(body: Node2D) -> void:
	_exited("baobab", body)


func _on_beach_body_entered(body: Node2D) -> void:
	_entered("beach", body)


func _on_beach_body_exited(body: Node2D) -> void:
	_exited("beach", body)


func _on_paths_body_entered(body: Node2D) -> void:
	_entered("paths", body)


func _on_paths_body_exited(body: Node2D) -> void:
	_exited("paths", body)


func _on_ship_body_entered(body: Node2D) -> void:
	_entered("ship", body)


func _on_ship_body_exited(body: Node2D) -> void:
	_exited("ship", body)
