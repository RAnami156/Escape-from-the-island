extends CharacterBody2D

signal reply_finished(reply: String, metrics: Dictionary)
signal observation_spoken(zone: String, reply: String)

const GuideClient = preload("res://script/guide_ollama_client.gd")
const AreaContext = preload("res://script/guide_area_context.gd")
const MAX_HISTORY_MESSAGES: int = 10
const MAX_INPUT_CHARACTERS: int = 280
const REFLECTION_SCHEMA: Dictionary = {
	"type": "object", "additionalProperties": false,
	"properties": {
		"intent": {"type": "string", "maxLength": 60},
		"reply": {"type": "string", "maxLength": 320},
	},
	"required": ["intent", "reply"],
}

enum Phase { INTRODUCTION, GETTING_ACQUAINTED }

@export_category("Following")
@export var follow_distance: float = 42.0
@export var follow_speed: float = 120.0
@export var catch_up_speed: float = 240.0

@export_category("Ollama — Michael only")
@export var ollama_host: String = "127.0.0.1"
@export var ollama_port: int = 11434
@export var model: String = "qwen3:8b"
@export_range(32, 192, 8) var max_response_tokens: int = 128
@export var auto_introduction: bool = true

@export_category("Area observations")
@export var area_comment_cooldown: float = 2.0
@export var area_revisit_cooldown: float = 45.0
@export var area_settle_time: float = 0.05

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bubble: Label = $Label
@onready var chat_panel: PanelContainer = $Dialogue/ChatPanel
@onready var title: Label = $Dialogue/ChatPanel/Margin/VBox/Header/Title
@onready var transcript: RichTextLabel = $Dialogue/ChatPanel/Margin/VBox/Transcript
@onready var input: LineEdit = $Dialogue/ChatPanel/Margin/VBox/InputRow/Message
@onready var send_button: Button = $Dialogue/ChatPanel/Margin/VBox/InputRow/Send
@onready var close_button: Button = $Dialogue/ChatPanel/Margin/VBox/Header/Close
@onready var retry_button: Button = $Dialogue/ChatPanel/Margin/VBox/Retry
@onready var status: Label = $Dialogue/ChatPanel/Margin/VBox/Status
@onready var talk_button: Button = $Dialogue/Talk

var current_phase: Phase = Phase.INTRODUCTION
var player_name: String = ""
var conversation_history: Array[Dictionary] = []
var last_metrics: Dictionary = {}
var _client: GuideClient
var _player: CharacterBody2D
var _trail: Array[Vector2] = []
var _direction: String = "down"
var _introduction_started: bool = false
var _has_met_player: bool = false
var _pending_user_text: String = ""
var _pending_introduction: bool = false
var _stream_text: String = ""
var _bubble_time_left: float = 0.0
var _owns_movement_lock: bool = false
var _movement_before_focus: bool = true
var _pending_name_disclosure: bool = false
var _inside_zones: Array[String] = []
var _queued_zone: String = ""
var _zone_delay_left: float = 0.0
var _comment_gap_left: float = 0.0
var _zone_cooldowns: Dictionary = {}
var _last_observation: String = ""
var _last_observation_zone: String = ""
var _show_observation_in_chat: bool = false
var _last_zone_lines: Dictionary = {}
var _bubble_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("guide_companion")
	_bubble_origin = bubble.position
	reset_dialogue()
	_client = GuideClient.new()
	add_child(_client)
	_client.token_received.connect(_on_token_received)
	_client.completed.connect(_on_reply_completed)
	_client.failed.connect(_on_reply_failed)
	input.text_submitted.connect(send_message)
	input.focus_entered.connect(_on_input_focus_entered)
	input.focus_exited.connect(_on_input_focus_exited)
	send_button.pressed.connect(func() -> void: send_message(input.text))
	close_button.pressed.connect(close_chat)
	talk_button.pressed.connect(open_chat)
	retry_button.pressed.connect(_retry_request)
	title.text = "Michael" if _is_czech() else "Майкл"
	send_button.text = "Odeslat" if _is_czech() else "Отправить"
	close_button.text = "Zavřít" if _is_czech() else "Закрыть"
	retry_button.text = "Zkusit znovu" if _is_czech() else "Повторить"
	talk_button.text = "F — Michael" if _is_czech() else "F — Майкл"
	input.placeholder_text = "Napiš Michaelovi…" if _is_czech() else "Напиши Майклу…"
	input.max_length = MAX_INPUT_CHARACTERS
	bubble.text = ""
	bubble.hide()
	_set_ready_status()
	_refresh_transcript()
	_play_animation(Vector2.ZERO)


func _process(delta: float) -> void:
	if is_instance_valid(Global.player) and not _introduction_started and auto_introduction:
		_introduction_started = true
		chat_panel.show()
		talk_button.hide()
		_start_request("", true)
	if not _client.busy and _bubble_time_left > 0.0:
		_bubble_time_left -= delta
		if _bubble_time_left <= 0.0:
			bubble.hide()
	_tick_observations(delta)


func enter_observation_zone(zone: String) -> void:
	if not AreaContext.ZONES.has(zone) or _inside_zones.has(zone):
		return
	_inside_zones.append(zone)
	if float(_zone_cooldowns.get(zone, 0.0)) <= 0.0:
		_queued_zone = zone
		_zone_delay_left = area_settle_time


func exit_observation_zone(zone: String) -> void:
	_inside_zones.erase(zone)
	if _last_observation_zone == zone:
		_last_observation = ""
		_last_observation_zone = ""
		_show_observation_in_chat = false
		_refresh_transcript()
	if _queued_zone == zone:
		_queued_zone = ""
		for index: int in range(_inside_zones.size() - 1, -1, -1):
			var candidate: String = _inside_zones[index]
			if float(_zone_cooldowns.get(candidate, 0.0)) <= 0.0:
				_queued_zone = candidate
				_zone_delay_left = area_settle_time
				break


func _tick_observations(delta: float) -> void:
	_comment_gap_left = maxf(_comment_gap_left - delta, 0.0)
	_zone_delay_left = maxf(_zone_delay_left - delta, 0.0)
	for zone: String in _zone_cooldowns:
		_zone_cooldowns[zone] = maxf(float(_zone_cooldowns[zone]) - delta, 0.0)
	var focused := get_viewport().gui_get_focus_owner()
	if _queued_zone.is_empty() or _client.busy or retry_button.visible or _comment_gap_left > 0.0 or _zone_delay_left > 0.0:
		return
	if auto_introduction and not _has_met_player:
		return
	if not is_instance_valid(Global.player) or not Global.player_can_move:
		return
	if global_position.distance_to(Global.player.global_position) > 280.0:
		return
	if focused is LineEdit or focused is TextEdit:
		return
	var zone := _queued_zone
	_queued_zone = ""
	if _inside_zones.has(zone):
		_say_observation(zone)


func _ship_is_repaired() -> bool:
	var scene := get_tree().current_scene
	var ship := scene.get_node_or_null("ship") if scene != null else null
	return ship != null and ship.get("ship_ready") == true


func _area_facts(zone: String) -> String:
	return AreaContext.facts(zone, _is_czech(), _ship_is_repaired())


func _area_lines(zone: String) -> Array:
	return AreaContext.lines(zone, _is_czech(), _ship_is_repaired())


func _say_observation(zone: String) -> void:
	var choices := _area_lines(zone)
	if choices.is_empty():
		return
	var previous: String = str(_last_zone_lines.get(zone, ""))
	# First arrival uses the clearest introduction; subsequent arrivals vary.
	var reply: String = str(choices[0])
	if not previous.is_empty():
		choices.erase(previous)
		if choices.is_empty():
			return
		reply = str(choices.pick_random())
	_last_zone_lines[zone] = reply
	_last_observation = reply
	_last_observation_zone = zone
	_show_observation_in_chat = true
	last_metrics = {"response_ms": 0, "source": "local_observation"}
	_zone_cooldowns[zone] = area_revisit_cooldown
	_comment_gap_left = area_comment_cooldown
	_show_bubble(reply, true)
	_bubble_time_left = 10.0
	_refresh_transcript()
	observation_spoken.emit(zone, reply)


func _nearby_area_context() -> String:
	if _inside_zones.is_empty():
		return ""
	var facts: PackedStringArray = []
	for zone: String in _inside_zones:
		facts.append(_area_facts(zone))
	var heading := "\nPRÁVĚ VIDÍŠ: " if _is_czech() else "\nСЕЙЧАС ВИДИШЬ: "
	var note := " To jsou současná pozorování, ne vzpomínky před havárií. Můžeš o nich mluvit, ale nic dalšího si nevymýšlej." if _is_czech() else " Это текущие наблюдения, а не воспоминания до крушения. Можешь обсуждать их, не придумывая дополнительных фактов."
	note += " Nevymýšlej stáří stromu, minulost lodi ani konkrétní součástky potřebné k opravě. U poškozené lodi je přirozené zmínit opravu jako možnou cestu k odplutí. Nespojuj okolí se svým úrazem." if _is_czech() else " Не выдумывай возраст дерева, прошлое корабля и конкретные детали для ремонта. Для разбитого корабля естественно предположить ремонт как способ уплыть. Не связывай окружение со своей травмой."
	if not _last_observation.is_empty():
		note += (" Tvá poslední poznámka: " if _is_czech() else " Твоя последняя реплика об окружении: ") + _last_observation
	return heading + " ".join(facts) + note


func _physics_process(delta: float) -> void:
	if not is_instance_valid(Global.player):
		velocity = Vector2.ZERO
		return
	if _player != Global.player:
		_player = Global.player
		_trail = [_player.global_position]
	var player_position := _player.global_position
	if _trail.is_empty() or _trail[-1].distance_to(player_position) >= 6.0:
		_trail.append(player_position)
	if _trail.size() > 256:
		_trail.pop_front()
	var distance := global_position.distance_to(player_position)
	var desired_velocity := Vector2.ZERO
	if distance > follow_distance:
		var goal := _follow_goal(player_position)
		var speed := follow_speed if distance < 120.0 else catch_up_speed
		var remaining := global_position.distance_to(goal)
		if goal.is_equal_approx(player_position):
			remaining = maxf(remaining - follow_distance, 0.0)
		desired_velocity = global_position.direction_to(goal) * minf(speed, remaining / maxf(delta, 0.001))
	velocity = velocity.move_toward(desired_velocity, 900.0 * delta)
	move_and_slide()
	_play_animation(velocity)


func _follow_goal(player_position: Vector2) -> Vector2:
	if not test_move(global_transform, player_position - global_position):
		_trail = [player_position]
		return player_position
	# Follow the player's actual trail around corners instead of cutting through walls.
	for index: int in range(_trail.size() - 1, -1, -1):
		if not test_move(global_transform, _trail[index] - global_position):
			var goal := _trail[index]
			_trail = _trail.slice(index)
			return goal
	return _trail[0]


func _play_animation(motion: Vector2) -> void:
	if motion.length_squared() > 1.0:
		if absf(motion.x) > absf(motion.y):
			_direction = "side"
			sprite.flip_h = motion.x < 0.0
		else:
			_direction = "top" if motion.y < 0.0 else "down"
			sprite.flip_h = false
		sprite.play("walk_" + _direction)
	else:
		sprite.play("ilde_down" if _direction == "down" else "idle_" + _direction)


func _input(event: InputEvent) -> void:
	if chat_panel.visible and event.is_action_pressed("esc"):
		close_chat()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		if not input.has_focus():
			open_chat()
			get_viewport().set_input_as_handled()


func open_chat() -> void:
	chat_panel.show()
	talk_button.hide()
	if input.editable:
		input.grab_focus()


func close_chat() -> void:
	input.release_focus()
	chat_panel.hide()
	talk_button.show()


func _on_input_focus_entered() -> void:
	if not _owns_movement_lock:
		_movement_before_focus = Global.player_can_move
		_owns_movement_lock = true
	Global.player_can_move = false


func _on_input_focus_exited() -> void:
	if _owns_movement_lock:
		Global.player_can_move = _movement_before_focus
		_owns_movement_lock = false


func send_message(value: String) -> void:
	value = value.strip_edges().left(MAX_INPUT_CHARACTERS)
	if value.is_empty() or _client.busy:
		return
	_show_observation_in_chat = false
	_pending_name_disclosure = _remember_player_name(value)
	input.clear()
	_start_request(value, false)


func _start_request(value: String, introduction: bool) -> void:
	_pending_user_text = value
	_pending_introduction = introduction
	_stream_text = ""
	input.release_focus()
	input.editable = false
	send_button.disabled = true
	retry_button.hide()
	status.text = "Michael odpovídá…" if _is_czech() else "Майкл отвечает…"
	_client.send(ollama_host, ollama_port, build_request(value, introduction))
	_refresh_transcript()


func build_request(value: String, introduction: bool) -> Dictionary:
	var messages: Array[Dictionary] = [{"role": "system", "content": _system_prompt() + _question_grounding(value) + _nearby_area_context()}]
	messages.append_array(conversation_history)
	if not introduction and _has_met_player:
		var dialogue_note := "Вы уже познакомились. Самолёт и своё представление больше не повторяй. На вопросы об имени отвечай доброжелательно, без замечаний о повторах."
		if _is_czech():
			dialogue_note = "Už jste se seznámili. Neopakuj letadlo ani své představení. Na otázky o jméně odpovídej přátelsky, bez poznámek o opakování."
		if _pending_name_disclosure:
			dialogue_note += " Hráč ti právě sdělil jméno. Přirozeně ho oslov a můžeš se krátce zeptat, jak se teď cítí." if _is_czech() else " Игрок только что назвал своё имя. Естественно обратись к нему, можно кратко спросить о его самочувствии."
		dialogue_note += _known_fact_note(value)
		messages.append({"role": "system", "content": dialogue_note})
	if introduction:
		var instruction := "Первая встреча. Удивись, что он тоже из упавшего самолёта; обязательно произнеси слово «самолёт». Представься Майклом и скажи, что тоже выжил. Спроси его имя. По смыслу: «Ого, ты тоже из самолёта? Я Майкл, тоже выжил. А тебя как зовут?» Можно немного иначе, 3 короткие фразы, без добавлений."
		if _is_czech():
			instruction = "První setkání. Překvapeně se zeptej, zda také přežil pád letadla. Představ se jako Michael, také jsi přežil. Zeptej se na jeho jméno. Přirozeně, například: ‚Ty jsi taky z toho letadla? Já jsem Michael, taky jsem přežil. Jak se jmenuješ?‘ Tři krátké věty, pouze česky."
		if _has_met_player:
			instruction = "Znovu se potkáváte. Krátce hráče pozdrav, jménem, pokud ho znáš. Nepředstavuj se znovu a neopakuj otázku o letadle." if _is_czech() else "Вы снова встретились. Коротко поздоровайся с игроком, по имени, если знаешь. Не знакомься заново и не повторяй вопрос про самолёт."
		messages.append({"role": "user", "content": instruction})
	else:
		messages.append({"role": "user", "content": value})
	var format := REFLECTION_SCHEMA.duplicate(true)
	if _inside_zones.has("baobab") and AreaContext.mentions_zone(value, ["baobab"]):
		var normalized := value.to_lower()
		for phrase: String in ["сколько лет", "возраст", "стар", "star", "stáří", "věk"]:
			if normalized.contains(phrase):
				format["properties"]["reply"]["enum"] = AreaContext.age_answers(_is_czech())
				break
	return {
		"model": model, "messages": messages, "stream": true, "think": false,
		# A tiny, explicit response plan precedes the spoken reply in the same
		# generation. This bounds preparation without an open-ended thinking pass.
		"format": format,
		"keep_alive": "15m",
		# Match the other NPCs' runner profile: switching context/batch sizes reloads the shared model.
		"options": {"num_ctx": 4096, "num_batch": 512, "num_predict": max_response_tokens + 32,
			"temperature": 0.6, "top_p": 0.9, "repeat_penalty": 1.05},
	}


func _system_prompt() -> String:
	if _is_czech():
		return _czech_system_prompt()
	var name_fact := "Имя игрока пока неизвестно. Не угадывай его."
	if not player_name.is_empty():
		name_fact = "Игрок сообщил: его зовут %s. Помни это имя, не спрашивай заново. На вопрос об имени игрока отвечай: %s." % [player_name, player_name]
	return """Ты Майкл, живой дружелюбный спутник игрока на острове.
ЗНАЕШЬ ТОЧНО: тебя зовут Майкл, у тебя тёмная кожа, ты выжил в том же авиакрушении и сейчас следуешь за игроком.
НЕ ПОМНИШЬ из-за сотрясения: семью, профессию, возраст, родину и прошлое до крушения. Не выдумывай их и не угадывай происхождение по внешности.
Новое из разговоров помнишь. Сотрясение иногда сбивает с мысли, но не мешает знать своё имя, внешность и имя игрока. Не изображай карикатуру и не упоминай травму без повода.
%s
Говори только по-русски, от первого лица, просто и естественно. 1–3 коротких предложения, до 320 символов.
Отвечай на смысл последней реплики с учётом истории. Поддерживай тему и настроение; иногда задавай один уместный вопрос, чтобы узнать собеседника. Если ему страшно или одиноко, сначала отзовись на это. На прямые вопросы отвечай прямо, на повторы — доброжелательно.
Спокойный дружеский тон: без упрёков, пафоса, интимных жестов и заученной мотивации. Не придумывай сведения об острове, маршруты, квесты и предметы. После знакомства не представляйся заново. О внешности говори по вопросу.
Верни JSON, сначала intent, затем reply. intent: краткая цель ответа в 3–6 словах, с учётом смысла и настроения, без длинных рассуждений. reply: только естественная реплика Майкла по-русски. intent не произноси, Markdown и описания действий не используй.""" % name_fact


func _czech_system_prompt() -> String:
	var name_fact := "Jméno hráče zatím neznáš. Nevymýšlej ho."
	if not player_name.is_empty():
		name_fact = "Hráč ti řekl, že se jmenuje %s. Pamatuj si jeho jméno a neptej se na něj znovu." % player_name
	return """Jsi Michael, přátelský lidský společník hráče na ostrově.
JISTÉ SKUTEČNOSTI: jmenuješ se Michael, máš tmavou pleť, přežil jsi stejnou havárii letadla a teď následuješ hráče.
KVŮLI OTŘESU MOZKU NEVÍŠ: nic o své rodině, povolání, věku, rodišti ani minulosti před havárií. Nevymýšlej si je, ani neodvozuj původ z barvy pleti.
Nové informace z rozhovorů si pamatuješ. Občas ztratíš nit, ale své jméno, vzhled i jméno hráče znáš. Žádná karikatura a zmiňování úrazu bez důvodu.
%s
Mluv výhradně přirozenou češtinou v první osobě. 1–3 krátké věty, nejvýše 320 znaků.
Odpovídej na smysl poslední zprávy v kontextu rozhovoru. Vnímej náladu, navazuj na téma a občas polož jednu vhodnou otázku, abys hráče poznal. Když se bojí nebo je osamělý, nejprve na ten pocit zareaguj. Na přímé otázky odpovídej přímo, na opakované přátelsky.
Klidný kamarádský tón, bez výčitek, patosu, důvěrných gest a motivačních klišé. Nevymýšlej informace o ostrově, cesty, úkoly ani předměty. Po seznámení se znovu nepředstavuj. Vzhled popisuj na dotaz.
Vrať JSON, nejprve intent, potom reply. intent: stručný cíl odpovědi ve 3–6 slovech podle smyslu zprávy a nálady, bez dlouhého uvažování. reply: pouze přirozená Michaelova replika česky. intent nevyslovuj, nepoužívej Markdown ani popisy akcí.""" % name_fact


func _known_fact_note(value: String) -> String:
	if AreaContext.mentions_zone(value, _inside_zones):
		var facts: PackedStringArray = []
		for zone: String in _inside_zones:
			facts.append(_area_facts(zone))
		return (" O předmětu hráčova dotazu znáš pouze: " if _is_czech() else " О предмете вопроса игрока известно только: ") + " ".join(facts) + (" Neodhaduj neznámé údaje ani je nespojuj se svým úrazem." if _is_czech() else " Не угадывай неизвестные данные и не связывай их со своей травмой.")
	var normalized := value.to_lower().replace("ё", "е")
	for phrase: String in ["как меня зовут", "мое имя", "jak se jmenuju", "mé jméno", "moje jméno"]:
		if normalized.contains(phrase) and not player_name.is_empty():
			return " Jméno hráče znáš: %s. Potvrď ho přátelsky, např. ‚Jmenuješ se %s, pamatuju si to.‘" % [player_name, player_name] if _is_czech() else " Имя игрока известно: %s. Дружески подтверди, например: «Ты %s, я помню»." % [player_name, player_name]
	for phrase: String in ["как тебя зовут", "твое имя", "jak se jmenuješ", "tvé jméno", "tvoje jméno"]:
		if normalized.contains(phrase):
			return " Své jméno bezpečně znáš: Michael. Odpověz jednoduše a přátelsky." if _is_czech() else " Своё имя точно знаешь: Майкл. Ответь просто и дружелюбно."
	for phrase: String in ["кож", "внешн", "выглядишь", "pleť", "pleti", "kůž", "vzhled", "vypadáš"]:
		if normalized.contains(phrase):
			return " Na otázku o svém vzhledu využij jistý fakt: máš tmavou pleť, to víš a otřes mozku na tom nic nemění." if _is_czech() else " На вопрос о своей внешности используй достоверный факт: у тебя тёмная кожа, это знаешь и сотрясение этому не мешает."
	return ""


func _question_grounding(value: String) -> String:
	if AreaContext.mentions_zone(value, _inside_zones):
		return ""
	var normalized := value.to_lower().replace("ё", "е")
	for mark: String in [".", ",", "!", "?", ";", ":", "(", ")", "—", "-", "\n", "\t", '"']:
		normalized = normalized.replace(mark, " ")
	normalized = " " + " ".join(normalized.split(" ", false)) + " "
	var about_player: bool = false
	var about_michael: bool = false
	for phrase: String in [" я ", " меня ", " мне ", " мой ", " моя ", " моей ", " мою ", " mám ", " jsem ", " moje ", " můj ", " mojí ", " mi ", " mě ", " mně ", " mou ", " svou ", " svoji "]:
		about_player = about_player or normalized.contains(phrase)
	for phrase: String in [" теб", " тво", " tv", " tě ", " ti ", " ses ", " your "]:
		about_michael = about_michael or normalized.contains(phrase)
	if about_player and not about_michael:
		return ""
	var unknown_biography := ["родил", "родом", "родн", "семь", "родител", "профес", "работал", "работаешь", "возраст", "тебе лет", "лет тебе", "сколько лет", "школ", "учил", "образован", "жил раньше", "раньше жил", "до круш", "до авар", "до полет", "националь", "граждан", "откуда ты", "жена", "женат", "дети", "детей", "дочь", "сын", "мама", "папа", "брат", "сестр", "фамил", "narodil", "odkud", "rodin", "pracoval", "povolání", "kolik ti je", "kolik je ti", "příjmení", "věk", "rodič", "děti", "dítě", "manžel", "otec", "matka", "bratr", "sestra", "studoval", "dětství", "národnost", "where were you born", "your job", "your family", "how old"]
	for phrase: String in unknown_biography:
		# Match word starts: e.g. «выбраться» must not trigger «брат».
		if normalized.contains(" " + phrase):
			return "\nPoslední otázka se týká Michaelovy neznámé minulosti. Krátce přiznej, že si to po úderu nepamatuješ. Nevymýšlej věk, zemi, město, rodinu, práci ani jiné podrobnosti." if _is_czech() else "\nПоследний вопрос касается неизвестного прошлого Майкла. В ответе разрешён только факт: после удара ты этого не помнишь. Коротко признай это, без догадок о возрасте, стране, городе, семье или работе и без добавления каких-либо подробностей."
	return ""


func _on_token_received(token: String) -> void:
	_stream_text += token
	_show_bubble(_stream_text)
	_refresh_transcript()


func _on_reply_completed(reply: String, metrics: Dictionary) -> void:
	if not _pending_introduction:
		conversation_history.append({"role": "user", "content": _pending_user_text})
	conversation_history.append({"role": "assistant", "content": reply})
	while conversation_history.size() > MAX_HISTORY_MESSAGES:
		conversation_history.pop_front()
	_has_met_player = true
	current_phase = Phase.GETTING_ACQUAINTED
	last_metrics = metrics
	_pending_user_text = ""
	_pending_name_disclosure = false
	_stream_text = ""
	input.editable = true
	send_button.disabled = false
	_set_ready_status()
	_refresh_transcript()
	_show_bubble(reply)
	_bubble_time_left = 12.0
	_comment_gap_left = maxf(_comment_gap_left, 0.35)
	reply_finished.emit(reply, metrics)


func _on_reply_failed(reason: String) -> void:
	input.editable = true
	send_button.disabled = false
	retry_button.show()
	if reason == "model_not_found":
		status.text = ("Ollama nemá model %s. Vyber u Michaela nainstalovaný model." if _is_czech() else "В Ollama нет модели %s. Укажи установленную модель у Майкла.") % model
	else:
		status.text = "Odpověď se nepodařilo získat. Spusť Ollama a zkus to znovu." if _is_czech() else "Не удалось получить ответ. Проверь, запущена ли Ollama, и нажми «Повторить»."
	_bubble_time_left = 6.0
	push_warning("[Michael / Ollama] " + reason)


func _retry_request() -> void:
	if not _client.busy:
		_start_request(_pending_user_text, _pending_introduction)


func _set_ready_status() -> void:
	status.text = "F — rozhovor · Enter — odeslat · Esc — zavřít" if _is_czech() else "F — разговор · Enter — отправить · Esc — закрыть"


func _refresh_transcript() -> void:
	var lines: PackedStringArray = []
	for message: Dictionary in conversation_history:
		var speaker: String = title.text if message.role == "assistant" else ("Ty" if _is_czech() else "Ты")
		lines.append(speaker + ": " + str(message.content))
	if _show_observation_in_chat and not _last_observation.is_empty():
		lines.append(title.text + ": " + _last_observation)
	if _client != null and _client.busy:
		if not _pending_introduction:
			lines.append(("Ty: " if _is_czech() else "Ты: ") + _pending_user_text)
		if not _stream_text.is_empty():
			lines.append(title.text + ": " + _stream_text)
	transcript.text = "\n\n".join(lines)


func _show_bubble(value: String, complete: bool = false) -> void:
	bubble.text = value
	bubble.max_lines_visible = -1 if complete else 3
	bubble.position = _bubble_origin
	bubble.show()
	if complete:
		_position_observation_bubble.call_deferred()


func _position_observation_bubble() -> void:
	if bubble.max_lines_visible == -1:
		bubble.position.y = minf(_bubble_origin.y, -20.0 - bubble.get_minimum_size().y * absf(bubble.scale.y))


func _remember_player_name(value: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("(?i)(?:меня\\s+зовут|мо[её]\\s+имя|зови\\s+меня|можешь\\s+звать\\s+меня|jmenuj[ui]\\s+se|říkej\\s+mi|my\\s+name\\s+is|call\\s+me)\\s*[:—-]?\\s+([\\p{L}][\\p{L}'’-]{1,31})")
	# Lowercase explicitly: PCRE's default case folding can miss Cyrillic capitals.
	var found := pattern.search(value.to_lower())
	var candidate := value.substr(found.get_start(1), found.get_end(1) - found.get_start(1)) if found != null else ""
	if candidate.is_empty() and player_name.is_empty() and not value.contains("?"):
		var single_name := RegEx.new()
		single_name.compile("^[\\p{L}][\\p{L}'’-]{1,31}[.!]?$")
		var excluded := ["привет", "здравствуй", "здорово", "да", "нет", "ага", "ладно", "окей", "хорошо", "спасибо", "понятно", "незнаю", "как", "кто", "что", "где", "почему", "ясно", "хм", "hello", "hi", "ahoj", "ano", "ne"]
		var cleaned := value.trim_suffix(".").trim_suffix("!")
		if single_name.search(value) != null and not cleaned.to_lower() in excluded:
			candidate = cleaned
	if not candidate.is_empty():
		player_name = candidate.left(32)
		return true
	return false


func reset_dialogue() -> void:
	# Each new Main instance is a new acquaintance. Old user:// saves are ignored.
	if is_instance_valid(_client):
		_client.cancel()
	_on_input_focus_exited()
	current_phase = Phase.INTRODUCTION
	player_name = ""
	conversation_history.clear()
	_has_met_player = false
	_introduction_started = false
	_pending_user_text = ""
	_pending_introduction = false
	_pending_name_disclosure = false
	_stream_text = ""
	last_metrics.clear()
	_bubble_time_left = 0.0
	_inside_zones.clear()
	_queued_zone = ""
	_zone_delay_left = 0.0
	_comment_gap_left = 0.0
	_zone_cooldowns.clear()
	_last_zone_lines.clear()
	_last_observation = ""
	_last_observation_zone = ""
	_show_observation_in_chat = false
	input.clear()
	input.release_focus()
	input.editable = true
	send_button.disabled = false
	retry_button.hide()
	chat_panel.hide()
	talk_button.show()
	bubble.text = ""
	bubble.hide()
	_set_ready_status()
	_refresh_transcript()


func _is_czech() -> bool:
	return Global.language == "cz"


func _exit_tree() -> void:
	_on_input_focus_exited()
	if is_instance_valid(_client):
		_client.cancel()
