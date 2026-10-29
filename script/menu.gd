extends Control

@onready var language_option: OptionButton = %OptionButton

var _settings_tween: Tween


func _ready() -> void:
	language_option.select(1 if Global.language == "cz" else 0)
	%AdvancedToggle.set_pressed_no_signal(Global.advanced_settings_enabled)
	_localize()
	$play.grab_focus()


func _on_option_button_item_selected(index: int) -> void:
	Global.language = "cz" if index == 1 else "ru"
	_localize()


func _localize() -> void:
	var cz := Global.language == "cz"
	$play.text = "Hrát" if cz else "Играть"
	$exit.text = "Konec" if cz else "Выход"
	$SettingsButton.text = "Nastavení" if cz else "Настройки"
	%SettingsTitle.text = "Nastavení" if cz else "Настройки"
	%CloseSettings.tooltip_text = "Zavřít · Esc" if cz else "Закрыть · Esc"
	%LanguageLabel.text = "Jazyk" if cz else "Язык"
	%AdvancedToggle.text = "Rozšířená nastavení" if cz else "Расширенные настройки"
	%AdvancedToggle.tooltip_text = "Nabídka ve hře klávesou Tab" if cz else "Меню в игре по клавише Tab"
	%AdvancedHint.text = "Tab — herní nabídka" if cz else "Tab — меню в игре"


func _on_advanced_toggled(enabled: bool) -> void:
	Global.advanced_settings_enabled = enabled


func _on_settings_pressed() -> void:
	_set_settings_open(not $SettingsPanel.visible)


func _on_close_settings_pressed() -> void:
	_set_settings_open(false)


func _set_settings_open(is_open: bool) -> void:
	if _settings_tween != null:
		_settings_tween.kill()
	$SettingsPanel.visible = is_open
	if is_open:
		$SettingsPanel.modulate.a = 0.0
		_settings_tween = create_tween()
		_settings_tween.tween_property($SettingsPanel, "modulate:a", 1.0, 0.16)
		language_option.grab_focus()
	else:
		$SettingsButton.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		get_viewport().set_input_as_handled()
		if $SettingsPanel.visible:
			_set_settings_open(false)
		else:
			get_tree().quit()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_play_pressed() -> void:
	get_tree().paused = false
	Global.player_can_move = true
	get_tree().change_scene_to_file("res://scene/start.tscn")
