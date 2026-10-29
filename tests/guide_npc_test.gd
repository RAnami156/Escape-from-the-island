extends SceneTree

# Godot --headless --path . --script res://tests/guide_npc_test.gd

const ClientScript = preload("res://script/guide_ollama_client.gd")
var GuideScene: PackedScene
var PlayerScene: PackedScene

var failures: int = 0
var _received: String = ""
var _completed: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _frames(count: int) -> void:
	for _index in count:
		await physics_frame
	await process_frame


func _run() -> void:
	GuideScene = load("res://scene/guide_npc.tscn")
	PlayerScene = load("res://scene/player.tscn")
	var global: Node = root.get_node("Global")
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player: CharacterBody2D = PlayerScene.instantiate()
	scene.add_child(player)
	var guide: CharacterBody2D = GuideScene.instantiate()
	guide.auto_introduction = false
	guide.position = Vector2(-80, 0)
	scene.add_child(guide)
	await _frames(2)
	_check(guide.player_name.is_empty(), "Player name must start unknown")
	guide._remember_player_name("Привет")
	_check(guide.player_name.is_empty(), "Greeting must not become a name")
	guide._remember_player_name("Как меня зовут?")
	_check(guide.player_name.is_empty(), "Question must not become a name")
	guide._remember_player_name("Меня зовут Роман")
	_check(guide.player_name == "Роман", "Explicit name must be remembered")
	guide._remember_player_name("Кто ты?")
	_check(guide.player_name == "Роман", "Questions must not overwrite the name")
	guide._remember_player_name("Зови меня Макс")
	_check(guide.player_name == "Макс", "Player must be able to correct the name")
	guide.player_name = ""
	guide._remember_player_name("Рома")
	_check(guide.player_name == "Рома", "A bare answer to the name question must work")
	var remembered: CharacterBody2D = GuideScene.instantiate()
	remembered.auto_introduction = false
	scene.add_child(remembered)
	_check(remembered.player_name.is_empty() and remembered.conversation_history.is_empty() and not remembered._has_met_player, "A new game must start with no previous name, history or acquaintance")
	remembered.queue_free()
	var payload: Dictionary = guide.build_request("Как меня зовут?", false)
	_check(payload.stream and not payload.think and payload.format.properties.has("intent"), "Bounded preparation and streaming must share one request")
	_check(payload.messages[0].content.contains("Рома"), "Name fact must remain outside the sliding conversation window")
	_check(payload.options.num_predict <= 160 and payload.options.num_ctx == 2048, "Response and preparation budgets must stay bounded")
	_check(guide._question_grounding("Мне страшно, вдруг мы не сможем выбраться?").is_empty(), "Escape conversation must not be mistaken for a brother question")
	_check(guide._question_grounding("Я скучаю по моей семье").is_empty(), "Player family must not be mistaken for Michael's missing memories")
	_check(guide._question_grounding("Ты знаешь, моя семья меня ждёт").is_empty(), "Addressing Michael must not turn player backstory into amnesia")
	_check(not guide._question_grounding("Расскажи про твою семью").is_empty(), "Michael must not invent his own family")
	# New games start fresh in either locale; the current game still remembers names.
	guide.conversation_history.clear()
	guide.conversation_history.append({"role": "assistant", "content": "Рад, что мы вместе."})
	global.language = "cz"
	var czech: CharacterBody2D = GuideScene.instantiate()
	czech.auto_introduction = false
	scene.add_child(czech)
	_check(czech.player_name.is_empty() and czech.conversation_history.is_empty(), "A Czech new game must not restore another game's name or history")
	_check(czech.title.text == "Michael" and czech.send_button.text == "Odeslat" and czech.close_button.text == "Zavřít", "Czech interface must be localized")
	_check(czech._question_grounding("Stýská se mi po rodině").is_empty(), "Czech player family must remain a conversation topic")
	_check(not czech._question_grounding("Máš děti?").is_empty(), "Czech family questions must respect Michael's unknown past")
	var czech_payload: Dictionary = czech.build_request("", true)
	_check(czech_payload.messages[0].content.begins_with("Jsi Michael") and czech_payload.messages[-1].content.contains("letadla"), "Czech personality and introduction must use native Czech instructions")
	czech._remember_player_name("Jmenuju se Řehoř")
	_check(czech.player_name == "Řehoř", "Czech names with diacritics must be remembered")
	czech.conversation_history.append({"role": "assistant", "content": "Jsem rád, že jsme spolu."})
	czech.queue_free()
	global.language = "ru"
	var russian: CharacterBody2D = GuideScene.instantiate()
	russian.auto_introduction = false
	scene.add_child(russian)
	_check(russian.player_name.is_empty() and russian.conversation_history.is_empty(), "Returning to Russian through a new game must start a fresh dialogue")
	russian.queue_free()
	guide._has_met_player = true
	guide._introduction_started = true
	guide.player_name = "Лена"
	guide.conversation_history.append({"role": "assistant", "content": "Привет, Лена, ты в порядке?"})
	guide.reset_dialogue()
	_check(guide.player_name.is_empty() and guide.conversation_history.is_empty() and not guide._has_met_player and not guide._introduction_started, "Explicit restart must clear all acquaintance state")
	var new_intro: Dictionary = guide.build_request("", true)
	_check(not new_intro.messages[0].content.contains("Рома") and new_intro.messages[-1].content.contains("Первая встреча"), "Restart must generate a first meeting instead of a welcome using an old name")
	_check(not JSON.stringify(new_intro).contains("Лена") and guide.transcript.text.is_empty(), "Old Lena greetings must not leak into UI or a new Ollama request")
	guide.open_chat()
	_check(not global.player_can_move and guide.input.has_focus(), "Typing must lock player movement")
	guide.close_chat()
	_check(global.player_can_move and not guide.chat_panel.visible, "Closing chat must restore player movement")
	player.global_position = Vector2(200, 0)
	await _frames(140)
	_check(guide.global_position.distance_to(player.global_position) <= 50.0, "Michael must follow and stop near the player")
	var wall := StaticBody2D.new()
	wall.position = Vector2(300, 0)
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(80, 200)
	collider.shape = rectangle
	wall.add_child(collider)
	scene.add_child(wall)
	await _frames(2)
	for destination: Vector2 in [Vector2(200, 160), Vector2(400, 160), Vector2(400, 0)]:
		while player.global_position.distance_to(destination) > 1.0:
			player.global_position = player.global_position.move_toward(destination, 3.0)
			await _frames(1)
	await _frames(100)
	_check(guide.global_position.distance_to(player.global_position) <= 55.0, "Player trail must guide Michael around a wall")
	var client := ClientScript.new()
	scene.add_child(client)
	client.token_received.connect(func(value: String) -> void: _received += value)
	client.completed.connect(func(value: String, _metrics: Dictionary) -> void: _completed = value)
	client.busy = true
	var bytes := (JSON.stringify({"message": {"content": "Привет, Рома!", "thinking": "hidden"}, "done": false}) + "\n" + JSON.stringify({"message": {"content": ""}, "done": true}) + "\n").to_utf8_buffer()
	for byte: int in bytes:
		client.feed_bytes(PackedByteArray([byte]))
	_check(_received == "Привет, Рома!" and _completed == _received, "Split UTF-8 stream must display immediately without thinking text")
	_check(not client.busy, "Completed stream must release the client")
	_received = ""
	_completed = ""
	client._structured = true
	client._reply = ""
	client._raw_content = ""
	client.busy = true
	var spoken := 'Ahoj, Řehoři! Říkám: "klid".\nJdeme 🙂'
	var structured := JSON.stringify({"intent": "Vnímat obavy a nabídnout podporu", "reply": spoken})
	structured = structured.replace("Ř", "\\u0158").replace("ř", "\\u0159").replace("🙂", "\\ud83d\\ude42")
	for character: String in structured:
		client.feed_bytes((JSON.stringify({"message": {"content": character}, "done": false}) + "\n").to_utf8_buffer())
	client.feed_bytes((JSON.stringify({"message": {"content": ""}, "done": true}) + "\n").to_utf8_buffer())
	_check(_received == spoken and _completed == spoken, "Structured streaming must hide preparation and decode split quotes, Unicode and emoji")
	print("GUIDE_NPC_TEST failures=", failures)
	quit(0 if failures == 0 else 1)
