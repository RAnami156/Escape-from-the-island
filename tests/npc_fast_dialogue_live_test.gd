extends SceneTree

# Run explicitly against local Ollama. Does not write persistent game saves.
const Fast = preload("res://script/npc_fast_dialogue.gd")
var failures := 0
var samples: Array[Dictionary] = []
var global: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _send(npc: Node, language: String, message: String) -> bool:
	var previous: int = npc.dialogue_history.size()
	var started := Time.get_ticks_msec()
	npc.send_message_to_ai(message)
	while Time.get_ticks_msec() - started < 15000:
		if npc.dialogue_history.size() > previous and not npc.waiting_for_response and npc.text.visible_characters == -1:
			var elapsed := Time.get_ticks_msec() - started
			var row := {
				"language": language, "npc": Fast.kind(npc), "phase": int(npc.current_phase),
				"wall_ms": elapsed, "metrics": npc.get_meta("fast_metrics", {}),
				"input": message, "reply": npc.text.text,
			}
			samples.append(row)
			print("NPC_PERF ", JSON.stringify(row))
			_check(not npc.text.text.is_empty() and not npc.text.text.contains('"d":'), "Only spoken text must reach the unchanged UI")
			if language == "cz":
				var cyrillic := RegEx.new()
				cyrillic.compile("[А-Яа-яЁё]")
				_check(cyrillic.search(npc.text.text) == null, "Czech replies must stay Czech")
			await process_frame
			return true
		await create_timer(0.005).timeout
	_check(false, "Local Ollama timed out for " + Fast.kind(npc) + " HTTP status=" + str(npc.http_request.get_http_client_status()))
	return false


func _run() -> void:
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
			var item := "book" if who == "panda" else ("fly" if who == "flycatcher" else "whiskey")
			var reward := "bamboo_boards" if who == "panda" else ("parus" if who == "flycatcher" else "helm")
			global.set(item, false)
			global.set(reward, false)
			global.player_position = npc.global_position + Vector2(0, 105)
			npc.get_node("Area2D").body_entered.emit(global.player)
			var messages: Array[String] = []
			if language == "ru":
				messages = ["Привет! Как тебя зовут?", "Я пережил крушение самолёта. Голова ещё немного гудит.", "Ты давно живёшь на острове?", "Да, я хочу выбратьраться с острова.", "Не знаю, я пока не придумал смешного ответа." if who == "panda" else ("Ты красивая и умная, я обожаю мух." if who == "flycatcher" else "Лучше признать ошибку и исправить её, чем упрямо спорить.")]
			else:
				messages = ["Ahoj! Jak se jmenuješ?", "Přežil jsem havárii letadla. Ještě mě trochu bolí hlava.", "Žiješ na ostrově už dlouho?", "Ano, chci se dostat z ostrova.", "Nevím, zatím mě nenapadla vtipná odpověď." if who == "panda" else ("Jsi krásná a chytrá, miluju mouchy." if who == "flycatcher" else "Je lepší přiznat chybu a napravit ji než se tvrdohlavě hádat.")]
			for message: String in messages:
				if not await _send(npc, language, message):
					_save_and_quit()
					return
			_check(npc.current_phase == 4 and npc.quest_was_given, "Real conversation must reach the item-search phase")
			if who == "panda":
				_check(npc.last_humor_score < 7 and npc.quest_location_type == 1, "A plain admission of having no joke must not pass the humor test")
			global.set(item, true)
			if not await _send(npc, language, "Našel jsem to a přinesl ti to." if language == "cz" else "Я нашёл предмет и принёс тебе."):
				_save_and_quit()
				return
			_check(npc.current_phase == 6 and global.get(reward) and not global.get(item), "Real Ollama grading must preserve the original reward exchange")
			if not await _send(npc, language, "Děkuju. Znáš ostatní obyvatele ostrova?" if language == "cz" else "Спасибо. Ты знаешь остальных обитателей острова?"):
				_save_and_quit()
				return
			_check(npc.current_phase == 6, "Conversation must continue after the quest")
			npc.get_node("Area2D").body_exited.emit(global.player)
		root.remove_child(main)
		main.free()
		current_scene = null
	_save_and_quit()


func _save_and_quit() -> void:
	var durations: Array[int] = []
	var over_target := 0
	var total := 0
	for row: Dictionary in samples:
		durations.append(int(row.wall_ms))
		total += int(row.wall_ms)
		if row.wall_ms > 2000:
			over_target += 1
	durations.sort()
	var summary := {"samples": samples.size(), "failures": failures, "over_2000_ms": over_target,
		"mean_ms": total / maxi(1, samples.size()), "max_ms": durations[-1] if not durations.is_empty() else 0}
	var file := FileAccess.open("res://tests/_npc_fast_live_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary": summary, "samples": samples}, "\t"))
	file.close()
	print("FAST_NPC_SUMMARY ", JSON.stringify(summary))
	quit(0 if failures == 0 else 1)
