extends SceneTree

# Godot --headless --path . --script res://tests/guide_areas_live_test.gd
# Zone reactions are local. Follow-up conversations require local Ollama.
const AreaContext = preload("res://script/guide_area_context.gd")
const TOPICS: Dictionary = {
	"bong": ["конг", "орангутан", "kong", "orangutan", "bong"],
	"flycatcher": ["мухолов", "растен", "ловуш", "mucholap", "rostlin", "past"],
	"panda": ["панд", "pand"],
	"baobab": ["дерев", "ствол", "баобаб", "baobab", "kmen", "strom"],
	"beach": ["пляж", "пес", "берег", "мор", "pláž", "pís", "břeh", "moř"],
	"paths": ["троп", "дорож", "pěšin", "cest", "stezk"],
	"ship": ["лод", "кораб", "loď", "lod", "člun"],
}
var failures: int = 0
var count: int = 0
var chat_count: int = 0
var latest_chat: String = ""
var guide: Node
var language: String = "ru"


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _frames() -> void:
	for _index in 4:
		await physics_frame
	await process_frame


func _on_observation(zone: String, text: String) -> void:
	count += 1
	print("AREA_REPLY ", language, " ", zone, " ms=", guide.last_metrics.get("response_ms"), " text=", text)
	_check(text.length() <= 180 and not text.begins_with("{"), "Area comment must be short spoken text")
	_check(AreaContext.lines(zone, language == "cz").has(text), "Only reviewed, grounded formulations may be spoken")
	var normalized := text.to_lower()
	var on_topic: bool = false
	for word: String in TOPICS[zone]:
		on_topic = on_topic or normalized.contains(word)
	_check(on_topic, "Observation must concern the entered area: " + zone)
	for phrase: String in ["тебе нужно", "нужно собрать", "нажми", "собери", "принеси", "musíš", "stiskni", "přines", "oprav loď"]:
		_check(not normalized.contains(phrase), "Observation must not become a quest instruction")
	if language == "cz":
		var cyrillic := RegEx.new()
		cyrillic.compile("[А-Яа-яЁё]")
		_check(cyrillic.search(text) == null, "Czech area comments must stay Czech")


func _on_chat(text: String, _metrics: Dictionary) -> void:
	chat_count += 1
	latest_chat = text
	print("AREA_CHAT ", language, " text=", text)


func _wait_for(expected: int, chat: bool = false) -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while (chat_count if chat else count) < expected and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if (chat_count if chat else count) < expected:
		_check(false, "Ollama did not complete the area request")
		return false
	return true


func _run() -> void:
	for locale: String in ["ru", "cz"]:
		language = locale
		root.get_node("Global").language = locale
		root.get_node("Global").player_can_move = true
		var authored: Node2D = load("res://scene/main.tscn").instantiate()
		var zones: Node2D = authored.get_node("for_npc").duplicate()
		var scene := Node2D.new()
		scene.transform = authored.transform
		authored.free()
		root.add_child(scene)
		current_scene = scene
		var player: Node2D = load("res://scene/player.tscn").instantiate()
		player.position = Vector2(-2000, -2000)
		scene.add_child(player)
		guide = load("res://scene/guide_npc.tscn").instantiate()
		guide.auto_introduction = false
		guide.position = Vector2(-2000, -2000)
		scene.add_child(guide)
		guide.set_process(false)
		guide.set_physics_process(false)
		guide._has_met_player = true
		guide.observation_spoken.connect(_on_observation)
		guide.reply_finished.connect(_on_chat)
		scene.add_child(zones)
		for zone: String in AreaContext.ZONES:
			var center: Vector2 = zones.get_node(zone + "/CollisionShape2D").global_position
			guide.global_position = center
			player.global_position = center + Vector2(-30, 15)
			await _frames()
			guide._comment_gap_left = 0.0
			var expected := count + 1
			guide._tick_observations(1.0)
			if not await _wait_for(expected):
				quit(1)
				return
			_check(guide.conversation_history.is_empty(), "Automatic remarks must not become persistent travel history")
		var expected_chat := chat_count + 1
		guide.send_message("Co myslíš, co je to za loď?" if locale == "cz" else "Как думаешь, что это за лодка?")
		if not await _wait_for(expected_chat, true):
			quit(1)
			return
		var tree: Vector2 = zones.get_node("baobab/CollisionShape2D").global_position
		guide.global_position = tree
		player.global_position = tree + Vector2(-30, 15)
		await _frames()
		expected_chat = chat_count + 1
		guide.send_message("Jak je ten baobab asi starý?" if locale == "cz" else "Как думаешь, сколько лет этому баобабу?")
		if not await _wait_for(expected_chat, true):
			quit(1)
			return
		_check(not latest_chat.to_lower().contains("сотряс") and not latest_chat.to_lower().contains("otřes"), "Tree questions must not turn into Michael's lost biography")
		scene.queue_free()
		await _frames()
	print("GUIDE_AREAS_LIVE_TEST failures=", failures)
	quit(0 if failures == 0 else 1)
