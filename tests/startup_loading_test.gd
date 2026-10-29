extends SceneTree

const Fast = preload("res://script/npc_fast_dialogue.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	# Passive prewarming is disabled headlessly. Complete requests explicitly to
	# exercise slow loading, errors and recovery without a real model or network.
	for language: String in ["ru", "cz"]:
		root.get_node("Global").language = language
		Fast._warmup_state = "loading"
		Fast._warmup_error = ""
		var intro: Node = load("res://scene/ranami_intro.tscn").instantiate()
		root.add_child(intro)
		current_scene = intro
		var started := Time.get_ticks_msec()
		while intro._prepared_scenes.size() < 3 and Time.get_ticks_msec() - started < 5000:
			await create_timer(0.01).timeout
		_check(intro._prepared_scenes.size() == 3, "All startup scenes must finish loading")
		for key in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			var press := InputEventKey.new()
			press.keycode = key
			press.pressed = true
			Input.parse_input_event(press)
			await process_frame
		_check(current_scene == intro and not intro._opening_menu, "Input must not bypass model loading")
		var status: String = intro.get_node("Splash/Loading/Status").text
		_check(status == ("Příprava dialogů…" if language == "cz" else "Готовим диалоги…"), "Loading must use the selected language")
		# Transient startup failures keep the loading screen, then retry unaided.
		Fast._finish_warm_up(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
		await process_frame
		await process_frame
		_check(current_scene == intro and intro._loading and not intro.get_node("Splash/Loading/Actions").visible, "A first connection failure must keep normal loading, not show an error")
		intro._next_retry_ms = Time.get_ticks_msec()
		await process_frame
		await process_frame
		_check(intro._automatic_retries == 1 and intro._loading, "Connection must retry automatically without pressing Retry")
		# A genuinely unavailable service still exposes actions after the grace period.
		intro._loading_started_ms = Time.get_ticks_msec() - intro.CONNECTION_GRACE_MS
		await process_frame
		await process_frame
		_check(current_scene == intro and intro.get_node("Splash/Loading/Actions").visible, "Connection failure must show Retry and keep the loading screen")
		_check(not intro._recovery_timer.is_stopped(), "Unavailable service must schedule recovery checks automatically")
		_check(intro.get_node("Splash/Loading/Actions/Retry").text == ("Zkusit znovu" if language == "cz" else "Повторить"), "Retry must be localized")
		Fast._warmup_state = "loading"
		Fast._warmup_error = ""
		# The minute timer must recover without needing the Retry button either.
		intro._recovery_timer.timeout.emit()
		await process_frame
		_check(intro._loading and not intro.get_node("Splash/Loading/Actions").visible, "Automatic recovery must resume loading")
		_check(intro._recovery_timer.is_stopped(), "A new attempt must cancel the old recovery timer")
		Fast._finish_warm_up(HTTPRequest.RESULT_SUCCESS, 200, "{\"done\":true}".to_utf8_buffer())
		await process_frame
		await process_frame
		_check(current_scene == intro and Fast.warm_up_status().state == "error", "HTTP 200 without a real generated reply is not ready")
		Fast._finish_warm_up(HTTPRequest.RESULT_SUCCESS, 404, PackedByteArray())
		_check(Fast.warm_up_status().error == "model_missing", "Missing model must have an actionable failure")
		Fast._finish_warm_up(HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())
		_check(Fast.warm_up_status().error == "timeout", "Timeout must not be treated as ready")
		Fast._warmup_state = "loading"
		Fast._warmup_error = ""
		intro.get_node("Splash/Loading/Actions/Retry").pressed.emit()
		var success := JSON.stringify({"done": true, "message": {"role": "assistant", "content": "OK"}, "eval_count": 1})
		Fast._finish_warm_up(HTTPRequest.RESULT_SUCCESS, 200, success.to_utf8_buffer())
		await create_timer(0.5).timeout
		_check(current_scene.scene_file_path == "res://scene/menu.tscn", "The menu opens only after resources AND a successful warmup")
		_check(root.get_node("Global").get_meta("startup_resources").size() == 3, "Preloaded resources must remain retained after the intro is freed")
		current_scene.get_node("play").pressed.emit()
		await scene_changed
		_check(current_scene.scene_file_path == "res://scene/start.tscn", "The airplane cutscene must still follow Play")
		var finished := current_scene
		current_scene = null
		root.remove_child(finished)
		finished.free()
	print("Startup loading: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
