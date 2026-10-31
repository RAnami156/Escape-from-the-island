extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _press_f(character: String, repeated: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.physical_keycode = KEY_F
	event.unicode = character.unicode_at(0)
	event.pressed = true
	event.echo = repeated
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_F
	release.physical_keycode = KEY_F
	Input.parse_input_event(release)


func _run() -> void:
	var globals: Node = root.get_node("Global")
	var saves: Node = root.get_node("SaveGame")
	# Disable saving and AI: test only real UI event routing in both Main variants.
	saves.save_path = "user://input-regression-unused/slot.json"
	node_added.connect(func(node: Node) -> void:
		if node.name == "guide_npc":
			node.auto_introduction = false
	)
	for language: String in ["cz", "ru"]:
		globals.language = language
		change_scene_to_file("res://scene/main.tscn")
		await scene_changed
		saves._autosave_left = 3600.0
		await process_frame
		var guide: Node = current_scene.get_node("guide_npc")
		var character := "f" if language == "cz" else "а"
		for path: String in ["bong", "flycather", "panda"]:
			guide.close_chat()
			var npc: Node = current_scene.get_node(path)
			npc._on_area_2d_body_entered(globals.player)
			var field: LineEdit = npc.get_node("CanvasLayer/text_ui/LineEdit")
			field.text = "test"
			field.grab_focus()
			field.caret_column = field.text.length()
			_check(field.has_focus(), "%s %s: NPC field focused before typing" % [language, path])
			await _press_f(character)
			_check(field.has_focus(), "%s %s: F must keep NPC input focus" % [language, path])
			_check(not guide.chat_panel.visible, "%s %s: typing F must not open Michael" % [language, path])
			_check(field.text == "test" + character, "%s %s: F must insert the active keyboard layout's character" % [language, path])
			await _press_f(character, true)
			_check(field.text == "test" + character + character, "%s %s: held F must remain normal text input" % [language, path])
			npc._on_area_2d_body_exited(globals.player)
			field.release_focus()
		guide.close_chat()
		await _press_f(character)
		_check(guide.chat_panel.visible and guide.input.has_focus(), "%s: F outside a text field must still open Michael" % language)
		_check(guide.input.text.is_empty(), "%s: shortcut must not insert a stray F into Michael's chat" % language)
		await _press_f(character)
		_check(guide.input.text == character and guide.input.has_focus(), "%s: F inside Michael's chat must also type normally" % language)
		guide.close_chat()
		var multiline := TextEdit.new()
		current_scene.add_child(multiline)
		multiline.size = Vector2(300, 100)
		multiline.grab_focus()
		await _press_f(character)
		_check(multiline.has_focus() and multiline.text == character and not guide.chat_panel.visible, "%s: multiline text editors must also keep F" % language)
		multiline.queue_free()
		await process_frame
	print("GUIDE_CHAT_INPUT_TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
