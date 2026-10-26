extends SceneTree

# Requires a running local Ollama with qwen3:8b. No persistent player memory is written.
var failures: int = 0
var replies: int = 0
var latest_reply: String = ""
var _language: String = "ru"


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _on_reply(reply: String, metrics: Dictionary) -> void:
	replies += 1
	latest_reply = reply
	print("MICHAEL_REPLY language=", _language, " first_token_ms=", metrics.get("first_token_ms"), " total_ms=", metrics.get("response_ms"), " reflection_words=", metrics.get("reflection_words"), " text=", reply)
	_check(int(metrics.get("reflection_words", 0)) > 0, "Every reply must include brief preparation")
	_check(not reply.begins_with("{") and not reply.contains('"intent"'), "Preparation and JSON must not appear as dialogue")
	if _language == "cz":
		var cyrillic := RegEx.new()
		cyrillic.compile("[А-Яа-яЁё]")
		_check(cyrillic.search(reply) == null, "Czech dialogue must not switch to Russian")


func _wait_reply(expected: int) -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while replies < expected and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if replies < expected:
		_check(false, "Ollama reply timed out")
		return false
	return true


func _send(guide: Node, text: String) -> bool:
	var expected := replies + 1
	guide.send_message(text)
	return await _wait_reply(expected)


func _run() -> void:
	var global: Node = root.get_node("Global")
	for language: String in ["ru", "cz"]:
		_language = language
		change_scene_to_file("res://scene/menu.tscn")
		await scene_changed
		var option: OptionButton = current_scene.get_node("OptionButton")
		var selected := 1 if language == "cz" else 0
		option.select(selected)
		option.item_selected.emit(selected)
		_check(global.language == language, "Menu must select Michael's dialogue language")
		var main: Node = load("res://scene/main.tscn").instantiate()
		var guide: Node = main.get_node("guide_npc")
		guide.reply_finished.connect(_on_reply)
		current_scene.queue_free()
		root.add_child(main)
		current_scene = main
		if not await _wait_reply(replies + 1):
			quit(1)
			return
		var czech := language == "cz"
		_check(latest_reply.to_lower().contains("letadl" if czech else "самол"), "Opening must mention the shared plane crash")
		_check(latest_reply.to_lower().contains("michael" if czech else "майкл"), "Michael must introduce himself")
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/_guide_preview_" + language + ".png")
		if not await _send(guide, "Jmenuju se Řehoř" if czech else "Меня зовут Роман"):
			quit(1)
			return
		_check(guide.player_name == ("Řehoř" if czech else "Роман"), "Name must be stored")
		if not await _send(guide, "Mám strach, že se odsud nikdy nedostaneme." if czech else "Мне страшно, вдруг мы так и не выберемся отсюда."):
			quit(1)
			return
		_check(latest_reply.length() >= 20 and not latest_reply.to_lower().contains("nepamatuj" if czech else "не помню"), "Sharing fear must receive a conversational response instead of an unrelated memory refusal")
		if not await _send(guide, "Nejvíc se bojím zůstat tady sám." if czech else "Больше всего боюсь оставаться здесь одному."):
			quit(1)
			return
		var topic_words := ["sám", "sama", "samot", "spolu", "tebou", "tebe", "tady", "u mě", "neopust", "один", "одном", "одному", "вместе", "рядом", "тобой", "одиноч"]
		var follows_topic: bool = false
		for word: String in topic_words:
			follows_topic = follows_topic or latest_reply.to_lower().contains(word)
		_check(follows_topic or (latest_reply.contains("?") and latest_reply.length() > 30), "Michael should acknowledge loneliness or continue with a meaningful question")
		if not await _send(guide, "Jak se jmenuju?" if czech else "Как меня зовут?"):
			quit(1)
			return
		_check(latest_reply.to_lower().contains("řehoř" if czech else "роман"), "Michael must recall the player's name")
		if not await _send(guide, "A jak se jmenuješ ty?" if czech else "А тебя как зовут?"):
			quit(1)
			return
		_check(latest_reply.to_lower().contains("michael" if czech else "майкл"), "Michael must know his own name")
		if not await _send(guide, "Čím jsi pracoval před havárií a kde ses narodil?" if czech else "Кем ты работал до крушения и где родился?"):
			quit(1)
			return
		var normalized := latest_reply.to_lower()
		_check(normalized.contains("nepamatuj" if czech else "не помню") or normalized.contains("nevím" if czech else "не могу") or normalized.contains("zapomněl" if czech else "забыл"), "Unknown backstory must remain unknown")
		_check(not normalized.contains("afri" if czech else "африк"), "Michael must not invent his origin")
		if not await _send(guide, "Jakou máš barvu pleti?" if czech else "Какого цвета у тебя кожа?"):
			quit(1)
			return
		normalized = latest_reply.to_lower().replace("ё", "е")
		_check(normalized.contains("tmav" if czech else "темн"), "Michael must know his appearance")
		if not await _send(guide, "Připomeň mi, jak se jmenuju." if czech else "Напомни, как меня зовут?"):
			quit(1)
			return
		_check(latest_reply.to_lower().contains("řehoř" if czech else "роман"), "Player name must survive the history window")
		_check(guide.conversation_history.size() <= guide.MAX_HISTORY_MESSAGES, "Conversation context must stay bounded")
	print("GUIDE_LIVE_TEST failures=", failures)
	quit(0 if failures == 0 else 1)
