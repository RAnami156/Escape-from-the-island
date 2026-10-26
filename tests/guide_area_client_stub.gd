extends "res://script/guide_ollama_client.gd"

var requests: Array[Dictionary] = []


func send(_host: String, _port: int, payload: Dictionary) -> void:
	busy = true
	requests.append(payload)


func finish(reply: String) -> void:
	busy = false
	completed.emit(reply, {"reflection_words": 4, "response_ms": 1})
