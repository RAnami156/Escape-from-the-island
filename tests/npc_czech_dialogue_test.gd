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
		var greeting := _prepare(npc, "ahoj")
		_check(greeting.format.properties.has("i") and not greeting.format.properties.has("r"), "Czech free talk must select an index, never generate unbounded speech")
		_check(not greeting.think and greeting.options.num_predict <= 80, "No thinking pass or long speech decoding")
		_check(greeting.options.num_ctx == Fast.CONTEXT_SIZE and greeting.options.num_batch == Fast.BATCH_SIZE, "Do not reload Michael's shared Ollama runner")
		var system: String = greeting.messages[0].content
		_check(system.contains("muž") and system.contains("tmavými vlasy") and system.contains("modrými kalhotami"), "Every Czech NPC knows the actual player sprite")
		_check(not JSON.stringify(greeting).contains("AUTHORED BEHAVIOR"), "Do not resend the long duplicate old behavior instructions")
		var hello: Array = npc.get_meta("czech_reply_choices")
		for spoken: String in hello:
			_check(spoken.to_lower().contains("ahoj") and not spoken.to_lower().contains("letadl"), "A greeting must not turn into sightseeing")
		var wire := {"message": {"content": JSON.stringify({"d": [20, 0, 0, 0], "i": 0})}}
		var expanded: Dictionary = JSON.parse_string(Fast.expand_response(npc, JSON.stringify(wire).to_utf8_buffer()).get_string_from_utf8())
		var response: Dictionary = JSON.parse_string(expanded.message.content)
		_check(response.reply == hello[0] and response.delta.respect == 20, "Selected speech and AI scoring reach the original handlers together")
		for wrong_index: Variant in [-1, 999, 0.5, "0"]:
			wire.message.content = JSON.stringify({"d": [20, 0, 0, 0], "i": wrong_index})
			expanded = JSON.parse_string(Fast.expand_response(npc, JSON.stringify(wire).to_utf8_buffer()).get_string_from_utf8())
			_check(expanded.message.content == "null", "Malformed selection must not apply relationships or progress")
		_prepare(npc, "cooo")
		npc.conversation_history.assign([{"role": "assistant", "content": "Sleduju trosky letadla u východní pláže. Chceš se na ně podívat?"}])
		var clarified: String = Czech.guard(npc, "Trosky jsou nebezpečný kousek. Budeš muset sebe ovládat.")
		_check(clarified.contains("nejasně") or clarified.contains("Myslela"), "cooo must become an explanation, including after an old saved hallucination")
		var clean_request := _prepare(npc, "cooo")
		_check(not JSON.stringify(clean_request).contains("Sleduju trosky"), "Old hallucinated sightseeing must not be fed back as history")
		for bad: String in ["Chceš se podívat na letadlo?", "Chceš něco pít?", "Můžeš si je prohlédnout, ale budeš muset sebe ovládat.", "Sedni si a uvař čaj."]:
			_prepare(npc, "ahoj")
			_check(Czech.guard(npc, bad) in Czech.replies(npc, "ahoj"), "Unsafe speech is replaced locally with a line for the actual message")
			_check(not Fast.maybe_repair_reply(npc, 0, 200, JSON.stringify({"message": {"content": JSON.stringify({"d": [0, 0, 0, 0], "r": bad})}}).to_utf8_buffer()), "Czech guard must never send a second AI request")
		_prepare(npc, "Jak vypadám?")
		var appearance: String = Czech.replies(npc, "Jak vypadám?")[0]
		_check(appearance.contains("košilí") and appearance.contains("kalhotami") and appearance.contains("tmavými vlasy"), "Appearance response must match the sprite")
		_prepare(npc, "Chceš si sednout a dát čaj?")
		_check(Czech.guard(npc, "Ano, posaď se.").contains("nemůžeš"), "Explicit unavailable-action requests get a truthful refusal")
		_prepare(npc, "Kde je můj úkol?")
		_check(Czech.replies(npc, "Kde je můj úkol?")[0].contains("žádném úkolu"), "Before a quest, do not invent one")
		npc.quest_was_given = true
		npc.quest_location = "původní místo zadané hrou"
		_prepare(npc, "Kde to mám hledat?", 4)
		var reminder: String = Czech.replies(npc, "Kde to mám hledat?")[0]
		_check(reminder.contains(npc.quest_location), "Active quest repeats only the selected original destination")
		npc.quest_reward_given = true
		_prepare(npc, "Dej mi další úkol.", 6)
		_check(Czech.replies(npc, "Dej mi další úkol.")[0].contains("splněná"), "Finished quests cannot become a new fetch quest")
		npc.quest_was_given = false
		npc.quest_reward_given = false
		var script_line := _prepare(npc, "Tady to je.", 5)
		_check(script_line.format.properties.r.enum == [""] and not script_line.format.properties.has("i"), "Existing reward lines remain authored by the game")
		if who == "panda":
			var grading := _prepare(npc, "Nevím, zatím mě nenapadla vtipná odpověď.", 3)
			_check(grading.format.properties.has("h") and not grading.format.properties.has("d"), "Panda still grades the real joke, and its handler derives the four deltas")
	main.free()
	current_scene = null
	# The Russian path and Michael retain their original generation/profile.
	global.language = "ru"
	main = load("res://scene/main.tscn").instantiate()
	main.get_node("guide_npc").auto_introduction = false
	root.add_child(main)
	current_scene = main
	root.get_node("SaveGame")._autosave_left = 999999.0
	var russian := Fast.build_request(main.get_node("bong"), "Привет")
	_check(russian.format.properties.has("r") and not russian.format.properties.has("i") and russian.options.num_predict == 256, "Russian dialogue options and schema stay unchanged")
	var michael: Dictionary = main.get_node("guide_npc").build_request("Привет", false)
	_check(michael.stream and not michael.format.properties.has("i") and michael.options.num_ctx == Fast.CONTEXT_SIZE, "Michael stays on his existing generation path")
	print("CZECH_DIALOGUE_TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
