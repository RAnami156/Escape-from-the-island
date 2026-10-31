extends Control

@onready var language_option: OptionButton = %OptionButton

var _settings_tween: Tween
var _new_game_confirmation: ConfirmationDialog


func _ready() -> void:
	preload("res://script/npc_fast_dialogue.gd").warm_up(self)
	language_option.select(1 if Global.language == "cz" else 0)
	%AdvancedToggle.set_pressed_no_signal(Global.advanced_settings_enabled)
	_localize()
	$ContinueButton.disabled = not SaveGame.has_save()
	if $ContinueButton.disabled:
		$play.grab_focus()
	else:
		$ContinueButton.grab_focus()
	$ContinueButton.pressed.connect(_on_continue_pressed)
	_new_game_confirmation = ConfirmationDialog.new()
	add_child(_new_game_confirmation)
	_new_game_confirmation.confirmed.connect(SaveGame.new_game)


func _on_option_button_item_selected(index: int) -> void:
	Global.language = "cz" if index == 1 else "ru"
	_localize()


func _localize() -> void:
	var cz := Global.language == "cz"
	$play.text = "Nová hra" if cz else "Новая игра"
	$ContinueButton.text = "Pokračovat" if cz else "Продолжить"
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
	if not SaveGame.has_save():
		SaveGame.new_game()
		return
	var cz := Global.language == "cz"
	_new_game_confirmation.title = "Nová hra" if cz else "Новая игра"
	_new_game_confirmation.dialog_text = "Nová hra nahradí dosavadní uložený postup. Začít znovu?" if cz else "Новая игра заменит сохранённый прогресс. Начать заново?"
	_new_game_confirmation.ok_button_text = "Začít" if cz else "Начать"
	_new_game_confirmation.cancel_button_text = "Zrušit" if cz else "Отмена"
	_new_game_confirmation.popup_centered(Vector2i(640, 180))


func _on_continue_pressed() -> void:
	if not SaveGame.load_game():
		%AdvancedHint.text = SaveGame.last_error
