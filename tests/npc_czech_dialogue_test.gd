extends SceneTree

const Fast = preload("res://script/npc_fast_dialogue.gd")
const Czech = preload("res://script/npc_czech_dialogue.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _prepare(npc: Node, text: String, current: int = 0) -> Dictionary:
	npc.current_phase = current
	if Czech.kind(npc) == "panda":
		npc.request_phase = current
	npc.pending_player_text = text
	return Fast.build_request(npc, text)


func _expand(npc: Node, wire: Dictionary) -> Variant:
	var body := JSON.stringify({"message": {"content": JSON.stringify(wire)}}).to_utf8_buffer()
	var outer: Dictionary = JSON.parse_string(Fast.expand_response(npc, body).get_string_from_utf8())
	return JSON.parse_string(outer.message.content)


func _run() -> void:
	var global: Node = root.get_node("Global")
	global.language = "cz"
	var main: Node = load("res://scene/main.tscn").instantiate()
	main.get_node("guide_npc").auto_introduction = false
	root.add_child(main)
	current_scene = main
	root.get_node("SaveGame")._autosave_left = 999999.0
	for path: String in ["bong", "panda", "flycather"]:
		var npc: Node = main.get_node(path)
		var who := Czech.kind(npc)
		for text: String in ["cau)", "jak se maš", "wtf jak ze nic neviš"]:
			var request := _prepare(npc, text)
			_check(request.format.properties.has("r") and not request.format.properties.has("i"), "Czech conversation must generate its own speech, including informal input")
			_check(not request.format.properties.r.has("enum"), "Free talk must not be limited to canned lines")
			_check(not request.think and request.options.num_predict >= 256, "Free speech needs enough tokens to finish its sentences")
			_check(request.options.num_ctx == Fast.CONTEXT_SIZE and request.options.num_batch == Fast.BATCH_SIZE, "Keep the shared Ollama runner profile")
			_check(request.messages[-1].content == text, "The model must see the player's exact input")
			var spoken := "Docela dobře, dnes mám konečně chvíli klidu. A co ty?"
			var response: Dictionary = _expand(npc, {"d": [20, 0, 0, 0], "r": spoken})
			_check(response.reply == spoken and response.delta.respect == 20, "An original valid line and its scoring must reach the handlers unchanged")
			_check(not npc.get_meta("fast_reply_filtered"), "An original line must not be replaced just because it is absent from a list")
		_check(_prepare(npc, "cau").options.temperature == 0.3, "Ordinary dialogue uses moderate sampling")
		var speech_request := _prepare(npc, "nevim jak se maš")
		_check(not speech_request.format.properties.has("d"), "Speech generation must not also grade relationships")
		var draft := "Mám se dobře, díky za optání."
		var assessment := Fast.prepare_assessment(npc, {"eval_count": 10, "prompt_eval_count": 100}, {"r": draft})
		_check(assessment.format.properties.has("d") and assessment.format.properties.r.enum == [""], "A separate assessment generates only scoring, never new speech")
		_check(npc.get_meta("response_timing").state == "running" and npc.get_meta("czech_request_stage") == "assessment", "The response timer and transaction remain open until grading finishes")
		var joined: Dictionary = _expand(npc, {"r": "", "d": [0, 0, 0, 0]})
		_check(joined.reply == draft and joined.delta.respect == 0, "Only validated scoring is joined to the unchanged spoken draft")
		_check(npc.get_meta("fast_metrics").output_tokens == 10, "Generation metrics include both requests")
		_prepare(npc, "jak se máš")
		Fast.prepare_assessment(npc, {}, {"r": draft})
		var neutral: Dictionary = _expand(npc, {"behavior": "neutral", "r": "", "d": [-20, -20, 20, -20]})
		_check(neutral.delta.respect == 0 and neutral.delta.friendship == 0 and neutral.delta.irritation == 0 and neutral.delta.deal_affinity == 0, "A neutral classification cannot carry contradictory hostility penalties")
		_prepare(npc, "jsi idiot")
		Fast.prepare_assessment(npc, {}, {"r": draft})
		var hostile: Dictionary = _expand(npc, {"behavior": "hostile", "r": "", "d": [-20, -20, 20, -20]})
		_check(hostile.delta.respect == -20 and hostile.delta.irritation == 20, "Actual hostility still affects relationships")

		_prepare(npc, "ahoj")
		Fast.prepare_assessment(npc, {}, {"r": draft})
		_check(_expand(npc, {"r": "Jiná replika.", "d": [20, 0, 0, 0]}) == null, "The grader cannot replace the already generated speech")
		var system: String = JSON.stringify(_prepare(npc, "Jak vypadám?"))
		_check(system.contains("muž") and system.contains("tmavými vlasy") and system.contains("modrými kalhotami"), "Every Czech NPC knows the actual player sprite")
		_check(not system.contains("Přežil havárii letadla"), "Appearance must not give the NPC knowledge of the player's arrival")
		for broken: Dictionary in [{"d": [20, 0, 0, 0], "i": 0}, {"d": [20, 0, 0, 0], "r": null}, {"d": ["bad", 0, 0, 0], "r": "Ahoj."}]:
			_check(_expand(npc, broken) == null, "Malformed and obsolete index responses must not apply stats")
		npc.conversation_history.assign([
			{"role": "user", "content": "cau)", "profile": Czech.PROFILE_VERSION},
			{"role": "assistant", "content": "Ty jsi z toho letadla? Sedni si.", "profile": Czech.PROFILE_VERSION},
			{"role": "user", "content": "jak se maš", "profile": Czech.PROFILE_VERSION},
			{"role": "assistant", "content": "Docela dobře. Dnes je tu klid.", "profile": Czech.PROFILE_VERSION},
		])
		var request := _prepare(npc, "cooo")
		_check(not JSON.stringify(request).contains("Sedni si") and JSON.stringify(request).contains("Dnes je tu klid"), "History preserves normal speech and removes old setting violations")
		npc.conversation_history.assign([
			{"role": "user", "content": "Jmenuju se Roman."},
			{"role": "assistant", "content": "Nebo jsi si to dovolil já."},
		])
		var migrated := JSON.stringify(_prepare(npc, "Jak se jmenuju?"))
		_check(not migrated.contains("dovolil já") and migrated.contains("jmenuje Roman"), "Old broken assistant speech must not poison new replies; explicitly learned player facts survive")
		_check(npc.conversation_history.size() == 2, "Context migration must preserve the saved conversation for the UI")
		npc.conversation_history.clear()
		_prepare(npc, "ahoj")
		_check(Fast.keep_supported_sentences(npc, "Mám se dobře. Jen si sedím a pozoruju moře.") == "Mám se dobře.", "Remove only the impossible action, preserving the model's own relevant answer")
		_check(Fast.keep_supported_sentences(npc, "Sedni si a napij se.").is_empty(), "Filtering cannot invent a reply when no supported sentence remains")
		for bad: String in ["Chceš něco pít?", "Sedni si a uvař čaj.", "Ty jsi z toho letadla?", "Přežil jsi havárii?"]:
			_check(not Fast.reply_violations(bad, true, npc).is_empty(), "Only actual setting violations are rejected: " + bad)
			var response: Dictionary = _expand(npc, {"d": [0, 0, 0, 0], "r": bad})
			_check(response.reply != bad, "A forbidden line must not reach the player")
		for spoken: String in ["Ahoj, jak se vede?", "U ruin je dnes klid.", "Chceš se podívat na baobab?", "Tady se nedá sedět ani vařit.", "Pojďme si promluvit o ostrově."]:
			_check(Fast.reply_violations(spoken, true, npc).is_empty(), "Natural conversation and supported exploration remain allowed")
		if who == "flycatcher":
			var neutral_delta := {"respect": 0, "friendship": 0, "irritation": 0, "deal_affinity": 0}
			var normal: Dictionary = npc.enforce_flycatcher_relationship_delta("nevim jak se maš", neutral_delta.duplicate())
			_check(normal == neutral_delta, "Flycatcher's local rules must not punish ordinary questions for lacking a compliment")
			npc.current_phase = 3
			var pivotal: Dictionary = npc.enforce_flycatcher_relationship_delta("Ne, mouchy nemám rád.", neutral_delta.duplicate())
			_check(pivotal.respect < 0 and pivotal.irritation > 0, "Her actual character question keeps its authored consequence")
			npc.current_phase = 0
		var valid_line := "Pojďme si promluvit o ostrově."
		if who == "bong":
			_check(npc.sanitize_stationary_reply(valid_line, 0) == valid_line, "The legacy Kong filter must preserve supported conversation")
		if who == "panda":
			_check(npc.sanitize_reply(valid_line, "ahoj") == valid_line, "The legacy Panda filter must preserve supported conversation")
		_prepare(npc, "Přežil jsem havárii letadla.")
		_check(Fast.reply_violations("Přežil jsi havárii? To muselo být těžké.", true, npc).is_empty(), "The NPC may respond when the player discloses the crash")
		npc.conversation_history.assign([{"role": "user", "content": "Přežil jsem havárii letadla."}])
		_prepare(npc, "pamatuješ?")
		_check(Fast.reply_violations("Přežil jsi havárii.", true, npc).is_empty(), "Disclosed player facts remain available from history")
		npc.conversation_history.clear()
		npc.quest_was_given = true
		npc.quest_location = "původní místo zadané hrou"
		var reminder := _prepare(npc, "Kde to mám hledat?", 4)
		_check(JSON.stringify(reminder).contains(npc.quest_location), "Active quest keeps its selected destination in context")
		npc.quest_reward_given = true
		var completed := _prepare(npc, "Dej mi další úkol.", 6)
		_check(JSON.stringify(completed).contains("splněná"), "Completed quest facts remain in context")
		_check(not Fast.reply_violations("Mám pro tebe malý problém. Potřebuji, abys našel tři speciální květy.", true, npc).is_empty(), "An invented quest for arbitrary objects must be rejected too")
		_check(Czech.quest_status(npc).contains("splněná"), "Quest recovery uses the engine's completed agreement, not an invented task")
		_check(Czech.completed_quest_reply(npc, "Dej mi další úkol.", "conversation") == Czech.quest_status(npc), "Explicit requests cannot create another quest even if intent was misclassified")
		_check(Czech.completed_quest_reply(npc, "Jak se máš?", "wellbeing").is_empty(), "Completing a quest must not replace ordinary free conversation")
		npc.quest_was_given = false
		npc.quest_reward_given = false
		var script_line := _prepare(npc, "Tady to je.", 5)
		_check(script_line.format.properties.r.enum == [""], "Reward lines remain authored by the game")
		if who == "bong":
			_prepare(npc, "Ano, chci odejít z ostrova.", 2)
			var question: Dictionary = _expand(npc, {"d": [20, 0, 0, 0], "r": ""})
			_check(question.reply in Czech.WISDOM_QUESTIONS, "Kong must still ask his quest question before evaluating the player's answer")
		if who == "panda":
			var grading := _prepare(npc, "Nevím, zatím mě nenapadla vtipná odpověď.", 3)
			_check(grading.format.properties.has("h") and not grading.format.properties.has("d"), "Panda still grades the actual joke")
	main.free()
	current_scene = null
	global.language = "ru"
	main = load("res://scene/main.tscn").instantiate()
	main.get_node("guide_npc").auto_introduction = false
	root.add_child(main)
	current_scene = main
	root.get_node("SaveGame")._autosave_left = 999999.0
	var kong: Node = main.get_node("bong")
	var russian := Fast.build_request(kong, "Привет")
	_check(russian.format.properties.has("r") and not russian.format.properties.has("i"), "Russian dialogue remains free generation")
	kong.pending_player_text = "Привет"
	_check(not Fast.reply_violations("О, ты с самолёта!", false, kong).is_empty(), "Russian NPCs also cannot guess how the player arrived")
	kong.pending_player_text = "Я выжил после крушения самолёта."
	_check(Fast.reply_violations("Ты выжил после крушения?", false, kong).is_empty(), "Russian NPCs may discuss disclosed player facts: " + str(Fast.reply_violations("Ты выжил после крушения?", false, kong)))
	var michael: Dictionary = main.get_node("guide_npc").build_request("Привет", false)
	_check(michael.stream and not michael.format.properties.has("i") and michael.options.num_ctx == Fast.CONTEXT_SIZE, "Michael keeps his existing generation path")
	main.free()
	current_scene = null
	print("CZECH_DIALOGUE_TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
