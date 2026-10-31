extends CanvasLayer

@onready var panel: Control = $Overlay
@onready var status: Label = $Overlay/Center/Panel/Content/Status
@onready var toast: Label = $Toast
var _toast_left := 0.0
var _previous_focus: Control


func _ready() -> void:
	SaveGame.status_changed.connect(_on_status)
	panel.hide()
	toast.hide()
	var content := $Overlay/Center/Panel/Content
	content.get_node("Resume").pressed.connect(close)
	content.get_node("Save").pressed.connect(func() -> void: SaveGame.save_game())
	content.get_node("Load").pressed.connect(func() -> void: SaveGame.load_game())
	content.get_node("Menu").pressed.connect(_save_and_menu)
	content.get_node("Quit").pressed.connect(_save_and_quit)
	_localize()


func _process(delta: float) -> void:
	if panel.visible:
		var busy := not SaveGame.can_save()
		for button: String in ["Save", "Menu", "Quit"]:
			$Overlay/Center/Panel/Content.get_node(button).disabled = busy
	_toast_left -= delta
	toast.visible = _toast_left > 0.0 and not panel.visible


func _input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("esc"):
		get_viewport().set_input_as_handled()
		close()
	elif panel.visible and event.is_action_pressed("tab"):
		get_viewport().set_input_as_handled()


func open() -> void:
	if get_tree().paused:
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	_localize()
	status.text = _t("Продолжи игру и дождись ответа NPC, затем сохрани.", "Pokračuj ve hře, počkej na odpověď NPC a pak hru ulož.") if not SaveGame.can_save() else ""
	$Overlay/Center/Panel/Content/Load.disabled = not SaveGame.has_save()
	panel.show()
	get_tree().paused = true
	$Overlay/Center/Panel/Content/Resume.grab_focus()


func close() -> void:
	panel.hide()
	get_tree().paused = false
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused):
		focused.release_focus()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()


func _exit_tree() -> void:
	if panel.visible:
		get_tree().paused = false


func _localize() -> void:
	var content := $Overlay/Center/Panel/Content
	content.get_node("Title").text = _t("Пауза", "Pauza")
	content.get_node("Resume").text = _t("Продолжить", "Pokračovat")
	content.get_node("Save").text = _t("Сохранить", "Uložit hru")
	content.get_node("Load").text = _t("Загрузить сохранение", "Načíst uloženou hru")
	content.get_node("Menu").text = _t("Сохранить и в меню", "Uložit a do menu")
	content.get_node("Quit").text = _t("Сохранить и выйти", "Uložit a ukončit")
	content.get_node("Hint").text = _t("F5 — сохранить · F9 — загрузить\nАвтосохранение раз в минуту", "F5 — uložit · F9 — načíst\nAutomatické uložení každou minutu")


func _save_and_menu() -> void:
	if SaveGame.save_game():
		close()
		get_tree().change_scene_to_file("res://scene/menu.tscn")


func _save_and_quit() -> void:
	if SaveGame.save_game():
		get_tree().quit()


func _on_status(message: String) -> void:
	status.text = message
	toast.text = message
	_toast_left = 3.5


func _t(ru: String, cz: String) -> String:
	return cz if Global.language == "cz" else ru
