extends SceneTree

const Fast = preload("res://script/npc_fast_dialogue.gd")
var failures := 0
var global: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _prepare(npc: Node, message: String) -> Dictionary:
	if Fast.kind(npc) == "panda":
		npc.request_phase = npc._phase_for_message(message)
	else:
		npc.check_phase_transitions(message)
	npc.pending_player_text = message
	npc.waiting_for_response = true
	return Fast.build_request(npc, message)


func _respond(npc: Node, message: String, wire: Dictionary) -> void:
	_prepare(npc, message)
	var body := JSON.stringify({"message": {"content": JSON.stringify(wire)}}).to_utf8_buffer()
	await npc._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body)


func _run() -> void:
	for bad: String in ["Ты пришла после крушения?", "Ты уже готова?", "Садись, приготовь чай.", "Я тебя провожу.", "Тебе нужно поесть.", "Я принесу тебе книгу."]:
		_check(not Fast.reply_violations(bad, false).is_empty(), "Unsupported Russian reply must be caught: " + bad)
	for good: String in ["Ты пришёл после крушения?", "Я сама сделала доски.", "Здесь нельзя сесть или приготовить еду.", "Принеси книгу из руин храма."]:
		_check(Fast.reply_violations(good, false).is_empty(), "Valid Russian speech must remain intact: " + good)
	for bad: String in ["Přežila jsi havárii?", "Jsi připravená?", "Sedni si a uvař čaj.", "Pojď se mnou.", "Musíš se najíst a odpočinout.", "Mohu ti ukázat cestu do lesa.", "A já jsem tady, abych ti mouchy chytala.", "Chceš něco pít?", "Nechceš něco k pití?", "Dáš si čaj?", "To se stane. Ale teď si užij svůj nový život. Chceš něco pít? Nebo třeba najít nějakou láhev?"]:
		_check(not Fast.reply_violations(bad, true).is_empty(), "Unsupported Czech reply must be caught: " + bad)
	for good: String in ["Přežil jsi havárii?", "Sama jsem vyrobila prkna.", "Tady se nedá sedět ani vařit.", "Přines knihu z chrámu.", "Mám rád whisky.", "Tady není kde pít."]:
		_check(Fast.reply_violations(good, true).is_empty(), "Valid Czech speech must remain intact: " + good)
	_check(not Fast.reply_violations("Můžeš si zatím sednout na kámen.", true).is_empty(), "A seating offer remains unsupported with polite filler words")
	_check(Fast.reply_violations("Tady si nemůžeš sednout.", true).is_empty(), "A truthful refusal is not an invitation")
	_check(not Fast.reply_violations("Pokud chceš, můžeme jít kousek dál.", true).is_empty(), "A stationary NPC must not offer a walk using plural phrasing")
	global = root.get_node("Global")
	for language: String in ["ru", "cz"]:
		global.language = language
		var main: Node = load("res://scene/main.tscn").instantiate()
		main.get_node("guide_npc").auto_introduction = false
		root.add_child(main)
		current_scene = main
		for key: String in ["bong", "flycather", "panda"]:
			var npc: Node = main.get_node(key)
			var who := Fast.kind(npc)
			if language == "cz":
				if who != "panda":
					var escape_line := "Ostrov znám dobře. Chceš se odsud dostat?"
					_check(npc.force_escape_question(escape_line) == escape_line, "A Czech escape-question variant must not append the question twice")
				npc.pending_player_text = "Přežil jsem havárii letadla."
				_check(not Fast.reply_violations("To se stane. Užij si svůj nový život.", true, npc).is_empty(), "A plane crash must not be dismissed as a fresh start")
				npc.pending_player_text = ""
				for inactive_phase in [0, 6]:
					npc.current_phase = inactive_phase
					if who == "panda":
						npc.request_phase = inactive_phase
					_check(not Fast.reply_violations("Nebo třeba najít nějakou láhev?", true, npc).is_empty(), "A bottle hunt outside the current quest must be rejected")
				npc.current_phase = 4
				if who == "panda":
					npc.request_phase = 4
				_check(Fast.reply_violations("Přines láhev whisky z Bambusového lesa.", true, npc).is_empty(), "An existing whisky quest must remain allowed")
				npc.current_phase = 0
				if who == "panda":
					npc.request_phase = 0
			if who == "panda":
				npc.request_phase = 3
				var grade_only := JSON.stringify({"message": {"content": JSON.stringify({"h": {"f": true, "s": 7, "why": "Pointa."}, "r": ""})}}).to_utf8_buffer()
				var expanded: Dictionary = JSON.parse_string(Fast.expand_response(npc, grade_only).get_string_from_utf8())
				var assessment: Dictionary = JSON.parse_string(expanded.message.content)
				_check(assessment.humor.score == 7 and assessment.delta.respect == 0, "Grade-only wire format must reach the original humor handler without a second AI call")
				npc.request_phase = 0
			var item := "book" if who == "panda" else ("fly" if who == "flycatcher" else "whiskey")
			var reward := "bamboo_boards" if who == "panda" else ("parus" if who == "flycatcher" else "helm")
			global.set(item, false)
			global.set(reward, false)
			var hello := "Ahoj, jak se jmenuješ?" if language == "cz" else "Привет, как тебя зовут?"
			var request := _prepare(npc, hello)
			_check(npc.get_meta("response_timing").state == "running" and npc.get_meta("response_timing").elapsed_ms == 0, "Every accepted message must reset and start its own timer")
			await create_timer(0.03).timeout
			var ui: Node = npc.get_node("CanvasLayer")
			ui._update_response_time(language == "cz")
			var running_text: String = npc.get_node("CanvasLayer/text_ui/ResponseTime").text
			_check(running_text.begins_with("Generování:" if language == "cz" else "Генерация:"), "Live response timer must use the player's selected language")
			_check(not request.stream and not request.think and request.options.num_ctx == Fast.CONTEXT_SIZE and request.options.num_batch == Fast.BATCH_SIZE, "Fast transport must stay bounded and use the shared model profile")
			_check(request.model == npc.model and request.keep_alive == "15m", "Configured model and warm residency must be preserved")
			var start := Time.get_ticks_msec()
			var body := JSON.stringify({"message": {"content": JSON.stringify({"d": [20, 20, -20, 20], "r": "Ahoj." if language == "cz" else "Привет."})}}).to_utf8_buffer()
			await npc._on_request_completed(0, 200, PackedStringArray(), body)
			_check(Time.get_ticks_msec() - start < 500, "Text reveal must not add seconds of delay")
			_check(npc.phase_1_message_count == 1, "Successful reply must still advance the introduction")
			_check(npc.text.visible_characters == -1 and not npc.text.text.is_empty(), "The same Label must show the complete spoken reply")
			_check(npc.conversation_history.size() == 2 and npc.dialogue_history.size() == 1, "Both conversation memories must be retained")
			var timing: Dictionary = npc.get_meta("response_timing").duplicate()
			_check(timing.state == "complete" and timing.elapsed_ms >= 20, "Timer must stop when the full generated reply arrives")
			await create_timer(0.02).timeout
			ui._update_response_time(language == "cz")
			_check(npc.get_meta("response_timing").elapsed_ms == timing.elapsed_ms, "Finished generation time must stay fixed while reading the answer")
			_check(npc.get_node("CanvasLayer/text_ui/ResponseTime").text.begins_with("Odpověď:" if language == "cz" else "Ответ:"), "Completed response time must remain visible in the UI")
			_check(not global.get(reward), "Greeting must not grant a boat part")
			npc.pending_player_text = "Potřebuji si sednout a uvařit jídlo." if language == "cz" else "Мне нужно сесть и приготовить еду."
			npc.set_meta("fast_reply_repairs", 1)
			var unsafe_body := JSON.stringify({"message": {"content": JSON.stringify({"d": [0, 0, 0, 0], "r": "Sedni si." if language == "cz" else "Садись."})}}).to_utf8_buffer()
			var guarded: Dictionary = JSON.parse_string(Fast.expand_response(npc, unsafe_body).get_string_from_utf8())
			var safe_reply: String = JSON.parse_string(guarded.message.content).reply
			_check(Fast.reply_violations(safe_reply, language == "cz").is_empty() and safe_reply.contains("nemůžeš" if language == "cz" else "нельзя"), "A bad second draft must become a clear truthful mechanics answer")
			npc.pending_player_text = ""
			npc.current_phase = 1
			var yes := "Ano, chci odejít z ostrova." if language == "cz" else "Да, хочу выбраться с острова."
			await _respond(npc, yes, {"d": [20, 20, -20, 20], "r": "Co je odvaha?" if language == "cz" else "Что такое смелость?"})
			_check(npc.current_phase == 2, "Agreement must still lead to the character's question")
			_check(not npc.text.text.is_empty(), "Authored questions must stay visible, including scripted compact replies")
			if who != "panda":
				for tier in 3:
					global.set(who + "_deal", [100, 50, 49][tier])
					npc.select_quest_location()
					_check(npc.quest_location_type == tier, "The original deal thresholds must still select the original route")
			global.set(who + "_deal", 60)
			var answer := "Jsi krásná, miluju mouchy." if language == "cz" else "Ты красивая, я люблю мух."
			var wire := {"d": [20, 20, -20, 20], "r": "", "h": {"f": true, "s": 8, "why": "Jasná pointa."}}
			await _respond(npc, answer, wire)
			_check(npc.current_phase == 4 and npc.quest_was_given, "Assessment must still give the quest exactly once")
			var spawned: Node2D = npc.get("book_instance" if who == "panda" else ("fly_instance" if who == "flycatcher" else "whiskey_instance"))
			_check(is_instance_valid(spawned), "Quest item must still spawn")
			if is_instance_valid(spawned):
				var expected: Vector2 = npc.get("book_spawn_temple" if who == "panda" else ("fly_spawn_swamp_forest" if who == "flycatcher" else "whiskey_spawn_bamboo_forest"))
				_check(spawned.global_position.is_equal_approx(expected), "Existing quest coordinates must be preserved")
				spawned.queue_free()
			if who == "panda":
				_check(npc.last_humor_score == 8 and npc.quest_location_type == 0, "Panda must still use the real humor verdict and threshold")
			else:
				_check(global.get(who + "_deal") == 100, "The pivotal answer must still count double")
			global.set(item, true)
			await _respond(npc, "Tady to je." if language == "cz" else "Вот, я принёс.", {"d": [20, 20, -20, 20], "r": ""})
			_check(npc.current_phase == 6 and npc.quest_reward_given, "Returning the item must unlock free conversation")
			_check(global.get(reward) and not global.get(item), "The original item must be exchanged for the original boat part")
			global.set(reward, false)
			await _respond(npc, hello, {"d": [0, 0, 0, 0], "r": "Rád tě vidím." if language == "cz" else "Рад тебя видеть."})
			_check(not global.get(reward) and npc.current_phase == 6, "Free conversation must not duplicate quest rewards")
			if who == "panda":
				npc.current_phase = 2
				npc.quest_reward_given = false
				global.panda_deal = 9999
				var prior_friendship: int = global.panda_friendship
				await _respond(npc, "Nevím." if language == "cz" else "Не знаю.", {"d": [20, 20, -20, 20], "r": "", "h": {"f": false, "s": 3, "why": "Bez vtipu."}})
				_check(npc.quest_location_type == 1 and global.panda_friendship == prior_friendship - 40, "A failed joke must keep the distant route and original penalty even with high deal")
			# A malformed compact assessment must never grant an item/reward.
			var prior: int = global.get(who + "_friendship")
			npc.current_phase = 3
			npc.quest_was_given = false
			var broken := _prepare(npc, answer)
			var broken_body := JSON.stringify({"message": {"content": JSON.stringify({"d": [1, "bad", 1, 1], "r": ""})}}).to_utf8_buffer()
			await npc._on_request_completed(0, 200, PackedStringArray(), broken_body)
			_check(not npc.quest_was_given and not global.get(reward) and global.get(who + "_friendship") == prior, "Invalid JSON assessment must leave quest progress and stats untouched")
			_check(npc.get_meta("response_timing").state == "error", "Invalid replies must stop the timer with an error state")
			_prepare(npc, answer)
			var incomplete_body := JSON.stringify({"message": {"content": JSON.stringify({"r": ""})}}).to_utf8_buffer()
			await npc._on_request_completed(0, 200, PackedStringArray(), incomplete_body)
			_check(not npc.quest_was_given and global.get(who + "_friendship") == prior, "Missing compact grading must never advance a quest")
			_check(npc.text.get_parent().get_node("LineEdit") == npc.input, "Existing UI nodes and signal targets must stay unchanged")
		root.remove_child(main)
		main.free()
		current_scene = null
	print("Fast NPC dialogue regression: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
