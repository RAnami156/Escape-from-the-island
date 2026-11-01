extends SceneTree

const Fast = preload("res://script/npc_fast_dialogue.gd")
var failures := 0
var rows: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _send(npc: Node, text: String) -> bool:
	var count: int = npc.dialogue_history.size()
	var started := Time.get_ticks_msec()
	npc.send_message_to_ai(text)
	while (npc.dialogue_history.size() == count or npc.waiting_for_response or npc.text.visible_characters != -1) and Time.get_ticks_msec() - started < 20000:
		await create_timer(0.01).timeout
	if npc.dialogue_history.size() == count:
		_check(false, "No completed reply: " + Fast.kind(npc) + " / " + text)
		return false
	var row := {"npc": Fast.kind(npc), "input": text, "reply": npc.text.text.replace("\n", " "), "ms": Time.get_ticks_msec() - started, "metrics": npc.get_meta("fast_metrics", {}), "phase": int(npc.current_phase), "filtered": npc.get_meta("fast_reply_filtered", false)}
	rows.append(row)
	print("CZECH_LIVE ", JSON.stringify(row))
	_check(not row.reply.is_empty() and Fast.reply_violations(row.reply, true).is_empty(), "Only a valid Czech spoken line reaches UI")
	return true


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
		var who := Fast.kind(npc)
		var item: String = {"bong": "whiskey", "panda": "book", "flycatcher": "fly"}[who]
		var reward: String = {"bong": "helm", "panda": "bamboo_boards", "flycatcher": "parus"}[who]
		for text: String in ["ahoj", "cooo", "Jak vypadám?", "Ano, chci odejít z ostrova.", "Nevím, zatím mě nenapadla vtipná odpověď." if who == "panda" else ("Jsi krásná, miluju mouchy." if who == "flycatcher" else "Je lepší přiznat chybu a napravit ji.")]:
			if not await _send(npc, text):
				_finish()
				return
		_check(npc.current_phase == 4 and npc.quest_was_given, "Original quest flow reaches the item search")
		if who == "panda":
			_check(npc.last_humor_score < 7 and npc.quest_location_type == 1, "A non-joke must not win the short book route")
		global.set(item, true)
		if not await _send(npc, "Našel jsem to a přinesl ti to."):
			_finish()
			return
		_check(npc.current_phase == 6 and npc.quest_reward_given and global.get(reward) and not global.get(item), "Original reward exchange is preserved")
		for text: String in ["Jak vypadám?", "Chceš si sednout a dát čaj?", "Dej mi další úkol.", "Děkuju."]:
			if not await _send(npc, text):
				_finish()
				return
	_finish()


func _finish() -> void:
	var comparable: Array = rows.filter(func(row: Dictionary) -> bool: return row.input in ["ahoj", "cooo"])
	var total := 0
	for row: Dictionary in comparable:
		total += int(row.ms)
	var summary := {"samples": rows.size(), "failures": failures, "greeting_clarification_mean_ms": total / maxi(1, comparable.size())}
	var report_path := "user://npc-czech-live-results.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary": summary, "samples": rows}, "\t"))
	file.close()
	print("CZECH_LIVE_SUMMARY ", JSON.stringify(summary))
	quit(0 if failures == 0 else 1)
