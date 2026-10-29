extends CanvasLayer

const FINAL_GOOD := "res://scene/final_leave.tscn"
const FINAL_BAD := "res://scene/final2_leave.tscn"

var _previous_focus: Control
var _transitioning := false


func _ready() -> void:
	_localize()
	_refresh_ship()


func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("tab"):
		if not visible and not Global.advanced_settings_enabled:
			return
		_set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("esc"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(is_open: bool) -> void:
	if is_open:
		_previous_focus = get_viewport().gui_get_focus_owner()
		_localize()
		_refresh_ship()
		%ActionStatus.text = ""
	visible = is_open
	get_tree().paused = is_open
	if is_open:
		%ResumeButton.grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused):
			focused.release_focus()
		if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
			_previous_focus.grab_focus()


func _exit_tree() -> void:
	if visible:
		get_tree().paused = false


func _t(ru: String, cz: String) -> String:
	return cz if Global.language == "cz" else ru


func _localize() -> void:
	%Title.text = _t("Меню", "Menu")
	%CloseButton.tooltip_text = _t("Закрыть · Esc", "Zavřít · Esc")
	%TeleportTitle.text = _t("Телепорт", "Teleport")
	%tp_bong.text = _t("Бонг", "Bong")
	%tp_panda.text = _t("Панда", "Panda")
	%tp_flycatcher.text = _t("Мухоловка", "Mucholapka")
	%tp_ship.text = _t("Корабль", "Loď")
	%tp_baobab.text = _t("Баобаб", "Baobab")
	%ShipTitle.text = _t("Лодка", "Loď")
	%RepairButton.text = _t("Починить всю лодку", "Opravit celou loď")
	%FinalTitle.text = _t("Катсцены", "Scény")
	%GoodFinalButton.text = _t("Хороший финал", "Dobrý konec")
	%BadFinalButton.text = _t("Плохой финал", "Špatný konec")
	%KeyboardHint.text = _t("Tab / Esc — закрыть", "Tab / Esc — zavřít")
	%ResumeButton.text = _t("Продолжить", "Pokračovat")


func _ship() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("ship") if scene != null else null


func _refresh_ship() -> void:
	var ship := _ship()
	if ship == null:
		%ShipStatus.text = _t("Лодка недоступна", "Loď není dostupná")
		%RepairButton.disabled = true
		return
	var repaired := int(ship.helm_repaired) + int(ship.sail_repaired) + int(ship.planks_repaired)
	%ShipStatus.text = _t("Лодка починена", "Loď je opravená") if repaired == 3 else _t("Починено: %d/3", "Opraveno: %d/3") % repaired
	%RepairButton.disabled = repaired == 3


func _teleport_to(path: NodePath, offset: Vector2, ru: String, cz: String) -> void:
	Global.teleport_player_to(path, offset)
	%ActionStatus.text = _t("Перемещение: ", "Přesun: ") + _t(ru, cz)


func _on_tp_bong_pressed() -> void:
	_teleport_to(^"bong", Vector2(0, 80), "Бонг", "Bong")


func _on_tp_panda_pressed() -> void:
	_teleport_to(^"panda", Vector2(0, 80), "Панда", "Panda")


func _on_tp_flycatcher_pressed() -> void:
	_teleport_to(^"flycather", Vector2(0, 80), "Мухоловка", "Mucholapka")


func _on_tp_ship_pressed() -> void:
	_teleport_to(^"ship", Vector2(-100, 0), "корабль", "loď")


func _on_tp_baobab_pressed() -> void:
	_teleport_to(^"structures/Baobab100_byRavan", Vector2(0, 160), "баобаб", "baobab")


func _on_repair_ship_pressed() -> void:
	var ship := _ship()
	if ship == null or not ship.has_method("repair_all"):
		%ActionStatus.text = _t("Корабль недоступен.", "Loď není dostupná.")
		return
	ship.repair_all()
	_refresh_ship()
	%ActionStatus.text = _t("Лодка полностью починена. Можно отплывать!", "Loď je kompletně opravená. Můžeme vyplout!")


func _on_resume_pressed() -> void:
	_set_open(false)


func _on_final_good_pressed() -> void:
	_play_final(FINAL_GOOD)


func _on_final_bad_pressed() -> void:
	_play_final(FINAL_BAD)


func _play_final(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	_set_open(false)
	Global.player_can_move = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_transitioning = false
		_set_open(true)
		%ActionStatus.text = _t("Не удалось открыть катсцену.", "Scénu se nepodařilo otevřít.")
