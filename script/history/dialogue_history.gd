class_name DialogueHistory
extends RefCounted


var messages: Array[Dictionary] = []
var display_history: Array[Dictionary] = []


func add_user(text: String) -> void:

	messages.append({
		"role": "user",
		"content": text
	})


func add_assistant(text: String) -> void:

	messages.append({
		"role": "assistant",
		"content": text
	})


func trim(max_messages: int) -> void:

	while messages.size() > max_messages:
		messages.pop_front()


func get_messages() -> Array[Dictionary]:

	return messages


func add_dialogue(
	player: String,
	npc: String
) -> void:

	display_history.append({
		"player": player,
		"npc": npc
	})
