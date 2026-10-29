extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventAction.new()
	event.action = action
	Input.parse_input_event(event)
	await process_frame
	await physics_frame


func _run() -> void:
	var global: Node = root.get_node("Global")
	change_scene_to_file("res://scene/menu.tscn")
	await scene_changed
	for language: String in ["ru", "cz"]:
		global.language = language
		current_scene.get_node("play").pressed.emit()
		await scene_changed
		_check(current_scene.scene_file_path == "res://scene/start.tscn", "Every Play must open Start")
		var intro: AnimationPlayer = current_scene.get_node("AnimationPlayer")
		_check(intro.is_playing() and intro.current_animation == "new_animation", "Start must play the airplane animation")
		_check(intro.current_animation_position < 0.5, "Every Play must restart the intro from the beginning")
		intro.advance(intro.current_animation_length + 0.1)
		await scene_changed
		_check(current_scene.scene_file_path == "res://scene/main.tscn", "Intro must finish in Main")
		current_scene.get_node("guide_npc").auto_introduction = false
		var main := current_scene
		var panel: CanvasLayer = main.get_node("advanced_settings")
		var ship: Node2D = main.get_node("ship")
		await _action(&"tab")
		_check(panel.visible and paused, "Tab must open the panel and pause gameplay")
		var title: Label = panel.get_node("%Title")
		_check(title.text == ("Menu" if language == "cz" else "Меню"), "Panel must use the selected language")
		var origin: Vector2 = global.player_position
		Input.action_press("D")
		for frame in 3:
			await physics_frame
		Input.action_release("D")
		_check(global.player_position.is_equal_approx(origin), "Player must stay still while the panel is open")
		global.helm = true
		global.parus = true
		global.bamboo_boards = true
		panel.get_node("%RepairButton").pressed.emit()
		_check(ship.ship_ready and ship.helm_repaired and ship.sail_repaired and ship.planks_repaired, "Repair button must repair every boat part")
		_check(ship.helm_anim.visible and ship.sail_anim.visible and ship.planks_anim.animation == &"fixed", "Full repair must update the boat visuals")
		_check(global.helm and global.parus and global.bamboo_boards, "Quick repair must not consume quest items")
		_check(panel.get_node("%RepairButton").disabled and panel.get_node("%ShipStatus").text == ("Loď je opravená" if language == "cz" else "Лодка починена"), "Panel must show a fully repaired boat")
		ship.repair_all()
		_check(ship.ship_ready, "Full repair must be safe to repeat")
		var destinations := [
			["%tp_bong", "bong", Vector2(0, 80)],
			["%tp_panda", "panda", Vector2(0, 80)],
			["%tp_flycatcher", "flycather", Vector2(0, 80)],
			["%tp_baobab", "structures/Baobab100_byRavan", Vector2(0, 160)],
			["%tp_ship", "ship", Vector2(-100, 0)],
		]
		for destination in destinations:
			panel.get_node(destination[0]).pressed.emit()
			var target: Node2D = main.get_node(destination[1])
			_check(global.player_position.is_equal_approx(target.global_position + destination[2]), "Teleport must keep its original destination: " + destination[1])
		_check(paused, "Teleport must keep the panel paused until it is closed")
		await _action(&"esc")
		_check(not panel.visible and not paused and current_scene == main, "Escape must close the panel without leaving Main")
		await _action(&"tab")
		panel.get_node("%CloseButton").pressed.emit()
		_check(not panel.visible and not paused, "Close button must resume gameplay")
		await _action(&"tab")
		panel.get_node("%ResumeButton").pressed.emit()
		_check(not panel.visible and not paused, "Resume button must resume gameplay")
		await _action(&"tab")
		var button: Button = panel.get_node("%GoodFinalButton" if language == "ru" else "%BadFinalButton")
		button.pressed.emit()
		await scene_changed
		var expected := "res://scene/final_leave.tscn" if language == "ru" else "res://scene/final2_leave.tscn"
		_check(current_scene.scene_file_path == expected and not paused, "Final preview must load the requested scene and clear pause")
		var ending: AnimationPlayer = current_scene.get_node("AnimationPlayer")
		_check(ending.is_playing() and ending.current_animation == ("new_animation" if language == "ru" else "new_animation_2"), "Each ending must play its correct animation")
		ending.advance(ending.current_animation_length + 0.1)
		await scene_changed
		_check(current_scene.scene_file_path == "res://scene/menu.tscn" and not paused, "Final preview must return to a usable menu")
	print("Advanced settings: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
