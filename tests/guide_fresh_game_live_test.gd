extends SceneTree

var failures: int = 0
var count: int = 0
var latest: String = ""

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _on_reply(text: String, _metrics: Dictionary) -> void:
	count += 1
	latest = text
	print("FRESH_GAME_REPLY ", root.get_node("Global").language, " ", text)

func _wait_for(expected: int) -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while count < expected and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_check(count >= expected, "Ollama reply must complete")
	return count >= expected

func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player: Node = load("res://scene/player.tscn").instantiate()
	scene.add_child(player)
	var packed: PackedScene = load("res://scene/guide_npc.tscn")
	for language: String in ["ru", "cz"]:
		root.get_node("Global").language = language
		var previous: Node = packed.instantiate()
		previous.auto_introduction = false
		scene.add_child(previous)
		previous._remember_player_name("Jmenuju se Lenka" if language == "cz" else "Меня зовут Лена")
		previous.conversation_history.append({"role": "assistant", "content": "Ahoj, Lenko." if language == "cz" else "Привет, Лена, ты в порядке?"})
		previous.queue_free()
		await process_frame
		var guide: Node = packed.instantiate()
		guide.auto_introduction = false
		scene.add_child(guide)
		guide.reply_finished.connect(_on_reply)
		_check(guide.player_name.is_empty() and guide.conversation_history.is_empty(), "A new game must be a fresh meeting")
		var expected := count + 1
		guide._start_request("", true)
		if not await _wait_for(expected):
			quit(1)
			return
		_check(not latest.to_lower().contains("лен") and not latest.to_lower().contains("lenk"), "Old names must not return in a fresh greeting")
		_check(latest.to_lower().contains("letadl" if language == "cz" else "самол"), "Fresh greeting must be the first meeting")
		guide.enter_observation_zone("ship")
		expected = count + 1
		guide.send_message("Co si myslíš o té lodi?" if language == "cz" else "Что думаешь об этом корабле?")
		if not await _wait_for(expected):
			quit(1)
			return
		var normalized := latest.to_lower()
		_check(normalized.contains("oprav" if language == "cz" else "почин") or normalized.contains("poškoz" if language == "cz" else "ремонт") or normalized.contains("rozbit" if language == "cz" else "разбит"), "Dialogue must understand the damaged ship and the repair inference")
		expected = count + 1
		guide.send_message("Jmenuju se Řehoř" if language == "cz" else "Меня зовут Роман")
		if not await _wait_for(expected):
			quit(1)
			return
		_check(guide.player_name == ("Řehoř" if language == "cz" else "Роман"), "Name must still be remembered within the current game")
		guide.queue_free()
		await process_frame
	print("GUIDE_FRESH_GAME_LIVE_TEST failures=", failures)
	quit(0 if failures == 0 else 1)
