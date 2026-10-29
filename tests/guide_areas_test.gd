extends SceneTree

const StubClient = preload("res://tests/guide_area_client_stub.gd")
const AreaContext = preload("res://script/guide_area_context.gd")
var failures: int = 0
var spoken: Array[String] = []

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

func _run() -> void:
	var authored: Node2D = load("res://scene/main.tscn").instantiate()
	var main_guide: Node = authored.get_node("guide_npc")
	_check(main_guide.follow_speed > 0.0 and main_guide.follow_distance > 0.0, "Main must not override follower settings with null")
	_check(main_guide.ollama_host == "127.0.0.1" and main_guide.ollama_port == 11434 and main_guide.model == "qwen3:8b", "Main must preserve valid Ollama defaults")
	_check(main_guide.auto_introduction and main_guide.area_settle_time <= 0.1, "Main must enable a fresh introduction and fast zone remarks")
	var zones: Node2D = authored.get_node("for_npc").duplicate()
	var scene := Node2D.new()
	scene.transform = authored.transform
	authored.free()
	root.add_child(scene)
	current_scene = scene
	var player: CharacterBody2D = load("res://scene/player.tscn").instantiate()
	player.position = Vector2(-2000, -2000)
	scene.add_child(player)
	var guide: CharacterBody2D = load("res://scene/guide_npc.tscn").instantiate()
	guide.auto_introduction = false
	guide.position = Vector2(-2000, -2000)
	scene.add_child(guide)
	guide.set_physics_process(false)
	guide.set_process(false)
	guide._client.queue_free()
	var client := StubClient.new()
	guide.add_child(client)
	guide._client = client
	client.token_received.connect(guide._on_token_received)
	client.completed.connect(guide._on_reply_completed)
	client.failed.connect(guide._on_reply_failed)
	guide.observation_spoken.connect(func(zone: String, _text: String) -> void: spoken.append(zone))
	scene.add_child(zones)
	await _frames()
	_check(guide.area_settle_time <= 0.1, "Area delay must stay below a tenth of a second")
	_check(guide.collision_layer == 8 and (player.collision_mask & 8) == 0, "Michael must not block the player")
	for language: String in ["ru", "cz"]:
		root.get_node("Global").language = language
		guide.reset_dialogue()
		for zone: String in AreaContext.ZONES:
			var area: Area2D = zones.get_node(zone)
			var center: Vector2 = area.get_node("CollisionShape2D").global_position
			_check(area.collision_mask == 8 and area.collision_layer == 0, "Only Michael must trigger areas")
			player.global_position = center
			await _frames()
			_check(guide._inside_zones.is_empty(), "Player alone must not trigger observations")
			guide.global_position = center
			await _frames()
			_check(guide._inside_zones.has(zone), "Physical entry must set area context")
			guide.enter_observation_zone(zone)
			var before := spoken.size()
			guide._tick_observations(0.1)
			_check(spoken.size() == before + 1 and spoken[-1] == zone, "Area line must appear immediately")
			_check(client.requests.is_empty() and not client.busy, "Area remarks must never wait for Ollama")
			_check(guide.bubble.text == AreaContext.lines(zone, language == "cz")[0], "First entry must use the clearest localized line")
			_check(guide.bubble.max_lines_visible == -1, "The whole remark must be visible")
			_check(not guide.chat_panel.visible and guide.conversation_history.is_empty(), "Ambient remarks must not open chat or become chat history")
			guide._tick_observations(100.0)
			_check(spoken.size() == before + 1, "Standing in an area must not repeat remarks")
			guide.global_position = Vector2(-2000, -2000)
			await _frames()
			_check(guide._inside_zones.is_empty(), "Exit must clear current context")
		var ship: Node = load("res://scene/ship.tscn").instantiate()
		ship.name = "ship"
		ship.ship_ready = true
		scene.add_child(ship)
		player.global_position = guide.global_position
		guide.enter_observation_zone("ship")
		guide._tick_observations(0.1)
		_check(AreaContext.lines("ship", language == "cz", true).has(guide.bubble.text), "Repaired ship must not be described as broken")
		_check(guide._area_facts("ship") == AreaContext.facts("ship", language == "cz", true), "Chat must receive the repaired ship state")
		ship.free()
		guide.exit_observation_zone("ship")
		guide._tick_observations(100.0)
		guide.enter_observation_zone("paths")
		guide._tick_observations(0.1)
		var first: String = guide.bubble.text
		guide.exit_observation_zone("paths")
		guide.enter_observation_zone("paths")
		var before := spoken.size()
		guide._tick_observations(0.1)
		_check(spoken.size() == before, "Immediate reentry must respect cooldown")
		guide.exit_observation_zone("paths")
		guide._tick_observations(100.0)
		guide.enter_observation_zone("paths")
		guide._tick_observations(0.1)
		_check(guide.bubble.text != first, "Later remarks must not repeat the previous line")
		guide.exit_observation_zone("paths")
		guide._tick_observations(100.0)
		guide.send_message("Jak se mas?" if language == "cz" else "Ты как?")
		var requests_before := client.requests.size()
		guide.enter_observation_zone("beach")
		before = spoken.size()
		guide._tick_observations(1.0)
		_check(spoken.size() == before, "Player conversation must retain priority")
		guide.exit_observation_zone("beach")
		client.finish("Jsem tady." if language == "cz" else "Я здесь.")
		guide._tick_observations(1.0)
		_check(spoken.size() == before and client.requests.size() == requests_before, "Exited queued areas must not speak later")
		guide.enter_observation_zone("baobab")
		var context: Dictionary = guide.build_request("Jak je ten baobab stary?" if language == "cz" else "Сколько лет этому баобабу?", false)
		_check(context.format.properties.reply.enum == AreaContext.age_answers(language == "cz"), "Unknown tree age must stay unknown")
		guide.exit_observation_zone("baobab")
		client.requests.clear()
	print("GUIDE_AREAS_TEST failures=", failures)
	quit(0 if failures == 0 else 1)
