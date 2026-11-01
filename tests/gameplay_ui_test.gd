extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var global: Node = root.get_node("Global")
	root.get_node("SaveGame").save_path = "user://ui-regression-unused/slot.json"
	for language: String in ["cz", "ru"]:
		global.language = language
		var main: Node = load("res://scene/main.tscn").instantiate()
		main.get_node("guide_npc").auto_introduction = false
		root.add_child(main)
		current_scene = main
		root.get_node("SaveGame")._autosave_left = 999999.0
		for path: String in ["bong", "panda", "flycather"]:
			var ui: Node = main.get_node(path + "/CanvasLayer")
			var who: String = ui.npc_key
			ui.get_node("relationship").show()
			ui._process(0.0)
			_check(ui._change_rows[0].modulate.a == 0, "Opening relationship UI must not invent a change")
			var respect: int = global.get(who + "_respect")
			global.set(who + "_respect", respect + 10)
			var irritation: int = global.get(who + "_irritation")
			global.set(who + "_irritation", irritation + 5)
			ui._process(0.0)
			await create_timer(0.2).timeout
			var increase: Control = ui._change_rows[0]
			var irritated: Control = ui._change_rows[2]
			_check(increase.modulate.a > 0.8 and increase.get_node("Arrow").direction == 1 and increase.get_node("Amount").text == "+10", "Increase must show an animated upward arrow and exact delta")
			_check(increase.get_node("Arrow").modulate == ui.IMPROVED, "Respect increase is beneficial")
			_check(irritated.get_node("Arrow").direction == 1 and irritated.get_node("Arrow").modulate == ui.WORSENED, "Irritation increase must be an upward arrow with an adverse color")
			global.set(who + "_respect", respect)
			global.set(who + "_irritation", irritation - 3)
			ui._process(0.0)
			_check(increase.get_node("Arrow").direction == -1 and increase.get_node("Amount").text == "-10", "A rapid second change must replace the previous arrow")
			_check(irritated.get_node("Arrow").direction == -1 and irritated.get_node("Arrow").modulate == ui.IMPROVED, "Lower irritation must count as an improvement")
			ui.get_node("relationship").hide()
			global.set(who + "_respect", respect + 30)
			ui._process(0.0)
			ui.get_node("relationship").show()
			ui._process(0.0)
			_check(increase.modulate.a == 0, "Hidden changes and reopening must not replay stale feedback")
			_check(ui.get_node("relationship/respect_text_value").text == str(respect + 30), "Displayed values stay equal to actual game state")
			ui.get_node("relationship").hide()
		var ship: Node = main.get_node("ship")
		var ui: Node = ship.get_node("ShipUI")
		ui._process(0.0)
		_check(not ui._open, "Boat panel is hidden away from the boat")
		ship.helm = true
		ui._process(0.0)
		_check(ui._open and ui.panel.visible, "Entering a repair area opens the boat panel")
		_check(ui.content.get_node("Action/Text").text == ("Chybí kormidlo" if language == "cz" else "Нужен штурвал"), "Missing-part hint uses selected language")
		_check(ship.helm_text.modulate.a == 0 and ship.final_text.modulate.a == 0, "Old world-space labels do not overlap the new panel")
		global.helm = true
		ui._refresh()
		_check(ui.content.get_node("Parts/helm/State").text == ("Připraveno" if language == "cz" else "Есть деталь"), "Inventory availability is shown separately from installed state")
		ship.try_repair()
		ui._refresh()
		_check(ship.helm_repaired and not global.helm and ui.content.get_node("Header/Count").text == "1 / 3", "Normal repair still consumes its item and updates progress")
		_check(ui.content.get_node("Parts/helm/State").text == ("Opraveno" if language == "cz" else "Установлено"), "Installed state differs from inventory availability")
		ship.helm = false
		ship.sail = true
		global.parus = true
		ui._refresh()
		_check(ui.content.get_node("Action/Text").text == ("Nasadit plachtu" if language == "cz" else "Установить парус"), "Hint follows the active physical repair area")
		ship.repair_all()
		ui._refresh()
		_check(ship.ship_ready and ui.content.get_node("Header/Count").text == "3 / 3", "Debug repair also updates all progress indicators")
		_check(ui.content.get_node("Action/Text").text == ("Odplout z ostrova" if language == "cz" else "Отплыть с острова"), "Completed boat shows the original E departure action")
		main.free()
		current_scene = null
	print("GAMEPLAY_UI_TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
