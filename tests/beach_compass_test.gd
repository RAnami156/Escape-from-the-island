extends SceneTree

var checks := 0
var failures := 0
var globals: Node
var saves: Node
var slot_directory := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	globals = root.get_node("Global")
	saves = root.get_node("SaveGame")
	slot_directory = "res://.godot/compass-tests-%d" % Time.get_ticks_usec()
	saves.save_path = slot_directory + "/slot.json"
	node_added.connect(func(node: Node) -> void:
		if node.name == "guide_npc":
			node.auto_introduction = false
	)
	for language: String in ["ru", "cz"]:
		globals.language = language
		change_scene_to_file("res://scene/main.tscn")
		await scene_changed
		await physics_frame
		await physics_frame
		var quest: Node = current_scene.get_node("BeachCompass")
		saves._autosave_left = 999999.0
		_check(not globals.compass_found and not globals.compass_chest_opened, "Fresh game starts with closed chest")
		# Check the actual physics world, including the aircraft's polygon.
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 10.0
		query.shape = shape
		query.collision_mask = globals.player.collision_mask
		query.transform = Transform2D(0.0, quest.global_position + Vector2(0, 28))
		query.exclude = [globals.player.get_rid()]
		_check(globals.player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "Player can stand in front of the chest")
		globals.player_position = quest.global_position + Vector2(0, 28)
		await physics_frame
		await _key(KEY_E)
		_check(quest.active and not globals.player_can_move, "E opens the lock and stops movement")
		var locked_position: Vector2 = globals.player.global_position
		# The flycatcher's search phase also writes the shared movement flag.
		current_scene.get_node("flycather").current_phase = 4
		Input.action_press("D")
		for frame in 4:
			await physics_frame
			await process_frame
		Input.action_release("D")
		_check(globals.player.global_position.is_equal_approx(locked_position) and not globals.player.is_physics_processing(), "Held movement stays blocked even during another ongoing quest")
		current_scene.get_node("flycather").current_phase = 0
		await _key(KEY_F)
		_check(not current_scene.get_node("guide_npc").chat_panel.visible, "Chat shortcut cannot interrupt the puzzle")
		quest.cooldown = 0.0
		quest.cursor = 0.0
		await _key(KEY_SPACE)
		_check(quest.hits == 0 and quest.active and not globals.compass_chest_opened, "A miss leaves the chest closed and permits retry")
		quest.cooldown = 0.0
		quest.cursor = quest.target_center
		await _key(KEY_E)
		_check(quest.hits == 1 and quest.active, "First real input opens one latch only")
		quest.cooldown = 0.0
		quest.cursor = 0.0
		await _key(KEY_E)
		_check(quest.hits == 1 and quest.active, "Miss after success preserves the opened latch")
		await _key(KEY_ESCAPE)
		_check(not quest.active and globals.player_can_move and not paused, "Esc closes puzzle without opening pause menu or trapping the player")
		_check(globals.player.is_physics_processing(), "Cancelling restores the player's physics processing")
		await _key(KEY_E)
		_check(quest.active and quest.hits == 0, "A cancelled puzzle can be restarted")
		await _key(KEY_TAB)
		_check(not quest.active and globals.player_can_move and paused, "Tab safely hands control to settings")
		await _key(KEY_TAB)
		_check(not paused, "Settings can close normally")
		await _key(KEY_E)
		for index in 2:
			quest.cooldown = 0.0
			quest.cursor = quest.target_center
			await _key(KEY_SPACE)
		_check(globals.compass_chest_opened and not globals.compass_found and not quest.active and globals.player_can_move, "Two hits open the chest and reveal a separate pickup")
		_check(saves.has_save(), "Opening the chest saves immediately")
		_check(saves.load_game(), "Open chest can be loaded before picking up compass")
		await scene_changed
		quest = current_scene.get_node("BeachCompass")
		_check(globals.compass_chest_opened and not globals.compass_found and not quest.active, "Load restores the open chest with compass still inside")
		await _key(KEY_E)
		_check(globals.compass_found and globals.player_can_move, "E picks up the compass")
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.save_path))
		_check(saved.globals.compass_found and saved.globals.compass_chest_opened, "Pickup is durably saved")
		var kong: Node2D = current_scene.get_node("bong")
		globals.player_position = kong.global_position + Vector2(300, 0)
		_check(quest.target_offset().normalized().is_equal_approx(Vector2.LEFT), "Compass points left when Kong is west")
		for facing: String in ["top", "down", "left", "rigth"]:
			globals.player.last_direction = facing
			_check(Vector2.from_angle(quest.compass_bearing()).is_equal_approx(Vector2.LEFT), "A westward target stays left while the player faces " + facing)
		for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			globals.player_position = kong.global_position - offset * 300.0
			_check(Vector2.from_angle(quest.compass_bearing()).is_equal_approx(offset), "Needle points to Kong in screen direction " + str(offset))
		globals.player_position = kong.global_position + Vector2(0, -300)
		_check(quest.target_offset().normalized().is_equal_approx(Vector2.DOWN), "Compass points down when Kong is south")
		globals.player_position = quest.global_position + Vector2(100, 80)
		Input.action_press("A")
		await create_timer(0.15).timeout
		_check(quest.moving_toward_kong(), "Actual movement toward Kong turns the needle green")
		Input.action_release("A")
		Input.action_press("D")
		await create_timer(0.15).timeout
		_check(not quest.moving_toward_kong(), "Actual movement away from Kong turns the needle red")
		Input.action_release("D")
		Input.action_press("W")
		await create_timer(0.15).timeout
		_check(not quest.moving_toward_kong(), "Moving up away from a target below stays red")
		Input.action_release("W")
		Input.action_press("S")
		await create_timer(0.15).timeout
		_check(quest.moving_toward_kong(), "Moving down toward a target below turns green")
		globals.player.set_physics_process(false)
		_check(not quest.moving_toward_kong(), "A movement lock cannot leave a stale green needle")
		globals.player.set_physics_process(true)
		Input.action_release("S")
		await physics_frame
		await process_frame
		await create_timer(0.15).timeout
		_check(not quest.moving_toward_kong(), "Standing still is red regardless of the character's facing")
		_check(absf(angle_difference(quest.compass_angle, quest.compass_bearing())) < 0.001, "Displayed needle matches the actual screen bearing")
		_check(saves.load_game(), "Collected compass save loads")
		await scene_changed
		quest = current_scene.get_node("BeachCompass")
		_check(globals.compass_found and globals.compass_chest_opened, "Collected compass persists across scene reload")
		_check(Vector2.from_angle(quest.compass_bearing()).is_equal_approx(quest.target_offset().normalized()), "Loaded compass points to Kong regardless of saved player facing")
		await _key(KEY_E)
		_check(not quest.active, "Collected compass cannot reopen the puzzle")
		# Exercise the old save format with the new optional fields missing.
		saved.globals.erase("compass_found")
		saved.globals.erase("compass_chest_opened")
		var legacy_path := slot_directory + "/legacy.json"
		var legacy := FileAccess.open(legacy_path, FileAccess.WRITE)
		legacy.store_string(JSON.stringify(saved))
		legacy.close()
		_check(not saves._read_file(legacy_path).is_empty(), "Existing saves without compass fields remain valid")
		saves.save_path = legacy_path
		_check(saves.load_game(), "Legacy save can actually be loaded")
		await scene_changed
		_check(not globals.compass_found and not globals.compass_chest_opened, "Legacy saves default to an unopened chest")
		saves.save_path = slot_directory + "/slot.json"
	# This test creates and removes only its own isolated workspace slot.
	for file: String in DirAccess.get_files_at(slot_directory):
		DirAccess.remove_absolute(slot_directory.path_join(file))
	DirAccess.remove_absolute(slot_directory)
	print("BEACH_COMPASS_TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
