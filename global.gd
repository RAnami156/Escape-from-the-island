extends Node

var language: String = "ru"

var player_can_move: bool = true

var player: CharacterBody2D = null
var _teleport_in_progress: bool = false

# World coordinates: assigning this property teleports the active player.
var player_position: Vector2 = Vector2.ZERO:
	get:
		if is_instance_valid(player):
			return player.global_position
		return player_position
	set(value):
		player_position = value
		if is_instance_valid(player):
			player.global_position = value
			player.velocity = Vector2.ZERO

#BONG
var bong_respect: int = 30
var bong_friendship: int = 35
var bong_irritation: int = 10
var bong_deal: int = 30

var whiskey: bool = false
var helm: bool = false

#flycatcher

var flycatcher_respect: int = -40
var flycatcher_friendship: int = -30
var flycatcher_irritation: int = 100
var flycatcher_deal: int = -67

var fly: bool = false
var parus: bool = false

#pandа 

var panda_respect: int = 10
var panda_friendship: int = 10
var panda_irritation: int = 30
var panda_deal: int = 0

var book: bool = false
var bamboo_boards: bool = false


# Runs in the autoload so the request survives the menu being freed.
func teleport_player_to(target_path: NodePath, offset: Vector2 = Vector2(0, 80)) -> void:
	if _teleport_in_progress:
		return
	_teleport_in_progress = true

	if not is_instance_valid(player):
		var error := get_tree().change_scene_to_file("res://scene/main.tscn")
		if error != OK:
			push_error("Could not load the island for teleport: %s" % error)
			_teleport_in_progress = false
			return
		await get_tree().scene_changed

	var target := get_tree().current_scene.get_node_or_null(target_path) as Node2D
	if is_instance_valid(player) and target != null:
		player_can_move = true
		player_position = target.global_position + offset
	else:
		push_error("Teleport target or player not found: %s" % target_path)

	_teleport_in_progress = false
