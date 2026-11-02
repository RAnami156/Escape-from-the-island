extends "res://tests/npc_czech_dialogue_live_test.gd"
## Live language regression. Requires the configured Czech model in local Ollama.
## Keeps the introduction open to examine conversation independently of the quest chain.


func _run() -> void:
	root.get_node("SaveGame").save_path = "/private/tmp/island-npc-quality-unused.json"
	var global: Node = root.get_node("Global")
	global.language = "cz"
	var main: Node = load("res://scene/main.tscn").instantiate()
	main.get_node("guide_npc").auto_introduction = false
	root.add_child(main)
	current_scene = main
	root.get_node("SaveGame")._autosave_left = 999999.0
	for path: String in ["bong", "panda", "flycather"]:
		var npc: Node = main.get_node(path)
		var who := Fast.kind(npc)
		var selected := true
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--npc=") and argument.trim_prefix("--npc=") != who:
				selected = false
			if argument.begins_with("--model="):
				npc.model = argument.trim_prefix("--model=")
		if not selected:
			continue
		for text: String in ["cau)", "nevim jak se maš", "jmenuju se Roman", "jak se jmenuju?", "co tím myslíš?", "je mi tu smutno", "můžeme si sednout a dát čaj?", "kde je Panda?"]:
			npc.current_phase = 0
			npc.phase_1_message_count = 0
			var previous_respect: int = global.get(who + "_respect")
			var previous_irritation: int = global.get(who + "_irritation")
			if not await _send(npc, text):
				_finish()
				return
			var row: Dictionary = rows[-1]
			var reply: String = row.reply.to_lower()
			_check(not row.filtered, "Quality samples must be generated replies, not a safety fallback")
			if text == "cau)":
				_check(_contains_any(reply, ["ahoj", "čau", "cau", "zdravím"]), "A greeting should get a greeting")
			if text == "nevim jak se maš":
				_check(_contains_any(reply, ["dobř", "dobr", "ujde", "klid", "cítím", "daří", "mám se", "špatně", "unaven", "nálad", "výborn", "skvě", "spokojen", "báječ", "sám", "fajn", "pohod"]), "How are you should receive an answer about the NPC's state")
				_check(int(global.get(who + "_respect")) >= previous_respect and int(global.get(who + "_irritation")) <= previous_irritation, "Confusion and an ordinary question must not be treated as an insult")
			if text == "jak se jmenuju?":
				_check(reply.contains("roman") and not reply.contains("jsem roman"), "The NPC must recall the player's name without adopting it")
			if text == "je mi tu smutno":
				_check(_contains_any(reply, ["mrzí", "líto", "chápu", "rozumím", "sám", "samot", "těž", "poví", "poslouch", "smut", "tráp"]), "Sadness should receive a relevant response")
			if text == "kde je Panda?":
				var correct_place := reply.contains("sever") and not _contains_any(reply, ["severových", "severozáp"]) and _contains_any(reply, ["ruin", "chrám", "bambus"])
				_check(correct_place or (who == "panda" and _contains_any(reply, ["jsem tady", "jsem přímo tady", "před tebou"])), "Directions must agree with the actual island or identify the Panda you are speaking to")
			_check(not npc.quest_was_given and not npc.quest_reward_given, "Ordinary conversation cannot create quests or rewards")
	_finish()


func _contains_any(value: String, fragments: Array) -> bool:
	for fragment: String in fragments:
		if value.contains(fragment):
			return true
	return false
