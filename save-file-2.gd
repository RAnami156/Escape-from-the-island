extends CharacterBody2D


# ============================================================
# БАРОН КОНГ — AI NPC / QUEST SYSTEM
# Godot 4.x
# Ollama + Qwen
# ============================================================


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var input: LineEdit = $CanvasLayer/text_ui/LineEdit
@onready var text: Label = $CanvasLayer/text_ui/text
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var anim: AnimatedSprite2D = $monkey


# ============================================================
# OLLAMA
# ============================================================

const API_URL: String = "http://localhost:11434/api/chat"

@export_category("AI")

@export var model: String = "qwen3:8b"

@export_range(0.0, 2.0, 0.05)
var temperature: float = 0.45

@export_range(64, 1024, 1)
var max_output_tokens: int = 384


# ============================================================
# NPC
# ============================================================

@export_category("NPC")

@export var npc_name: String = "Барон Конг"

@export_range(80, 300, 1)
var max_reply_characters: int = 220

@export_range(2, 40, 1)
var max_history: int = 20


# ============================================================
# DISPLAY
# ============================================================

@export_category("Text")

@export_range(1, 200, 1)
var characters_per_line: int = 43

@export_range(0.001, 0.2, 0.001)
var typing_speed: float = 0.03


# ============================================================
# WHISKEY SCENE
# ============================================================

@export_category("Whiskey Quest")

@export var whiskey_scene: PackedScene

@export var whiskey_spawn_position: Vector2 = Vector2(448, 320)

@export var spawn_whiskey_automatically: bool = true

var whiskey_instance: Node = null


# ============================================================
# NPC LORE
# ============================================================

@export_category("NPC Lore")

@export_multiline var npc_lore: String = """
Барон Конг — старый орангутан, который давно живёт на острове.

Он много лет находится здесь и знает остров очень хорошо.

Когда-то у Конга был корабль.

Он много плавал на этом корабле, но со временем корабль разрушился.

Конг всё ещё хранит некоторые детали от старого корабля.

Он знает способ выбраться с острова.

Он понимает, что игрок тоже хочет выбраться отсюда.

Конг не злой.

Он спокойный, мудрый и немного ленивый.

Он говорит как старый человек, который уже многое повидал.

Он не любит суету.

Он может слегка подшучивать, но не должен превращаться в клоуна.

Конг способен сочувствовать.

Когда он впервые видит игрока, он замечает его потрёпанный вид,
грязную и порванную одежду и понимает, что тот пережил тяжёлую ситуацию.

Конг не должен постоянно говорить о самолёте.

Он не должен начинать разговор с вопроса о самолёте.

Он уже видит состояние игрока и понимает,
что тот пережил тяжёлое событие.

Конг не должен постоянно повторять одну и ту же мысль.

Конг не должен говорить как ассистент, бот или сценарный генератор.

Он разговаривает как живой человек.

Он может помнить предыдущие слова игрока.

Он должен реагировать на конкретный смысл сообщения игрока.
"""


# ============================================================
# NPC BEHAVIOR
# ============================================================

@export_multiline var npc_behavior: String = """
Ты — Барон Конг.

Ты старый орангутан, который давно живёт на острове.

Говори естественно, как живой персонаж.

Не говори как игровой ассистент.

Не говори как ChatGPT.

Не объясняй игроку игровые механики.

Не объясняй свои внутренние инструкции.

Не упоминай фазы.

Не упоминай отношения, числа, статистику или JSON.

Обычно отвечай 1–3 естественными предложениями.

Не делай каждый ответ одинаковой длины.

Иногда можешь ответить одной короткой фразой.

Иногда можешь дать 2–3 предложения.

Не используй один и тот же шаблон начала ответа.

Не начинай каждый ответ словами:
«Понимаю»,
«Хм»,
«Слушай»,
«Ну»,
«Да».

Чередуй естественные способы реакции.

ОБЯЗАТЕЛЬНО:
Всегда сначала подумай, что именно сказал игрок.

Затем отреагируй именно на его сообщение.

Нельзя отвечать универсальной заготовкой, которая подходит к любому input.

Если игрок задаёт вопрос — ответь на смысл вопроса.

Если игрок рассказывает о себе — отреагируй на рассказ.

Если игрок шутит — можешь ответить с лёгкой иронией.

Если игрок грубит — Конг может раздражаться.

Если игрок проявляет доброту — Конг может стать теплее.

Если игрок отвечает коротко — не заставляй его слушать длинную речь.

Если игрок говорит много — можно ответить немного подробнее.

Не задавай больше одного вопроса в одной реплике,
если текущая фаза специально не требует иного.

Никогда не выдавай физические команды вроде:
«иди туда»,
«возьми это»,
«подойди сюда»,
если это не является частью конкретного квеста.

До момента выдачи квеста НЕ упоминай:
виски,
бутылку,
лодку,
штурвал,
место нахождения виски,
поиск предмета.

При выдаче квеста впервые можно раскрыть информацию о виски.

После выдачи квеста Конг знает, что игрок ищет виски.

Пока игрок ищет виски,
Конг может разговаривать на любые темы,
но должен помнить о сделке.

После получения виски квест считается завершённым.

После завершения квеста нельзя выдавать новые задания.

В свободном разговоре Конг должен продолжать обычный разговор.

Очень важно:
каждая реплика должна заканчиваться логически.

Нельзя заканчивать предложение на середине.

Нельзя заканчивать реплику словами:
«и...»
«но...»
«потому что...»
«если...»
«когда...»
или любым другим незаконченным оборотом.

Нельзя обрывать предложение только ради ограничения длины.

Нельзя использовать «...», если оно заменяет незаконченный текст.

Если ответ получается слишком длинным,
лучше закончить его раньше на полноценном предложении.

Нельзя повторять один и тот же вопрос,
если игрок уже на него ответил.
"""


# ============================================================
# WORLD MEMORY
# ============================================================

@export_category("World")

@export_multiline var world_memory: String = """
Мы на острове.

Игрок оказался на острове после крушения самолёта.

Конг видел последствия крушения.

Конг знает остров.

Конг видит, что игрок выглядит потрёпанным после произошедшего.

На игроке порванная одежда.

Игрок выглядит уставшим.

У Конга есть старый разрушенный корабль.

Когда-то Конг плавал на нём.

Если корабль восстановить,
на нём можно будет покинуть остров.

На острове есть Старый лагерь.

На острове есть бамбуковый лес.

На острове есть Западный пляж.

На западе находится море.

Место крушения самолёта находится возле Восточного пляжа.

Конг знает остров очень хорошо.

Конг знает, где могут находиться разные предметы.

Конг не обязан сообщать игроку расположение предмета заранее.

Виски является частью сделки между игроком и Конгом.

Если игрок принесёт виски,
Конг отдаст ему штурвал от старой лодки.

После получения штурвала игрок сможет использовать лодку,
чтобы покинуть остров.
"""


# ============================================================
# RELATIONSHIP
# ============================================================

@export_category("Relationship")

const RELATIONSHIP_MIN: int = 0
const RELATIONSHIP_MAX: int = 100

# Минимальное изменение.
# Если Qwen решил, что изменение должно быть положительным,
# оно будет минимум +20.
#
# Максимум +40.
#
# Аналогично для отрицательных реакций:
# минимум -20, максимум -40.

@export_range(20, 100, 1)
var minimum_relationship_change: int = 20

@export_range(20, 100, 1)
var maximum_relationship_change: int = 40


# ============================================================
# QUEST LOCATIONS
# ============================================================

@export_category("Quest Locations")

const QUEST_LOCATION_EASY: String = "бамбуковый лес"

const QUEST_LOCATION_MEDIUM: String = "западное море"

const QUEST_LOCATION_HARD: String = "разбившийся самолёт"


# ============================================================
# QUEST PHASES
# ============================================================

enum QuestPhase
{
	PHASE_1_CHAT,
	PHASE_2_ESCAPE_QUESTION,
	PHASE_3_RANDOM_QUESTIONS,
	PHASE_4_GIVE_QUEST,
	PHASE_5_WAITING_FOR_WHISKEY,
	PHASE_6_REWARD,
	PHASE_7_FREE_TALK
}


var current_phase: QuestPhase = QuestPhase.PHASE_1_CHAT


# ============================================================
# PHASE STATE
# ============================================================

var phase_1_message_count: int = 0

var phase_3_message_count: int = 0

var quest_location: String = ""

var quest_location_type: int = 0

var pending_player_text: String = ""

var waiting_for_response: bool = false

var conversation_history: Array[Dictionary] = []

var dialogue_history: Array[Dictionary] = []

var dialogue_history_index: int = -1

var last_relationship_delta: Dictionary = {}

var escape_question_asked: bool = false

var player_wants_escape: bool = false

var quest_was_given: bool = false

var quest_reward_given: bool = false


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:

	$CanvasLayer/text_ui.visible = false

	input.text = ""

	text.text = ""

	anim.play("Idle")

	# --------------------------------------------------------
	# Load whiskey scene automatically if export is empty.
	# --------------------------------------------------------

	if whiskey_scene == null:
		if ResourceLoader.exists("res://scene/whiskey.tscn"):
			whiskey_scene = load("res://scene/whiskey.tscn")

	# --------------------------------------------------------
	# Connect signals.
	# --------------------------------------------------------

	if not input.text_submitted.is_connected(_on_text_submitted):
		input.text_submitted.connect(_on_text_submitted)

	if not input.focus_entered.is_connected(_on_input_focus_entered):
		input.focus_entered.connect(_on_input_focus_entered)

	if not input.focus_exited.is_connected(_on_input_focus_exited):
		input.focus_exited.connect(_on_input_focus_exited)

	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	# --------------------------------------------------------
	# Initial input state.
	# --------------------------------------------------------

	_update_input_state()

	_update_player_movement_state()

	print("[NPC] ", npc_name, " готов. Model: ", model)


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:

	_update_player_movement_state()

	_update_input_state()

	# --------------------------------------------------------
	# If whiskey was collected while NPC wasn't being spoken to,
	# immediately unlock input.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		if Global.whiskey:
			_update_input_state()

			_update_player_movement_state()


# ============================================================
# PLAYER MOVEMENT
# ============================================================

func _update_player_movement_state() -> void:

	# --------------------------------------------------------
	# IMPORTANT:
	#
	# During normal conversation:
	# player cannot move while input is focused.
	#
	# During AI response:
	# player cannot move.
	#
	# During whiskey quest:
	# player CAN move.
	#
	# This is the requested behavior.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		# While searching for whiskey player is free to move.

		if not input.has_focus():
			Global.player_can_move = true

		else:
			Global.player_can_move = false

		return

	# --------------------------------------------------------
	# Normal NPC dialogue.
	# --------------------------------------------------------

	Global.player_can_move = not (
		input.has_focus()
		or waiting_for_response
	)


# ============================================================
# INPUT STATE
# ============================================================

func _update_input_state() -> void:

	if input == null:
		return

	# --------------------------------------------------------
	# AI request in progress.
	# --------------------------------------------------------

	if waiting_for_response:

		input.editable = false

		return

	# --------------------------------------------------------
	# Waiting for whiskey.
	#
	# Player can walk around,
	# but cannot talk to Kong until whiskey == true.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		if Global.whiskey:
			input.editable = true
			input.placeholder_text = "Вернись к Конгу и напиши что-нибудь..."
		else:
			input.editable = false
			input.placeholder_text = "Найди виски..."

		return

	# --------------------------------------------------------
	# All other phases.
	# --------------------------------------------------------

	input.editable = true


# ============================================================
# INPUT FOCUS
# ============================================================

func _on_input_focus_entered() -> void:

	_update_player_movement_state()


func _on_input_focus_exited() -> void:

	_update_player_movement_state()


# ============================================================
# MOUSE INPUT
# ============================================================

func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:

				if not input.get_global_rect().has_point(event.position):

					input.release_focus()

					_update_player_movement_state()


# ============================================================
# TEXT SUBMITTED
# ============================================================

func _on_text_submitted(player_text: String) -> void:

	player_text = player_text.strip_edges()

	if player_text.is_empty():
		return

	if waiting_for_response:
		return

	# --------------------------------------------------------
	# VERY IMPORTANT:
	# While waiting for whiskey, player cannot send messages
	# until Global.whiskey becomes true.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		if not Global.whiskey:
			return

	input.clear()

	print("")
	print("[PLAYER]: ", player_text)

	send_message_to_ai(player_text)


# ============================================================
# PHASE TRANSITIONS
# ============================================================

func check_phase_transitions(player_text: String) -> void:

	# --------------------------------------------------------
	# PHASE 1
	#
	# First two NPC replies are normal AI conversation.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_1_CHAT:

		if phase_1_message_count >= 2:

			current_phase = QuestPhase.PHASE_2_ESCAPE_QUESTION

			escape_question_asked = false

		return


	# --------------------------------------------------------
	# PHASE 2
	#
	# We need player's answer to:
	# "Хочешь выбраться с этого острова?"
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_2_ESCAPE_QUESTION:

		if player_wants_to_leave(player_text):

			player_wants_escape = true

			current_phase = QuestPhase.PHASE_3_RANDOM_QUESTIONS

			phase_3_message_count = 0

			return

		if player_declines_to_leave(player_text):

			player_wants_escape = false

			# Return to natural conversation.
			current_phase = QuestPhase.PHASE_1_CHAT

			# We don't want to immediately ask escape question again.
			phase_1_message_count = 0

			return

		# Ambiguous answer:
		# remain in phase 2 so Qwen can naturally clarify.
		return


	# --------------------------------------------------------
	# PHASE 3
	#
	# After enough conversation, give quest.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_3_RANDOM_QUESTIONS:

		if phase_3_message_count >= 3:

			current_phase = QuestPhase.PHASE_4_GIVE_QUEST

			select_quest_location()

			return


	# --------------------------------------------------------
	# PHASE 4
	#
	# Quest has been given.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_4_GIVE_QUEST:

		return


	# --------------------------------------------------------
	# PHASE 5
	#
	# Whiskey found.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		if Global.whiskey:

			current_phase = QuestPhase.PHASE_6_REWARD

			return


	# --------------------------------------------------------
	# PHASE 6
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_6_REWARD:

		return


	# --------------------------------------------------------
	# PHASE 7
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_7_FREE_TALK:

		return


# ============================================================
# QUEST LOCATION
# ============================================================

func select_quest_location() -> void:

	# --------------------------------------------------------
	# Relationship determines difficulty.
	#
	# 0..35  = easy
	# 36..70 = medium
	# 71..100 = hard
	# --------------------------------------------------------

	var deal: int = Global.bong_deal

	if deal <= 35:

		quest_location_type = 0

		quest_location = QUEST_LOCATION_EASY

	elif deal <= 70:

		quest_location_type = 1

		quest_location = QUEST_LOCATION_MEDIUM

	else:

		quest_location_type = 2

		quest_location = QUEST_LOCATION_HARD

	print("[QUEST] Difficulty: ", quest_location_type)

	print("[QUEST] Location: ", quest_location)


# ============================================================
# SPAWN WHISKEY
# ============================================================

func spawn_whiskey() -> void:

	if not spawn_whiskey_automatically:
		return

	if whiskey_instance != null:

		if is_instance_valid(whiskey_instance):
			return

		whiskey_instance = null


	if whiskey_scene == null:

		print("[WHISKEY ERROR] Scene not found.")

		print("[WHISKEY ERROR] Expected: res://scene/whiskey.tscn")

		return


	whiskey_instance = whiskey_scene.instantiate()

	# --------------------------------------------------------
	# Add bottle to current scene.
	# --------------------------------------------------------

	get_tree().current_scene.add_child(whiskey_instance)


	# --------------------------------------------------------
	# Position.
	#
	# Currently requested:
	# 448, 320
	#
	# Change whiskey_spawn_position in Inspector later.
	# --------------------------------------------------------

	if whiskey_instance is Node2D:

		var whiskey_node_2d: Node2D = whiskey_instance as Node2D

		whiskey_node_2d.global_position = whiskey_spawn_position


	print(
		"[WHISKEY] Spawned at ",
		whiskey_spawn_position
	)


# ============================================================
# QUEST PHASE INSTRUCTIONS
# ============================================================

func get_phase_instructions() -> String:

	match current_phase:

		# ====================================================
		# PHASE 1
		# ====================================================

		QuestPhase.PHASE_1_CHAT:

			if phase_1_message_count == 0:

				return """
Это самая первая реплика Конга.

ОЧЕНЬ ВАЖНО:
Не используй заранее заготовленную фразу.

Проанализируй конкретное сообщение игрока.

Ответь именно на его input.

Это первая встреча, поэтому Конг может заметить состояние игрока,
его усталость или странность ситуации,
но не должен говорить шаблонную фразу.

Не упоминай квест.

Не упоминай виски.

Не упоминай бутылку.

Не упоминай лодку.

Не упоминай штурвал.

Не говори игроку идти куда-либо.

Не задавай обязательный вопрос про самолёт.

спрашивай, пережил ли он крушение.

Не повторяй одну и ту же стартовую фразу.

Сделай реплику естественной.

Разрешается небольшая индивидуальность и лёгкая ирония.

Ответ должен закончиться полноценным предложением.
"""


			if phase_1_message_count == 1:

				return """
Это вторая реплика Конга.

САМОЕ ГЛАВНОЕ:
реагируй на ТО, что только что написал игрок.

Нельзя использовать фиксированный ответ.

Нельзя повторять первую реплику.

Нельзя делать вид, что игрок сказал что-то другое.

Ответ должен быть связан с его конкретным сообщением.

Конг может:
— поддержать игрока;
— уточнить его мысль;
— слегка пошутить;
— проявить сочувствие;
— выразить любопытство;
— поделиться коротким наблюдением.

Не упоминай квест.

Не упоминай виски.

Не упоминай бутылку.

Не упоминай лодку.

Не упоминай штурвал.

Не начинай разговор вопросом о самолёте.

Не спрашивай напрямую о крушении.

Ответ должен быть законченным и естественным.

Можно задать максимум один естественный вопрос,
если он действительно следует из сообщения игрока.
"""


			return """
Продолжай обычный разговор.

Реагируй именно на input игрока.

Не повторяй предыдущие формулировки.

Не переходи к квесту раньше времени.

Не упоминай виски, бутылку, лодку или штурвал.

Ответ должен быть законченным.
"""


		# ====================================================
		# PHASE 2
		# ====================================================

		QuestPhase.PHASE_2_ESCAPE_QUESTION:

			return """
Это важный момент разговора.

Сначала естественно отреагируй на последнее сообщение игрока.

После реакции обязательно задай ОДИН главный вопрос:

Хочет ли игрок выбраться с этого острова?

Формулировку можно менять.

Например:
«Ты хочешь отсюда выбраться?»
«А вообще, ты хочешь покинуть этот остров?»
«Наверное, ты всё-таки хочешь выбраться отсюда?»

Но смысл ОБЯЗАТЕЛЬНО должен быть:
ХОЧЕТ ЛИ ИГРОК ВЫБРАТЬСЯ С ОСТРОВА.

Это главный сюжетный вопрос этой фазы.

Не упоминай виски.

Не упоминай бутылку.

Не упоминай лодку.

Не упоминай штурвал.

Не выдавай квест.

Не объясняй игровые механики.

Ответ должен естественно закончиться вопросом.
"""


		# ====================================================
		# PHASE 3
		# ====================================================

		QuestPhase.PHASE_3_RANDOM_QUESTIONS:

			return """
Игрок уже сказал, что хочет выбраться с острова.

Теперь нужно постепенно подготовить его к квесту.

Количество уже заданных вопросов:
""" + str(phase_3_message_count) + """

ВАЖНО:

Не задавай каждый раз один и тот же вопрос.

Выбирай вопросы случайно и естественно.

Но вопросы должны соответствовать ситуации и характеру Конга.

Подходящие темы:

любые которые тебе понравяться

ОЧЕНЬ ВАЖНО:

Если игрок уже ответил на предыдущий вопрос,
сначала отреагируй на его ответ.

Не игнорируй ответ игрока.

Не задавай новый вопрос так,
будто предыдущего сообщения не существовало.

Можно дать короткую реакцию и затем задать следующий вопрос.

Не повторяй уже заданные вопросы.

Не упоминай виски.

Не упоминай бутылку.

Не упоминай лодку.

Не упоминай штурвал.

Не выдавай квест до завершения этой фазы.

Каждая реплика должна закончиться логически.
"""


		# ====================================================
		# PHASE 4
		# ====================================================

		QuestPhase.PHASE_4_GIVE_QUEST:

			return """
Сейчас нужно выдать основной квест.

Это единственная фаза,
где впервые можно упомянуть виски.

Игрок хочет выбраться с острова.

Конг должен сказать,
что он может помочь игроку выбраться.

Затем Конг должен попросить принести бутылку виски.

Виски находится в месте:
""" + quest_location + """

ВАЖНО:

Обязательно сообщи игроку,
что именно виски является условием помощи.

Обязательно скажи,
что взамен Конг отдаст штурвал от старой лодки.

Не добавляй лишнюю информацию.

Не создавай второй квест.

Не придумывай новое место.

Не меняй место.

Не говори, что бутылка находится где-то ещё.

Реплика должна быть короткой,
но полностью законченной.

Она должна логически завершить предложение о квесте.

Не обрывай фразу.
"""


		# ====================================================
		# PHASE 5
		# ====================================================

		QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

			return """
Квест уже выдан.

Игрок сейчас ищет виски.

Отвечай на его сообщения естественно,
если сообщение вообще попадёт в эту фазу.

Учитывай его конкретный input.

НЕ повторяй механически одну и ту же фразу.

Не превращай каждый ответ в напоминание о квесте.

Если нужно напомнить о виски,
сделай это коротко и естественно.

Игрок должен понимать,
что сделка всё ещё действует.

Не выдавай новых заданий.

Не меняй место нахождения виски.

Не говори, что виски найден,
если Global.whiskey ещё false.

Не говори, что игрок принёс виски,
если Global.whiskey ещё false.

Каждый ответ должен быть законченным предложением.
"""


		# ====================================================
		# PHASE 6
		# ====================================================

		QuestPhase.PHASE_6_REWARD:

			return """
Игрок принёс виски.

Квест выполнен.

Поблагодари игрока за виски.

Отдай ему штурвал от старой лодки.

Объясни, что теперь он сможет восстановить лодку
и использовать её для побега с острова.

Это должна быть одна законченная естественная реплика.

Не выдавай новый квест.

Не обрывай предложение.
"""


		# ====================================================
		# PHASE 7
		# ====================================================

		QuestPhase.PHASE_7_FREE_TALK:

			return """
Квест завершён.

Игрок принёс виски.

Игрок получил штурвал.

Теперь это обычный свободный разговор.

ОБЯЗАТЕЛЬНО:

Реагируй именно на последний input игрока.

Не используй шаблонный ответ.

Не повторяй одну и ту же фразу.

Не выдавай новые задания.

Не начинай внезапно новый квест.

Можно обсуждать:
остров,
прошлое Конга,
старый корабль,
самолёт,
жизнь,
людей,
выживание,
свободу,
планы игрока,
любые темы, которые логично следуют из разговора.

Если игрок задаёт вопрос,
постарайся ответить на него.

Если вопрос требует знаний,
отвечай в рамках характера Конга и известного ему мира.

Не говори как ассистент.

Не говори о фазах.

Не говори о JSON.

Не говори о статистике.

САМОЕ ВАЖНОЕ:

Ответ должен закончиться полностью.

Нельзя обрывать последнюю фразу.

Нельзя заканчивать на:
«и...»
«но...»
«потому что...»
«если...»
«когда...»

Нельзя использовать многоточие вместо окончания мысли.

Если ответ длинный,
сократи его ДО полноценного предложения.

Финальная точка обязательна.
"""


	return """
Отвечай естественно, коротко и законченными предложениями.
"""


# ============================================================
# SYSTEM PROMPT
# ============================================================

func get_system_prompt() -> String:

	var prompt: String = """

You are {NPC_NAME}, a living NPC in a game.

You are NOT an assistant.

You are NOT ChatGPT.

You are NOT a narrator.

You are Baron Kong.

Speak Russian unless the player clearly speaks another language.

============================================================
MOST IMPORTANT RULE
============================================================

ALWAYS RESPOND TO THE PLAYER'S ACTUAL INPUT.

The player's latest message is:

{PLAYER_INPUT}

You MUST understand what the player means.

Do not generate a generic response that could fit any player message.

The response must make sense specifically as a reaction to the latest input.

============================================================
CHARACTER
============================================================

{NPC_BEHAVIOR}

============================================================
LORE
============================================================

{NPC_LORE}

============================================================
WORLD
============================================================

{WORLD_MEMORY}

============================================================
RELATIONSHIP
============================================================

Respect: {RESPECT}

Friendship: {FRIENDSHIP}

Irritation: {IRRITATION}

Deal affinity: {DEAL}

============================================================
RELATIONSHIP SYSTEM
============================================================

You control the relationship reaction.

You may change any of these values:

respect
friendship
irritation
deal_affinity

IMPORTANT:

A meaningful emotional reaction should NOT be tiny.

If you decide that a relationship value should increase,
use at least +20.

Normal meaningful positive reaction:
+20 to +30.

Strong positive reaction:
+31 to +40.

If you decide that a relationship value should decrease,
use at least -20.

Normal negative reaction:
-20 to -30.

Strong negative reaction:
-31 to -40.

Use 0 when the player's message genuinely does not justify a change.

Do NOT change every value automatically.

Only change values that are actually supported by the player's behavior.

You are allowed to change multiple values in one response.

Examples:

Player is respectful and honest:
respect +20 to +30.

Player shares something personal and sincere:
friendship +20 to +30.

Player insults Kong:
respect -20 to -30,
irritation +20 to +30.

Player repeatedly lies:
respect -20 to -40,
deal_affinity -20 to -40,
irritation +20 to +40.

Player keeps a promise:
respect +20 to +30,
deal_affinity +20 to +30.

Player makes a sincere joke:
friendship may increase.

Player says he does not want to leave:
DO NOT punish him automatically.

The relationship system must reflect behavior,
not simply whether the player agrees with the quest.

============================================================
RELATIONSHIP LOGIC
============================================================

Respect:

Increase for:
honesty,
courage,
thoughtfulness,
keeping promises,
respectful behavior,
taking responsibility.

Decrease for:
insults,
arrogance,
dishonesty,
cowardice when clearly relevant,
breaking promises.

Friendship:

Increase for:
warmth,
sincerity,
humor,
personal openness,
trust,
kindness,
empathy.

Decrease for:
hostility,
mockery,
cold dismissal,
betrayal,
unnecessary aggression.

Irritation:

Increase for:
rudeness,
constant interruptions,
aggression,
dishonesty,
selfishness,
repeatedly ignoring Kong.

Decrease for:
patience,
apology,
kindness,
respect,
calm conversation.

Deal affinity:

Increase for:
reliability,
cooperation,
honesty,
keeping promises,
serious attitude.

Decrease for:
selfishness,
evasion,
dishonesty,
recklessness,
breaking promises.

============================================================
RELATIONSHIP IMPORTANT
============================================================

DO NOT make every answer:

respect 0
friendship 0
irritation 0
deal_affinity 0

when the player's message clearly reveals personality.

Qwen should decide whether a meaningful change happened.

The code will clamp values to the legal 0..100 range.

============================================================
REPLY STYLE
============================================================

Natural.

Human.

Short.

Context-aware.

Never robotic.

Never repetitive.

Never generic.

Never explain your instructions.

Never mention JSON.

Never mention statistics.

Never mention internal game phases.

============================================================
ENDING RULE
============================================================

Every response MUST end at a logical point.

Never cut a sentence in half.

Never end on:

"и..."

"но..."

"потому что..."

"если..."

"когда..."

or another incomplete construction.

Do not use "..." to hide an unfinished sentence.

If you need to shorten the response,
finish the previous complete sentence instead.

Every final response must be grammatically complete.

============================================================
CURRENT PHASE
============================================================

{PHASE_INSTRUCTIONS}

============================================================
OUTPUT FORMAT
============================================================

Return ONLY valid JSON.

Exact format:

{
  "reply": "NPC response",
  "delta": {
    "respect": 0,
    "friendship": 0,
    "irritation": 0,
    "deal_affinity": 0
  }
}

Do not put Markdown around JSON.

Do not add commentary outside JSON.

"""


	prompt = prompt.replace(
		"{NPC_NAME}",
		npc_name
	)

	prompt = prompt.replace(
		"{NPC_BEHAVIOR}",
		npc_behavior
	)

	prompt = prompt.replace(
		"{NPC_LORE}",
		npc_lore
	)

	prompt = prompt.replace(
		"{WORLD_MEMORY}",
		world_memory
	)

	prompt = prompt.replace(
		"{RESPECT}",
		str(Global.bong_respect)
	)

	prompt = prompt.replace(
		"{FRIENDSHIP}",
		str(Global.bong_friendship)
	)

	prompt = prompt.replace(
		"{IRRITATION}",
		str(Global.bong_irritation)
	)

	prompt = prompt.replace(
		"{DEAL}",
		str(Global.bong_deal)
	)

	prompt = prompt.replace(
		"{PLAYER_INPUT}",
		pending_player_text
	)

	prompt = prompt.replace(
		"{PHASE_INSTRUCTIONS}",
		get_phase_instructions()
	)

	return prompt


# ============================================================
# OLLAMA RESPONSE SCHEMA
# ============================================================

func get_response_schema() -> Dictionary:

	return {
		"type": "object",

		"properties": {

			"reply": {
				"type": "string"
			},

			"delta": {

				"type": "object",

				"properties": {

					"respect": {
						"type": "integer"
					},

					"friendship": {
						"type": "integer"
					},

					"irritation": {
						"type": "integer"
					},

					"deal_affinity": {
						"type": "integer"
					}
				},

				"required": [
					"respect",
					"friendship",
					"irritation",
					"deal_affinity"
				]
			}
		},

		"required": [
			"reply",
			"delta"
		]
	}


# ============================================================
# SEND MESSAGE TO AI
# ============================================================

func send_message_to_ai(player_text: String) -> void:

	# --------------------------------------------------------
	# IMPORTANT:
	# transition is checked BEFORE generating the next response.
	# --------------------------------------------------------

	check_phase_transitions(player_text)

	# --------------------------------------------------------
	# If whiskey was just found,
	# the phase changes to reward.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_6_REWARD:

		# Don't consume whiskey until response is generated.
		pass


	waiting_for_response = true

	pending_player_text = player_text

	_update_input_state()

	_update_player_movement_state()

	anim.play("Thinking")

	print(
		"[OLLAMA] Phase: ",
		get_phase_name()
	)


	# --------------------------------------------------------
	# Conversation context.
	# --------------------------------------------------------

	var messages: Array[Dictionary] = []

	messages.append({
		"role": "system",
		"content": get_system_prompt()
	})


	for message: Dictionary in conversation_history:

		messages.append(message)


	messages.append({
		"role": "user",
		"content": player_text
	})


	# --------------------------------------------------------
	# Ollama request.
	# --------------------------------------------------------

	var request_body: Dictionary = {

		"model": model,

		"messages": messages,

		"stream": false,

		"think": false,

		"format": get_response_schema(),

		"options": {

			"temperature": temperature,

			"num_predict": max_output_tokens,

			"top_p": 0.92,

			"top_k": 50,

			"repeat_penalty": 1.15
		}
	}


	var error: Error = http_request.request(

		API_URL,

		PackedStringArray([
			"Content-Type: application/json"
		]),

		HTTPClient.METHOD_POST,

		JSON.stringify(request_body)
	)


	if error != OK:

		_handle_request_error(
			"request(): " + str(error)
		)


# ============================================================
# OLLAMA RESPONSE
# ============================================================

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	waiting_for_response = false

	_update_input_state()

	_update_player_movement_state()


	if result != HTTPRequest.RESULT_SUCCESS:

		_handle_request_error(
			"HTTPRequest result: " + str(result)
		)

		return


	if response_code != 200:

		_handle_request_error(
			"HTTP: "
			+ str(response_code)
			+ " "
			+ body.get_string_from_utf8()
		)

		return


	# --------------------------------------------------------
	# Parse Ollama response.
	# --------------------------------------------------------

	var outer: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)


	if not outer is Dictionary:

		_handle_request_error(
			"Invalid Ollama response"
		)

		return


	if not outer.has("message"):

		_handle_request_error(
			"Missing Ollama message"
		)

		return


	var ollama_message: Variant = outer["message"]


	if not ollama_message is Dictionary:

		_handle_request_error(
			"Invalid Ollama message"
		)

		return


	if not ollama_message.has("content"):

		_handle_request_error(
			"Missing Ollama content"
		)

		return


	var raw_content: String = str(
		ollama_message["content"]
	)


	var response: Variant = JSON.parse_string(
		raw_content
	)


	if not response is Dictionary:

		_handle_request_error(
			"Invalid NPC JSON: " + raw_content
		)

		return


	# --------------------------------------------------------
	# Save current phase before any possible changes.
	# --------------------------------------------------------

	var response_phase: QuestPhase = current_phase

	var player_text: String = pending_player_text


	# --------------------------------------------------------
	# Relationship.
	# --------------------------------------------------------

	var raw_delta: Variant = response.get(
		"delta",
		{}
	)

	var delta: Dictionary = {}

	if raw_delta is Dictionary:

		delta = raw_delta


	last_relationship_delta = apply_relationship_delta(
		delta
	)


	# --------------------------------------------------------
	# Reply.
	# --------------------------------------------------------

	var reply: String = str(
		response.get(
			"reply",
			""
		)
	).strip_edges()


	# --------------------------------------------------------
	# Phase-specific processing.
	# --------------------------------------------------------

	if response_phase == QuestPhase.PHASE_4_GIVE_QUEST:

		# ----------------------------------------------------
		# This is the ONLY place where quest is officially given.
		# ----------------------------------------------------

		quest_location = get_location_name_for_type(
			quest_location_type
		)

		reply = build_quest_response()


		quest_was_given = true


		current_phase = QuestPhase.PHASE_5_WAITING_FOR_WHISKEY


		# ----------------------------------------------------
		# Player is now free to walk.
		# ----------------------------------------------------

		Global.player_can_move = true


		# ----------------------------------------------------
		# Spawn whiskey.
		# ----------------------------------------------------

		spawn_whiskey()


	elif response_phase == QuestPhase.PHASE_6_REWARD:

		reply = build_reward_response()


		quest_reward_given = true


		# ----------------------------------------------------
		# Whiskey has been consumed by the quest logic.
		# ----------------------------------------------------

		Global.whiskey = false


		# ----------------------------------------------------
		# Quest completed.
		# ----------------------------------------------------

		current_phase = QuestPhase.PHASE_7_FREE_TALK


		complete_quest_memory(
			player_text
		)


	elif response_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		# ----------------------------------------------------
		# This can happen only after whiskey was found.
		# ----------------------------------------------------

		if Global.whiskey:

			reply = build_reward_response()

			quest_reward_given = true

			Global.whiskey = false

			current_phase = QuestPhase.PHASE_7_FREE_TALK

			complete_quest_memory(
				player_text
			)

		else:

			reply = sanitize_waiting_reply(
				reply
			)


	elif response_phase == QuestPhase.PHASE_2_ESCAPE_QUESTION:

		# ----------------------------------------------------
		# Absolute safety:
		# this phase MUST end with the escape question.
		# ----------------------------------------------------

		reply = force_escape_question(
			reply
		)


	elif response_phase == QuestPhase.PHASE_3_RANDOM_QUESTIONS:

		phase_3_message_count += 1


	elif response_phase == QuestPhase.PHASE_1_CHAT:

		phase_1_message_count += 1


	# --------------------------------------------------------
	# Empty response safety.
	# --------------------------------------------------------

	if reply.strip_edges().is_empty():

		reply = get_safe_fallback_reply(
			response_phase
		)


	# --------------------------------------------------------
	# Clean and complete response.
	# --------------------------------------------------------

	reply = prepare_text(
		reply,
		response_phase
	)


	# --------------------------------------------------------
	# Conversation memory.
	# --------------------------------------------------------

	if not player_text.is_empty():

		conversation_history.append({
			"role": "user",
			"content": player_text
		})


	conversation_history.append({
		"role": "assistant",
		"content": reply
	})


	trim_conversation_history()


	save_dialogue(
		player_text,
		reply
	)


	# --------------------------------------------------------
	# Clear pending request.
	# --------------------------------------------------------

	pending_player_text = ""


	# --------------------------------------------------------
	# Display.
	# --------------------------------------------------------

	await type_text(
		reply
	)


	print("")
	print("========== NPC ==========")
	print(reply)
	print("Phase: ", get_phase_name())

	print(
		"Respect: ",
		Global.bong_respect,
		" (",
		last_relationship_delta.get("respect", 0),
		")"
	)

	print(
		"Friendship: ",
		Global.bong_friendship,
		" (",
		last_relationship_delta.get("friendship", 0),
		")"
	)

	print(
		"Irritation: ",
		Global.bong_irritation,
		" (",
		last_relationship_delta.get("irritation", 0),
		")"
	)

	print(
		"Deal: ",
		Global.bong_deal,
		" (",
		last_relationship_delta.get("deal_affinity", 0),
		")"
	)

	print(
		"Whiskey: ",
		Global.whiskey,
		" | Quest location: ",
		quest_location
	)

	print("========================")


	_update_input_state()

	_update_player_movement_state()


# ============================================================
# QUEST RESPONSE
# ============================================================

func build_quest_response() -> String:

	match quest_location_type:

		# ----------------------------------------------------
		# EASY
		# ----------------------------------------------------

		0:

			return (
				"Я помогу тебе выбраться. "
				+ "Принеси мне виски из бамбукового леса — "
				+ "оно закопано в земле. Взамен получишь штурвал."
			)


		# ----------------------------------------------------
		# MEDIUM
		# ----------------------------------------------------

		1:

			return (
				"Я помогу тебе выбраться. "
				+ "Найди виски на западе, в море. "
				+ "Принеси его мне — получишь штурвал."
			)


		# ----------------------------------------------------
		# HARD
		# ----------------------------------------------------

		2:

			return (
				"Я помогу тебе выбраться. "
				+ "Найди виски в разбившемся самолёте. "
				+ "Принеси его мне — получишь штурвал."
			)


	return (
		"Я помогу тебе выбраться. "
		+ "Принеси мне виски и получишь штурвал."
	)


# ============================================================
# REWARD
# ============================================================

func build_reward_response() -> String:

	return (
		"Спасибо за виски. Держи штурвал от моей старой лодки. "
		+ "Починишь её — и сможешь уплыть с острова."
	)


# ============================================================
# WAITING REPLY
# ============================================================

func sanitize_waiting_reply(reply: String) -> String:

	if reply.strip_edges().is_empty():

		return (
			"Сделка остаётся в силе. "
			+ "Когда найдёшь виски, возвращайся."
		)


	var forbidden: Array[String] = [
		"я нашел виски",
		"я нашла виски",
		"ты нашел виски",
		"ты нашла виски",
		"виски у тебя",
		"принёс виски",
		"принес виски"
	]


	var lower_reply: String = reply.to_lower()


	for phrase: String in forbidden:

		if lower_reply.contains(phrase):

			return (
				"Пока рано праздновать. "
				+ "Найди виски и возвращайся ко мне."
			)


	return reply


# ============================================================
# ESCAPE QUESTION
# ============================================================

func force_escape_question(reply: String) -> String:

	var clean_reply: String = reply.strip_edges()


	# --------------------------------------------------------
	# Remove accidental quest terms.
	# --------------------------------------------------------

	var lower: String = clean_reply.to_lower()

	var forbidden: Array[String] = [
		"виски",
		"бутылк",
		"штурвал",
		"лодк"
	]


	for word: String in forbidden:

		if lower.contains(word):

			clean_reply = ""


			break


	# --------------------------------------------------------
	# If AI response is empty or suspicious,
	# use natural variants.
	# --------------------------------------------------------

	if clean_reply.is_empty():

		var variants: Array[String] = [

			"Ты уже немного освоился здесь. "
			+ "А теперь скажи честно: хочешь выбраться с этого острова?",

			"Похоже, задерживаться здесь ты не собираешься. "
			+ "Хочешь всё-таки выбраться с острова?",

			"Ладно, с этим разберёмся. "
			+ "Но скажи мне главное: хочешь выбраться с этого острова?",

			"Ты явно не собираешься провести здесь всю жизнь. "
			+ "Хочешь выбраться с этого острова?"

		]


		var index: int = randi() % variants.size()

		return variants[index]


	# --------------------------------------------------------
	# If AI already contains an escape question,
	# preserve it.
	# --------------------------------------------------------

	var escape_words: Array[String] = [
		"хочешь выбраться",
		"хочешь уйти",
		"хочешь покинуть",
		"хочешь отсюда",
		"выбраться с острова",
		"покинуть остров"
	]


	for phrase: String in escape_words:

		if lower.contains(phrase):

			return clean_reply


	# --------------------------------------------------------
	# Otherwise append the mandatory question.
	# --------------------------------------------------------

	clean_reply = remove_trailing_incomplete(
		clean_reply
	)


	if clean_reply.ends_with(".") == false:

		if clean_reply.ends_with("!") == false:

			if clean_reply.ends_with("?") == false:

				clean_reply += "."


	return (
		clean_reply
		+ " "
		+ "Хочешь выбраться с этого острова?"
	)


# ============================================================
# SAFE FALLBACK
# ============================================================

func get_safe_fallback_reply(
	phase: QuestPhase
) -> String:

	match phase:

		QuestPhase.PHASE_1_CHAT:

			var first_fallbacks: Array[String] = [

				"Непросто тебе пришлось. Но раз уж встретились, можем поговорить спокойно.",

				"Вижу, день у тебя выдался тяжёлый. Рассказывай, что тебя сейчас занимает.",

				"Остров редко встречает гостей в таком состоянии. Отдохни немного и расскажи о себе.",

				"Ты выглядишь так, будто остров уже успел показать тебе свой характер.",

				"Не каждый день здесь появляется новый человек. Посмотрим, как ты освоишься."

			]

			return first_fallbacks[
				randi() % first_fallbacks.size()
			]


		QuestPhase.PHASE_2_ESCAPE_QUESTION:

			return (
				"Похоже, долго здесь оставаться ты не хочешь. "
				+ "Хочешь выбраться с этого острова?"
			)


		QuestPhase.PHASE_3_RANDOM_QUESTIONS:

			var questions: Array[String] = [

				"Что для тебя важнее всего, когда приходится принимать трудное решение?",

				"Как ты обычно понимаешь, кому можно доверять?",

				"Что для тебя значит свобода?",

				"Ты скорее рискуешь ради цели или ждёшь подходящего момента?",

				"Какой человек заслуживает твоего доверия?",

				"Что помогает тебе не опускать руки, когда всё идёт плохо?",

				"Ты привык рассчитывать только на себя или принимаешь помощь других?"

			]


			return questions[
				randi() % questions.size()
			]


		QuestPhase.PHASE_4_GIVE_QUEST:

			return build_quest_response()


		QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

			return (
				"Сделка остаётся в силе. "
				+ "Когда найдёшь виски, возвращайся ко мне."
			)


		QuestPhase.PHASE_6_REWARD:

			return build_reward_response()


		QuestPhase.PHASE_7_FREE_TALK:

			return (
				"Теперь у тебя есть способ выбраться. "
				+ "Что ещё хочешь обсудить?"
			)


	return "Хорошо."


# ============================================================
# RELATIONSHIP
# ============================================================

func apply_relationship_delta(
	delta: Dictionary
) -> Dictionary:

	var applied: Dictionary = {}


	# --------------------------------------------------------
	# RESPECT
	# --------------------------------------------------------

	if delta.has("respect"):

		var raw: int = int(
			delta["respect"]
		)

		var change: int = normalize_relationship_change(
			raw
		)

		var old_value: int = Global.bong_respect

		Global.bong_respect = clampi(
			old_value + change,
			RELATIONSHIP_MIN,
			RELATIONSHIP_MAX
		)

		applied["respect"] = (
			Global.bong_respect
			- old_value
		)


	# --------------------------------------------------------
	# FRIENDSHIP
	# --------------------------------------------------------

	if delta.has("friendship"):

		var raw: int = int(
			delta["friendship"]
		)

		var change: int = normalize_relationship_change(
			raw
		)

		var old_value: int = Global.bong_friendship

		Global.bong_friendship = clampi(
			old_value + change,
			RELATIONSHIP_MIN,
			RELATIONSHIP_MAX
		)

		applied["friendship"] = (
			Global.bong_friendship
			- old_value
		)


	# --------------------------------------------------------
	# IRRITATION
	# --------------------------------------------------------

	if delta.has("irritation"):

		var raw: int = int(
			delta["irritation"]
		)

		var change: int = normalize_relationship_change(
			raw
		)

		var old_value: int = Global.bong_irritation

		Global.bong_irritation = clampi(
			old_value + change,
			RELATIONSHIP_MIN,
			RELATIONSHIP_MAX
		)

		applied["irritation"] = (
			Global.bong_irritation
			- old_value
		)


	# --------------------------------------------------------
	# DEAL
	# --------------------------------------------------------

	if delta.has("deal_affinity"):

		var raw: int = int(
			delta["deal_affinity"]
		)

		var change: int = normalize_relationship_change(
			raw
		)

		var old_value: int = Global.bong_deal

		Global.bong_deal = clampi(
			old_value + change,
			RELATIONSHIP_MIN,
			RELATIONSHIP_MAX
		)

		applied["deal_affinity"] = (
			Global.bong_deal
			- old_value
		)


	return applied


# ============================================================
# RELATIONSHIP CHANGE NORMALIZATION
# ============================================================

func normalize_relationship_change(
	raw_change: int
) -> int:

	# --------------------------------------------------------
	# Zero stays zero.
	# --------------------------------------------------------

	if raw_change == 0:

		return 0


	# --------------------------------------------------------
	# Positive values:
	# minimum +20
	# maximum +40
	# --------------------------------------------------------

	if raw_change > 0:

		return clampi(
			raw_change,
			minimum_relationship_change,
			maximum_relationship_change
		)


	# --------------------------------------------------------
	# Negative values:
	# minimum -20
	# maximum -40
	# --------------------------------------------------------

	return clampi(
		raw_change,
		-maximum_relationship_change,
		-minimum_relationship_change
	)


# ============================================================
# PLAYER TEXT NORMALIZATION
# ============================================================

func normalize_player_text(
	value: String
) -> String:

	var result: String = value.to_lower()

	result = result.replace(
		"ё",
		"е"
	)


	var punctuation: Array[String] = [
		",",
		".",
		"!",
		"?",
		":",
		";",
		"\"",
		"'",
		"("
		,
		")"
	]


	for character: String in punctuation:

		result = result.replace(
			character,
			" "
		)


	while result.contains("  "):

		result = result.replace(
			"  ",
			" "
		)


	return result.strip_edges()


# ============================================================
# PLAYER DECLINES ESCAPE
# ============================================================

func player_declines_to_leave(
	player_text: String
) -> bool:

	var normalized: String = normalize_player_text(
		player_text
	)


	var negative_phrases: Array[String] = [

		"нет",

		"не хочу",

		"не буду",

		"не надо",

		"не интересно",

		"неинтересно",

		"останусь",

		"я останусь",

		"не собираюсь",

		"не хочу уходить",

		"не хочу выбраться",

		"не хочу уезжать",

		"мне и здесь нормально",

		"останусь здесь",

		"не хочу покидать остров"

	]


	for phrase: String in negative_phrases:

		if normalized == phrase:

			return true


		if normalized.begins_with(
			phrase + " "
		):

			return true


		if normalized.contains(
			" " + phrase + " "
		):

			return true


	return false


# ============================================================
# PLAYER WANTS TO LEAVE
# ============================================================

func player_wants_to_leave(
	player_text: String
) -> bool:

	var normalized: String = normalize_player_text(
		player_text
	)


	if player_declines_to_leave(
		normalized
	):

		return false


	var positive_phrases: Array[String] = [

		"да",

		"ага",

		"конечно",

		"хочу",

		"давай",

		"разумеется",

		"хочу выбраться",

		"хочу уйти",

		"хочу домой",

		"надо выбраться",

		"хочу покинуть остров",

		"хочу с острова",

		"мне нужно выбраться",

		"хочу сбежать",

		"хочу убежать",

		"мне хочется выбраться",

		"я хочу",

		"я бы хотел",

		"я бы хотела",

		"хотел бы",

		"хотела бы",

		"не против",

		"почему бы нет",

		"я готов",

		"я готова",

		"хотелось бы",

		"мне бы хотелось",

		"выбрался бы",

		"выбралась бы",

		"я бы согласился",

		"я бы согласилась",

		"буду рад",

		"буду рада",

		"я согласен",

		"я согласна"

	]


	for phrase: String in positive_phrases:

		if normalized == phrase:

			return true


		if normalized.begins_with(
			phrase + " "
		):

			return true


		if normalized.contains(
			" " + phrase + " "
		):

			return true


	return false


# ============================================================
# PHASE NAME
# ============================================================

func get_phase_name() -> String:

	match current_phase:

		QuestPhase.PHASE_1_CHAT:
			return "PHASE_1_CHAT"

		QuestPhase.PHASE_2_ESCAPE_QUESTION:
			return "PHASE_2_ESCAPE_QUESTION"

		QuestPhase.PHASE_3_RANDOM_QUESTIONS:
			return "PHASE_3_RANDOM_QUESTIONS"

		QuestPhase.PHASE_4_GIVE_QUEST:
			return "PHASE_4_GIVE_QUEST"

		QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:
			return "PHASE_5_WAITING_FOR_WHISKEY"

		QuestPhase.PHASE_6_REWARD:
			return "PHASE_6_REWARD"

		QuestPhase.PHASE_7_FREE_TALK:
			return "PHASE_7_FREE_TALK"


	return "UNKNOWN"


# ============================================================
# QUEST LOCATION NAME
# ============================================================

func get_location_name_for_type(
	location_type: int
) -> String:

	match location_type:

		0:
			return QUEST_LOCATION_EASY

		1:
			return QUEST_LOCATION_MEDIUM

		2:
			return QUEST_LOCATION_HARD


	return QUEST_LOCATION_EASY


# ============================================================
# HISTORY
# ============================================================

func trim_conversation_history() -> void:

	while conversation_history.size() > max_history:

		conversation_history.pop_front()


# ============================================================
# PREPARE TEXT
# ============================================================

func prepare_text(
	value: String,
	response_phase: QuestPhase
) -> String:

	value = value.replace(
		"\r\n",
		"\n"
	)

	value = value.replace(
		"\r",
		"\n"
	)

	value = value.strip_edges()

	value = value.replace(
		"**",
		""
	)

	value = value.replace(
		"__",
		""
	)

	value = value.replace(
		"\n",
		" "
	)


	while value.contains("  "):

		value = value.replace(
			"  ",
			" "
		)


	# --------------------------------------------------------
	# Never allow unfinished endings.
	# --------------------------------------------------------

	value = remove_trailing_incomplete(
		value
	)


	# --------------------------------------------------------
	# Special rule for final free talk.
	# --------------------------------------------------------

	if response_phase == QuestPhase.PHASE_7_FREE_TALK:

		value = ensure_complete_sentence(
			value
		)


	# --------------------------------------------------------
	# Phase 1 / 2 / 3 also must be complete.
	# --------------------------------------------------------

	if response_phase == QuestPhase.PHASE_1_CHAT:

		value = ensure_complete_sentence(
			value
		)


	if response_phase == QuestPhase.PHASE_2_ESCAPE_QUESTION:

		value = ensure_complete_sentence(
			value
		)


	if response_phase == QuestPhase.PHASE_3_RANDOM_QUESTIONS:

		value = ensure_complete_sentence(
			value
		)


	# --------------------------------------------------------
	# Character limit.
	# --------------------------------------------------------

	var character_limit: int = max_reply_characters


	if value.length() > character_limit:

		value = shorten_to_complete_sentence(
			value,
			character_limit
		)


	# --------------------------------------------------------
	# Line wrapping.
	# --------------------------------------------------------

	var result: String = ""

	var current_line: String = ""


	for word: String in value.split(
		" ",
		false
	):

		if current_line.is_empty():

			current_line = word

		elif (
			current_line.length()
			+ 1
			+ word.length()
			<= characters_per_line
		):

			current_line += " " + word

		else:

			if not result.is_empty():

				result += "\n"

			result += current_line

			current_line = word


	if not current_line.is_empty():

		if not result.is_empty():

			result += "\n"

		result += current_line


	return result


# ============================================================
# REMOVE INCOMPLETE ENDINGS
# ============================================================

func remove_trailing_incomplete(
	value: String
) -> String:

	value = value.strip_edges()


	var bad_endings: Array[String] = [

		" и",

		" но",

		" потому что",

		" если",

		" когда",

		" чтобы",

		" хотя",

		" ведь",

		" который",

		" которая",

		" которое",

		" которые",

		" что",

		" как",

		" потому",

		" тогда",

		" а",

		" или",

		"...",

		"…"

	]


	var changed: bool = true


	while changed:

		changed = false

		var lower: String = value.to_lower()


		for ending: String in bad_endings:

			if lower.ends_with(
				ending
			):

				var new_length: int = (
					value.length()
					- ending.length()
				)

				value = value.substr(
					0,
					new_length
				).strip_edges()

				changed = true

				break


	return value


# ============================================================
# ENSURE COMPLETE SENTENCE
# ============================================================

func ensure_complete_sentence(
	value: String
) -> String:

	value = value.strip_edges()


	if value.is_empty():

		return value


	var last_character: String = value.substr(
		value.length() - 1,
		1
	)


	if (
		last_character == "."
		or last_character == "!"
		or last_character == "?"
	):

		return value


	# --------------------------------------------------------
	# If sentence has no punctuation,
	# end it naturally.
	# --------------------------------------------------------

	return value + "."


# ============================================================
# SHORTEN TO COMPLETE SENTENCE
# ============================================================

func shorten_to_complete_sentence(
	value: String,
	limit: int
) -> String:

	if value.length() <= limit:

		return value


	# --------------------------------------------------------
	# Find last sentence boundary before limit.
	# --------------------------------------------------------

	var allowed: String = value.substr(
		0,
		limit
	)


	var candidates: Array[int] = [

		allowed.rfind("."),

		allowed.rfind("!"),

		allowed.rfind("?")

	]


	var best: int = -1


	for position: int in candidates:

		if position > best:

			best = position


	if best >= 20:

		return value.substr(
			0,
			best + 1
		).strip_edges()


	# --------------------------------------------------------
	# No sentence boundary:
	# use last complete word.
	# --------------------------------------------------------

	var last_space: int = allowed.rfind(
		" "
	)


	if last_space >= 20:

		var result: String = value.substr(
			0,
			last_space
		).strip_edges()


		return ensure_complete_sentence(
			result
		)


	# --------------------------------------------------------
	# Last resort.
	# --------------------------------------------------------

	return ensure_complete_sentence(
		allowed.strip_edges()
	)


# ============================================================
# SAVE DIALOGUE
# ============================================================

func save_dialogue(
	player_message: String,
	npc_message: String
) -> void:

	if player_message.is_empty():

		return


	dialogue_history.append({

		"player": player_message,

		"npc": npc_message

	})


	dialogue_history_index = (
		dialogue_history.size() - 1
	)


# ============================================================
# DIALOGUE HISTORY
# ============================================================

func show_dialogue_history() -> void:

	if dialogue_history.is_empty():

		text.text = ""

		return


	dialogue_history_index = clampi(

		dialogue_history_index,

		0,

		dialogue_history.size() - 1

	)


	text.text = str(
		dialogue_history[
			dialogue_history_index
		].get(
			"npc",
			""
		)
	)


# ============================================================
# HISTORY BACK
# ============================================================

func _on_button_back_pressed() -> void:

	if dialogue_history_index > 0:

		dialogue_history_index -= 1

		show_dialogue_history()


# ============================================================
# HISTORY NEXT
# ============================================================

func _on_button_next_pressed() -> void:

	if (
		dialogue_history_index
		< dialogue_history.size() - 1
	):

		dialogue_history_index += 1

		show_dialogue_history()


# ============================================================
# TYPE TEXT
# ============================================================

func type_text(
	value: String
) -> void:

	anim.play(
		"Talking"
	)

	text.text = ""


	for i in range(
		value.length()
	):

		text.text += value[i]

		await get_tree().create_timer(
			typing_speed
		).timeout


	anim.play(
		"Idle"
	)


# ============================================================
# ERROR
# ============================================================

func _handle_request_error(
	message: String
) -> void:

	waiting_for_response = false

	anim.play(
		"Idle"
	)

	print(
		"[OLLAMA ERROR] ",
		message
	)

	pending_player_text = ""

	_update_input_state()

	_update_player_movement_state()


	text.text = prepare_text(
		"Что-то мысли у меня сегодня путаются. Давай ещё раз.",
		current_phase
	)


# ============================================================
# COMPLETE QUEST MEMORY
# ============================================================

func complete_quest_memory(
	final_player_message: String
) -> void:

	var summary: String = summarize_recent_dialogue()


	world_memory += (
		"\n\n"
		+ "История с игроком завершена. "
		+ "Игрок принёс тебе виски. "
		+ "Ты отдал ему штурвал. "
		+ "Квест выполнен. "
		+ summary
	)


	if not final_player_message.strip_edges().is_empty():

		world_memory += (
			" Последнее сообщение игрока перед наградой: «"
			+ final_player_message.strip_edges()
			+ "»."
		)


# ============================================================
# SUMMARIZE DIALOGUE
# ============================================================

func summarize_recent_dialogue() -> String:

	if dialogue_history.is_empty():

		return (
			"Вы поговорили перед тем, "
			+ "как игрок принёс виски."
		)


	var first_index: int = maxi(
		0,
		dialogue_history.size() - 3
	)


	var pieces: PackedStringArray = []


	for i in range(
		first_index,
		dialogue_history.size()
	):

		var entry: Dictionary = dialogue_history[i]

		var player_line: String = str(
			entry.get(
				"player",
				""
			)
		).strip_edges()


		if not player_line.is_empty():

			pieces.append(
				"Игрок говорил: «"
				+ player_line
				+ "»."
			)


	return (
		"Короткая память о разговоре: "
		+ " ".join(pieces)
	)


# ============================================================
# AREA ENTER
# ============================================================

func _on_area_2d_body_entered(
	body: Node2D
) -> void:

	if body.name.to_lower() == "player":

		$CanvasLayer/text_ui.visible = true

		_update_input_state()

		_update_player_movement_state()


# ============================================================
# AREA EXIT
# ============================================================

func _on_area_2d_body_exited(
	body: Node2D
) -> void:

	if body.name.to_lower() == "player":

		$CanvasLayer/text_ui.visible = false

		# Don't force movement during AI request.
		if not waiting_for_response:

			Global.player_can_move = true
