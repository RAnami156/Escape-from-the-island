extends SceneTree

var failures := 0
var checks := 0
var saves: Node
var globals: Node
var test_directory := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = keycode
	Input.parse_input_event(event)


func _run() -> void:
	saves = root.get_node("SaveGame")
	globals = root.get_node("Global")
	test_directory = "user://save-tests-%d" % Time.get_ticks_usec()
	saves.save_path = test_directory + "/slot.json"
	# No live AI requests: exercise the actual scenes and durable state in isolation.
	node_added.connect(func(node: Node) -> void:
		if node.name == "guide_npc":
			node.auto_introduction = false
	)
	_check(not saves.has_save(), "Fresh slot must be empty")
	_check(not saves.load_game(), "Missing slot must fail without changing scenes")
	for language: String in ["cz", "ru"]:
		globals.language = language
		change_scene_to_file("res://scene/main.tscn")
		await scene_changed
		await process_frame
		var scene := current_scene
		var guide: Node = scene.get_node("guide_npc")
		globals.player_position = Vector2(4200, 3300)
		globals.bong_friendship = 73
		globals.flycatcher_respect = 14
		globals.panda_deal = 42
		globals.book = true
		globals.parus = true
		var bong: Node = scene.get_node("bong")
		bong.current_phase = 4
		bong.quest_was_given = true
		bong.quest_location_type = 2
		bong.quest_location = "Test original destination"
		bong.phase_1_message_count = 2
		bong.conversation_history.assign([{"role": "user", "content": "Ahoj"}, {"role": "assistant", "content": "Ahoj, trosečníku."}])
		bong.dialogue_history.assign([{"player": "Ahoj", "npc": "Ahoj, trosečníku."}])
		bong.dialogue_history_index = 0
		var fly: Node = scene.get_node("flycather")
		fly.current_phase = 6
		fly.quest_was_given = true
		fly.quest_reward_given = true
		var panda: Node = scene.get_node("panda")
		panda.current_phase = 4
		panda.quest_was_given = true
		panda.selected_question = "Saved question"
		guide.current_phase = 1
		guide.player_name = "Roman"
		guide._has_met_player = true
		guide._introduction_started = true
		guide.conversation_history.assign([{"role": "assistant", "content": "Jmenuji se Michael."}])
		guide.global_position = Vector2(4210, 3310)
		var ship: Node = scene.get_node("ship")
		ship.helm_repaired = true
		_check(saves.save_game(), "Save succeeds for " + language)
		_check(saves.has_save(), "Written JSON validates for " + language)
		if not saves.has_save():
			quit(1)
			return
		var original := FileAccess.get_file_as_string(saves.save_path)
		bong.waiting_for_response = true
		_check(not saves.save_game(), "In-flight quest reply cannot be saved")
		_check(FileAccess.get_file_as_string(saves.save_path) == original, "Busy save leaves slot untouched")
		bong.waiting_for_response = false
		_check(saves.save_game(), "Replacing an existing slot succeeds")
		_check(FileAccess.file_exists(saves.save_path + ".bak"), "Previous slot is backed up")
		globals.player_position = Vector2.ZERO
		globals.book = false
		globals.bong_friendship = 0
		_check(saves.load_game(), "Continue starts scene transition")
		await scene_changed
		_check(globals.language == language, "Load restores saved language before NPC script selection")
		_check(globals.player_position.is_equal_approx(Vector2(4200, 3300)), "Load restores player coordinates")
		_check(globals.bong_friendship == 73 and globals.panda_deal == 42 and globals.flycatcher_respect == 14, "Relationships restored")
		_check(globals.book and globals.parus, "Inventory restored")
		scene = current_scene
		bong = scene.get_node("bong")
		fly = scene.get_node("flycather")
		panda = scene.get_node("panda")
		guide = scene.get_node("guide_npc")
		ship = scene.get_node("ship")
		_check(bong.current_phase == 4 and bong.quest_location_type == 2 and bong.quest_location == "Test original destination", "Quest state and destination restored")
		_check(bong.conversation_history.size() == 2 and bong.dialogue_history.size() == 1, "NPC conversation history restored")
		_check(is_instance_valid(bong.whiskey_instance), "Outstanding quest item respawned")
		_check(bong.whiskey_instance.global_position == bong.get_whiskey_spawn_position(), "Item stays at original authored coordinates")
		_check(not is_instance_valid(fly.fly_instance) and fly.quest_reward_given, "Completed quest does not respawn its item")
		_check(not is_instance_valid(panda.book_instance) and panda.selected_question == "Saved question", "Collected item is not duplicated")
		_check(ship.helm_repaired and ship.helm_anim.visible and not ship.ship_ready, "Partial boat repair and its visuals restored")
		_check(guide.player_name == "Roman" and guide._has_met_player and guide._introduction_started and guide.conversation_history.size() == 1, "Michael remembers saved acquaintance")
		_check(guide.global_position.is_equal_approx(Vector2(4210, 3310)), "Companion position restored")
		var pause_menu: Node = scene.get_node("PauseMenu")
		await _key(KEY_ESCAPE)
		_check(paused and pause_menu.panel.visible, "Esc menu pauses the game")
		_check(saves.save_game(), "Manual save works while paused")
		await _key(KEY_ESCAPE)
		_check(not paused and not pause_menu.panel.visible, "Resume unpauses")
		globals.bong_friendship = 81
		saves._autosave_left = 0.0
		await process_frame
		await process_frame
		var automatic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.save_path))
		_check(automatic.globals.bong_friendship == 81, "Autosave records current progress")
		globals.bong_friendship = 73
		await _key(KEY_F5)
		var quick: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.save_path))
		_check(quick.globals.bong_friendship == 73, "F5 saves current progress")
		globals.bong_friendship = 0
		# Call deferred input and await the actual scene replacement, not its next frame.
		var quick_load := InputEventKey.new()
		quick_load.physical_keycode = KEY_F9
		quick_load.pressed = true
		Input.parse_input_event(quick_load)
		await scene_changed
		_check(globals.bong_friendship == 73, "F9 restores the quick save")
		quick_load = InputEventKey.new()
		quick_load.physical_keycode = KEY_F9
		Input.parse_input_event(quick_load)
		# Broken primary falls back to the previous valid JSON, without throwing.
		var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.save_path + ".bak"))
		var file := FileAccess.open(saves.save_path, FileAccess.WRITE)
		file.store_string("{broken")
		file.close()
		_check(saves.has_save(), "Corrupt primary falls back to backup")
		_check(saves.load_game(), "Backup can be loaded")
		await scene_changed
		_check(globals.bong_friendship == int(backup.globals.bong_friendship), "Backup restores previous saved progress")
		_check(saves.save_game(), "A valid save repairs the damaged primary")
		var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.save_path))
		var invalid := valid.duplicate(true)
		invalid.npcs.bong.conversation_history = ["not a message dictionary"]
		_check(not saves._valid_save(invalid), "Malformed typed history rejected")
		invalid = valid.duplicate(true)
		invalid.version = 999
		_check(not saves._valid_save(invalid), "Unsupported format rejected")
		invalid = valid.duplicate(true)
		invalid.player.position = ["bad", 20]
		_check(not saves._valid_save(invalid), "Invalid coordinates rejected")
		# Actual menu localization and Continue button, with an existing slot.
		change_scene_to_file("res://scene/menu.tscn")
		await scene_changed
		_check(not current_scene.get_node("ContinueButton").disabled, "Continue available from menu")
		_check(current_scene.get_node("ContinueButton").text == ("Pokračovat" if language == "cz" else "Продолжить"), "Menu localized")
		current_scene.get_node("play").pressed.emit()
		_check(current_scene._new_game_confirmation.visible, "Existing progress is protected by new-game confirmation")
		current_scene._new_game_confirmation.hide()
		current_scene.get_node("ContinueButton").pressed.emit()
		await scene_changed
		_check(current_scene.scene_file_path == "res://scene/main.tscn", "Continue skips Start cutscene")
		current_scene.get_node("ship").repair_all()
		_check(saves.save_game(), "Fully repaired boat can be saved")
		_check(saves.load_game(), "Fully repaired boat can be loaded")
		await scene_changed
		_check(current_scene.get_node("ship").ship_ready and current_scene.get_node("ship").planks_anim.animation == &"fixed", "Full boat repair survives reload")
		saves.new_game()
		await scene_changed
		_check(current_scene.scene_file_path == "res://scene/start.tscn", "New game plays Start cutscene")
		current_scene._go_to_game()
		await scene_changed
		_check(globals.bong_friendship == 35 and not globals.book and not globals.parus, "New game resets inventory and relationships")
		_check(current_scene.get_node("bong").current_phase == 0 and not current_scene.get_node("ship").helm_repaired, "New game resets quests and boat")
		_check(current_scene.get_node("guide_npc").player_name.is_empty(), "New game resets Michael's memory")
	# Clean only this run's explicitly isolated files.
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(saves.save_path + suffix):
			DirAccess.remove_absolute(saves.save_path + suffix)
	DirAccess.remove_absolute(test_directory)
	print("SAVE_TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
