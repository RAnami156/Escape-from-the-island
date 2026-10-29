extends CanvasLayer
## Keep the loading screen up until the island resources and Ollama are ready.

const FastDialogue = preload("res://script/npc_fast_dialogue.gd")
const MENU := "res://scene/menu.tscn"
const SCENES := [MENU, "res://scene/start.tscn", "res://scene/main.tscn"]
const FADE_SECONDS := 0.35
const CONNECTION_GRACE_MS := 120000
const FIRST_RETRY_MS := 2000
const MAX_RETRY_MS := 8000
const RECOVERY_CHECK_SECONDS := 60.0

var _prepared_scenes: Dictionary = {}
var _loading := false
var _opening_menu := false
var _czech := true
var _loading_started_ms := 0
var _next_retry_ms := 0
var _retry_delay_ms := FIRST_RETRY_MS
var _automatic_retries := 0
var _recovery_timer: Timer


func _ready() -> void:
	_czech = Global.language == "cz"
	$Splash/Loading/Actions/Retry.text = "Zkusit znovu" if _czech else "Повторить"
	$Splash/Loading/Actions/Exit.text = "Konec" if _czech else "Выход"
	$Splash/Loading/Actions/Retry.pressed.connect(_begin_loading)
	$Splash/Loading/Actions/Exit.pressed.connect(func() -> void: get_tree().quit())
	_recovery_timer = Timer.new()
	_recovery_timer.name = "ConnectionRecovery"
	_recovery_timer.one_shot = true
	_recovery_timer.wait_time = RECOVERY_CHECK_SECONDS
	_recovery_timer.timeout.connect(_begin_loading)
	add_child(_recovery_timer)
	_begin_loading()


func _begin_loading() -> void:
	if _loading or _opening_menu:
		return
	_loading = true
	_recovery_timer.stop()
	_loading_started_ms = Time.get_ticks_msec()
	_next_retry_ms = 0
	_retry_delay_ms = FIRST_RETRY_MS
	_automatic_retries = 0
	$Splash/Loading/Actions.hide()
	$Splash/Loading/Track.show()
	$Splash/Loading/Status.modulate = Color.WHITE
	$Splash/Loading/Status.text = "Načítání ostrova…" if _czech else "Загружаем остров…"
	$Splash/Loading/Hint.text = ""
	for path: String in SCENES:
		if _prepared_scenes.has(path):
			continue
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or status == ResourceLoader.THREAD_LOAD_FAILED:
			var error := ResourceLoader.load_threaded_request(path, "PackedScene", true)
			if error != OK:
				_show_error("resources")
				return
	FastDialogue.warm_up(self)
	while is_inside_tree():
		var progress := _poll_resources()
		if progress < 0.0:
			_show_error("resources")
			return
		var ai_status := FastDialogue.warm_up_status()
		if ai_status.state == "error":
			if not _retry_connection(ai_status.error):
				_show_error(ai_status.error)
				return
		var resources_ready := _prepared_scenes.size() == SCENES.size()
		if resources_ready and ai_status.state == "ready":
			# Retain dependencies through Start and Main without instantiating NPCs early.
			Global.set_meta("startup_resources", _prepared_scenes)
			_loading = false
			_open_menu()
			return
		_update_loading_display(progress, resources_ready)
		await get_tree().process_frame


func _retry_connection(reason: String) -> bool:
	if not _is_connection_error(reason):
		return false
	var now := Time.get_ticks_msec()
	if now - _loading_started_ms >= CONNECTION_GRACE_MS:
		return false
	if _next_retry_ms == 0:
		_next_retry_ms = now + _retry_delay_ms
	elif now >= _next_retry_ms:
		_next_retry_ms = 0
		_retry_delay_ms = mini(MAX_RETRY_MS, _retry_delay_ms * 2)
		_automatic_retries += 1
		FastDialogue.warm_up(self)
	return true


func _is_connection_error(reason: String) -> bool:
	return reason == "unavailable" or reason == "timeout"


func _poll_resources() -> float:
	var total := 0.0
	for path: String in SCENES:
		if _prepared_scenes.has(path):
			total += 1.0
			continue
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return -1.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene: PackedScene = ResourceLoader.load_threaded_get(path)
			if scene == null:
				return -1.0
			_prepared_scenes[path] = scene
			total += 1.0
		elif not progress.is_empty():
			total += float(progress[0])
	return total / SCENES.size()


func _update_loading_display(progress: float, resources_ready: bool) -> void:
	var track: ColorRect = $Splash/Loading/Track
	var fill: ColorRect = $Splash/Loading/Track/Fill
	if resources_ready:
		$Splash/Loading/Status.text = "Příprava dialogů…" if _czech else "Готовим диалоги…"
		$Splash/Loading/Hint.text = "První spuštění může trvat o něco déle." if _czech else "Первый запуск может занять немного больше времени."
		# Ollama has no reliable load percentage: show motion instead of invented progress.
		fill.size.x = track.size.x * 0.22
		fill.position.x = (sin(Time.get_ticks_msec() * 0.0025) * 0.5 + 0.5) * (track.size.x - fill.size.x)
	else:
		fill.position.x = 0.0
		fill.size.x = track.size.x * progress


func _show_error(reason: String) -> void:
	_loading = false
	$Splash/Loading/Track.hide()
	var title := "Dialogy se nepodařilo připravit." if _czech else "Не удалось подготовить диалоги."
	var hint := "Zkontroluj Ollamu a zkus to znovu." if _czech else "Проверь Ollama и попробуй ещё раз."
	match reason:
		"unavailable":
			title = "Ollama není dostupná." if _czech else "Ollama недоступна."
			hint = "Zkontroluj, že běží Ollama. Připojení zkusíme automaticky." if _czech else "Проверь, что Ollama запущена. Подключимся автоматически."
		"model_missing":
			title = "Chybí model pro dialogy." if _czech else "Модель для диалогов не установлена."
			hint = "Nainstaluj qwen3:8b v Ollamě a zkus to znovu." if _czech else "Установи qwen3:8b в Ollama и попробуй ещё раз."
		"timeout":
			title = "Načítání dialogů trvá příliš dlouho." if _czech else "Загрузка диалогов заняла слишком много времени."
			hint = "Připojení zkusíme automaticky znovu." if _czech else "Проверим подключение снова автоматически."
		"resources":
			title = "Ostrov se nepodařilo načíst." if _czech else "Не удалось загрузить остров."
			hint = "Zkus to prosím znovu." if _czech else "Попробуй ещё раз."
	$Splash/Loading/Status.text = title
	$Splash/Loading/Hint.text = hint
	$Splash/Loading/Status.modulate = Color(0.93, 0.78, 0.64)
	$Splash/Loading/Actions.show()
	$Splash/Loading/Actions/Retry.grab_focus()
	if _is_connection_error(reason):
		# A stopped/starting service can recover without another click.
		_recovery_timer.start()


func _open_menu() -> void:
	_opening_menu = true
	$Splash/Loading/Status.text = "Vše je připraveno" if _czech else "Всё готово"
	$Splash/Loading/Hint.text = ""
	$Splash/Loading/Track/Fill.position.x = 0.0
	$Splash/Loading/Track/Fill.size.x = $Splash/Loading/Track.size.x
	var menu_scene: PackedScene = _prepared_scenes[MENU]
	var menu := menu_scene.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	get_tree().root.move_child(self, get_tree().root.get_child_count() - 1)
	var fade := create_tween()
	fade.tween_property($Splash, "modulate:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE)
	await fade.finished
	queue_free()


func _input(event: InputEvent) -> void:
	# Loading cannot be skipped; keep presses away from the menu during its reveal.
	if _opening_menu and event.is_pressed():
		get_viewport().set_input_as_handled()
