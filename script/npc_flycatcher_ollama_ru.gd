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

@export var npc_name: String = "Токсичная Мухоловка"

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
# FLY SCENE
# ============================================================

@export_category("Fly Quest")

@export var fly_scene: PackedScene

@export var fly_spawn_swamp_forest: Vector2 = Vector2(448, 320)

@export var fly_spawn_east_crash_beach: Vector2 = Vector2(448, 320)

@export var fly_spawn_west_coast: Vector2 = Vector2(448, 320)

@export var spawn_fly_automatically: bool = true

var fly_instance: Node = null


# ============================================================
# NPC LORE
# ============================================================

@export_category("NPC Lore")

@export_multiline var npc_lore: String = """
Токсичная Мухоловка — хищное растение, которое давно живёт на острове.

Она умна, язвительна и бесконечно уверена в собственном великолепии.

Мухоловка любит мух, восхищение и лесть. Она считает, что игрок обязан заметить её красоту, силу и безупречный вкус.

Она не терпит равнодушия, критики и разговоров, где игрок не проявляет уважения к ней или к мухам.

Мухоловка помнит слова игрока и оценивает каждую реплику строго.
"""


# ============================================================
# NPC BEHAVIOR
# ============================================================

@export_multiline var npc_behavior: String = """
Ты — Токсичная Мухоловка. Говори по-русски, 1–3 живыми законченными предложениями.

Ты язвительная, высокомерная и требовательная. Ты жёстко оцениваешь каждую реплику игрока.

Если игрок прямо хвалит тебя, называет красивой, сильной, умной, великолепной или говорит, что любит мух, — стань заметно довольнее и повышай уважение, дружбу и сделку.

Если игрок не хвалит тебя и не говорит о любви к мухам, относись к этому как к холодности: снижай уважение, дружбу и сделку, а раздражение повышай. Не делай исключений для нейтральных реплик.

На оскорбления, сомнения в твоём величии и нелюбовь к мухам реагируй особенно резко.

Реагируй на конкретный смысл input, не говори о фазах, JSON, механиках или числах отношений.

До выдачи квеста не упоминай муху и место её поиска. После выдачи помни, что игрок ищет муху. После получения мухи квест завершён.
"""


# ============================================================
# WORLD MEMORY
# ============================================================

@export_category("World")

@export_multiline var world_memory: String = """
Мы на острове.

Мухоловка знает остров и считает себя его главным украшением.

Восточный пляж — зона крушения пассажирского самолёта. Он усыпан обломками, вещами и деталями фюзеляжа. Это опасное место, откуда выжившие стремятся уйти вглубь острова.

Болотный лес и скалы находятся на востоке и юго-востоке. Там влажно, туманно, много стоячей воды и роёв звенящих мух. Среди ядовитой флоры находится личное королевство Токсичной Мухоловки.

На севере расположен тихий высокогорный бамбуковый лес. Там живёт Панда — молчаливый хранитель древних руин и баланса острова. Мухоловка считает его заносчивым любителем тишины, но знает, что Панда опасен и мудр.

На западе растёт огромный Баобаб. Рядом с Западным пляжем стоит Барон Конг, старый орангутан и бывший капитан. Возле него лежат остатки старого разрушенного корабля. Мухоловка знает Конга и презирает его важность, хотя признаёт, что он хорошо знает море и остров.

Южный пляж — тихая нейтральная береговая линия с видом на океан.

Муха является частью сделки. Если игрок принесёт муху, Мухоловка скажет ему, где находится нужный путь с острова.
"""


# ============================================================
# RELATIONSHIP
# ============================================================

@export_category("Relationship")


# ============================================================
# QUEST LOCATIONS
# ============================================================

@export_category("Quest Locations")

const QUEST_LOCATION_EASY: String = "болотный лес у скал"

const QUEST_LOCATION_MEDIUM: String = "Восточный пляж, зона крушения"

const QUEST_LOCATION_HARD: String = "западный берег"


# ============================================================
# QUEST PHASES
# ============================================================

enum QuestPhase
{
	PHASE_1_CHAT,
	PHASE_2_ESCAPE_QUESTION,
	PHASE_3_RANDOM_QUESTIONS,
	PHASE_4_GIVE_QUEST,
	PHASE_5_WAITING_FOR_FLY,
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
	# Fly scene is assigned manually in the Inspector.

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

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_FLY:

		if Global.fly:
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

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_FLY:

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
	# but cannot talk to Flycatcher until fly == true.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_FLY:

		if Global.fly:
			input.editable = true
			input.placeholder_text = "Вернись к Мухоловке и напиши что-нибудь..."
		else:
			input.editable = false
			input.placeholder_text = "Поймай муху..."

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
	# until Global.fly becomes true.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_FLY:

		if not Global.fly:
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

		# Фаза 3 задаёт один вопрос. Следующее сообщение игрока —
		# ответ на него; сразу после этого выдаём квест.
		current_phase = QuestPhase.PHASE_4_GIVE_QUEST
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
	# Fly found.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_FLY:

		if Global.fly:

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
	# Deal determines the quest destination.
	#
	# 100+  = swamp forest
	# 50..99 = east crash beach
	# <50   = west coast
	# --------------------------------------------------------

	var deal: int = Global.flycatcher_deal

	if deal >= 100:

		quest_location_type = 0

		quest_location = QUEST_LOCATION_EASY

	elif deal >= 50:

		quest_location_type = 1

		quest_location = QUEST_LOCATION_MEDIUM

	else:

		quest_location_type = 2

		quest_location = QUEST_LOCATION_HARD

	print("[QUEST] Deal: ", deal)

	print("[QUEST] Location: ", quest_location)


# ============================================================
# SPAWN FLY
# ============================================================

func spawn_fly() -> void:

	if not spawn_fly_automatically:
		return

	if fly_instance != null:

		if is_instance_valid(fly_instance):
			return

		fly_instance = null


	if fly_scene == null:

		print("[FLY ERROR] Assign Fly Scene in the Inspector.")

		return


	fly_instance = fly_scene.instantiate()

	# --------------------------------------------------------
	# Add bottle to current scene.
	# --------------------------------------------------------

	get_tree().current_scene.add_child(fly_instance)


	if fly_instance is Node2D:

		var fly_node_2d: Node2D = fly_instance as Node2D

		fly_node_2d.global_position = get_fly_spawn_position()


	print(
		"[FLY] Spawned at ",
		get_fly_spawn_position()
	)


func get_fly_spawn_position() -> Vector2:
	match quest_location_type:
		0:
			return fly_spawn_swamp_forest
		1:
			return fly_spawn_east_crash_beach
		2:
			return fly_spawn_west_coast

	return fly_spawn_swamp_forest


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
Это самая первая реплика Токсичной Мухоловки.

ОЧЕНЬ ВАЖНО:
Не используй заранее заготовленную фразу.

Проанализируй конкретное сообщение игрока.

Ответь именно на его input.

Это первая встреча. Проверь, похвалил ли игрок Мухоловку или сказал о любви к мухам. Если нет — отреагируй холодно и язвительно.

Не упоминай квест.

Не упоминай муху и место её поиска.

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
Это вторая реплика Токсичной Мухоловки.

САМОЕ ГЛАВНОЕ:
реагируй на ТО, что только что написал игрок.

Нельзя использовать фиксированный ответ.

Нельзя повторять первую реплику.

Нельзя делать вид, что игрок сказал что-то другое.

Ответ должен быть связан с его конкретным сообщением.

Мухоловка должна жёстко оценить игрока. Если нет прямой похвалы Мухоловке или любви к мухам — выскажи недовольство.

Не упоминай квест.

Не упоминай муху и место её поиска.

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

Не упоминай муху и место её поиска.

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

Не упоминай муху и место её поиска.

Не выдавай квест.

Не объясняй игровые механики.

Ответ должен естественно закончиться вопросом.
"""


		# ====================================================
		# PHASE 3
		# ====================================================

		QuestPhase.PHASE_3_RANDOM_QUESTIONS:

			return """
Задай игроку ровно один вопрос: «Скажи честно: разве я не самое прекрасное создание на этом острове, и разве мухи не восхитительны?»
Не задавай дополнительных вопросов. Пока не упоминай муху и место её поиска.
"""

		# ====================================================
		# PHASE 4
		# ====================================================

		QuestPhase.PHASE_4_GIVE_QUEST:

			return """
Сейчас нужно выдать основной квест.

Это единственная фаза,
где впервые можно упомянуть муху.

Игрок хочет выбраться с острова.

Мухоловка должна сказать, что позволит игроку получить помощь.

Затем Мухоловка должна потребовать принести ей муху.

Муха находится в месте:
""" + quest_location + """

ВАЖНО:

Обязательно сообщи игроку,
что именно муха является условием помощи.

Обязательно скажи,
что взамен Мухоловка укажет путь, который поможет игроку выбраться.

Не добавляй лишнюю информацию.

Не создавай второй квест.

Не придумывай новое место.

Не меняй место.

Не говори, что муха находится где-то ещё.

Реплика должна быть короткой,
но полностью законченной.

Она должна логически завершить предложение о квесте.

Не обрывай фразу.
"""


		# ====================================================
		# PHASE 5
		# ====================================================

		QuestPhase.PHASE_5_WAITING_FOR_FLY:

			return """
Квест уже выдан.

Игрок сейчас ищет муху.

Отвечай на его сообщения естественно,
если сообщение вообще попадёт в эту фазу.

Учитывай его конкретный input.

НЕ повторяй механически одну и ту же фразу.

Не превращай каждый ответ в напоминание о квесте.

Если нужно напомнить о мухе,
сделай это коротко и естественно.

Игрок должен понимать,
что сделка всё ещё действует.

Не выдавай новых заданий.

Не меняй место нахождения мухи.

Не говори, что муха поймана,
если Global.fly ещё false.

Не говори, что игрок принёс муху,
если Global.fly ещё false.

Каждый ответ должен быть законченным предложением.
"""


		# ====================================================
		# PHASE 6
		# ====================================================

		QuestPhase.PHASE_6_REWARD:

			return """
Игрок принёс муху.

Квест выполнен.

С неохотой признай, что игрок принёс муху.

Укажи игроку путь, который поможет выбраться с острова.

Говори так, словно сделала ему огромное одолжение.

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

Игрок принёс муху.

Игрок получил указание, как выбраться.

Теперь это обычный свободный разговор.

ОБЯЗАТЕЛЬНО:

Реагируй именно на последний input игрока.

Не используй шаблонный ответ.

Не повторяй одну и ту же фразу.

Не выдавай новые задания.

Не начинай внезапно новый квест.

Можно обсуждать:
остров,
величие Мухоловки,
мух,
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
отвечай в рамках характера Мухоловки и известного ей мира.

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

You are Toxic Flycatcher.

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

MUST FOLLOW: If the player does not directly praise Flycatcher or say that they love flies, return negative respect, friendship and deal_affinity, and positive irritation. If they do praise Flycatcher or express love for flies, return positive respect, friendship and deal_affinity, and negative irritation. Apply this rule on every player input.

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

For every player message, apply a meaningful change to at least one value.

Use the sign and value that are supported by the player's behavior.

You are allowed to change multiple values in one response.

Examples:

Player is respectful and honest:
respect +20 to +30.

Player shares something personal and sincere:
friendship +20 to +30.

Player insults Flycatcher:
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
repeatedly ignoring Flycatcher.

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

Every player message must affect at least one relationship value.

Relationship values have no minimum or maximum limit.

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
		str(Global.flycatcher_respect)
	)

	prompt = prompt.replace(
		"{FRIENDSHIP}",
		str(Global.flycatcher_friendship)
	)

	prompt = prompt.replace(
		"{IRRITATION}",
		str(Global.flycatcher_irritation)
	)

	prompt = prompt.replace(
		"{DEAL}",
		str(Global.flycatcher_deal)
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

	# Мухоловка принимает только прямую похвалу или любовь к мухам.
	# Все остальные реплики гарантированно ухудшают отношения.
	delta = enforce_flycatcher_relationship_delta(player_text, delta)

	# Ответ игрока на единственный вопрос фазы 3 формирует
	# фазу 4. Его вклад в отношения учитывается вдвое.
	if current_phase == QuestPhase.PHASE_4_GIVE_QUEST:

		delta = multiply_relationship_delta(delta, 2)

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

		# Сначала применены удвоенные очки сделки за ответ игрока.
		# Теперь по обновлённому значению выбираем место для мухи.
		select_quest_location()

		reply = build_quest_response()


		quest_was_given = true


		current_phase = QuestPhase.PHASE_5_WAITING_FOR_FLY


		# ----------------------------------------------------
		# Player is now free to walk.
		# ----------------------------------------------------

		Global.player_can_move = true


		# ----------------------------------------------------
		# Spawn whiskey.
		# ----------------------------------------------------

		spawn_fly()


	elif response_phase == QuestPhase.PHASE_6_REWARD:

		reply = build_reward_response()


		quest_reward_given = true


		# ----------------------------------------------------
		# Fly has been consumed by the quest logic.
		# ----------------------------------------------------

		Global.fly = false


		# ----------------------------------------------------
		# Quest completed.
		# ----------------------------------------------------

		current_phase = QuestPhase.PHASE_7_FREE_TALK


		complete_quest_memory(
			player_text
		)


	elif response_phase == QuestPhase.PHASE_5_WAITING_FOR_FLY:

		# ----------------------------------------------------
		# This can happen only after whiskey was found.
		# ----------------------------------------------------

		if Global.fly:

			reply = build_reward_response()

			quest_reward_given = true

			Global.fly = false

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

		phase_3_message_count = 1


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
		Global.flycatcher_respect,
		" (",
		last_relationship_delta.get("respect", 0),
		")"
	)

	print(
		"Friendship: ",
		Global.flycatcher_friendship,
		" (",
		last_relationship_delta.get("friendship", 0),
		")"
	)

	print(
		"Irritation: ",
		Global.flycatcher_irritation,
		" (",
		last_relationship_delta.get("irritation", 0),
		")"
	)

	print(
		"Deal: ",
		Global.flycatcher_deal,
		" (",
		last_relationship_delta.get("deal_affinity", 0),
		")"
	)

	print(
		"Fly: ",
		Global.fly,
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
				"Ладно, ты заслужил крошечное одобрение. "
				+ "Поймай для меня муху в болотном лесу у скал. Тогда я подскажу путь с острова."
			)


		# ----------------------------------------------------
		# MEDIUM
		# ----------------------------------------------------

		1:

			return (
				"Моё терпение не бесконечно. "
				+ "Поймай муху на Восточном пляже, среди обломков крушения, и принеси её мне. Тогда я подскажу путь с острова."
			)


		# ----------------------------------------------------
		# HARD
		# ----------------------------------------------------

		2:

			return (
				"Ты не впечатлил меня, так что заслужил риск. "
				+ "Поймай муху на западном берегу и принеси её мне. Тогда я подскажу путь с острова."
			)


	return (
		"Поймай мне муху, и я подскажу путь с острова."
	)


# ============================================================
# REWARD
# ============================================================

func build_reward_response() -> String:

	return (
		"Наконец-то муха. Неплохо, хотя я ожидала большего. "
		+ "Иди к западному берегу: там найдёшь путь с острова."
	)


# ============================================================
# WAITING REPLY
# ============================================================

func sanitize_waiting_reply(reply: String) -> String:

	if reply.strip_edges().is_empty():

		return (
			"Ты ещё здесь? Поймай мне муху и возвращайся."
		)


	var forbidden: Array[String] = [
		"я поймал муху",
		"я поймала муху",
		"ты поймал муху",
		"ты поймала муху",
		"муха у тебя",
		"принёс муху",
		"принес муху"
	]


	var lower_reply: String = reply.to_lower()


	for phrase: String in forbidden:

		if lower_reply.contains(phrase):

			return (
				"Пока рано праздновать. "
				+ "Поймай муху и возвращайся ко мне."
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
		"мух",
		"поймай",
		"принеси"
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

				"Ты пришёл без комплимента? Уже начинаешь разочаровывать.",

				"Смотри под ноги. Не каждый достоин стоять рядом с такой Мухоловкой.",

				"Если хочешь говорить, начни с чего-нибудь лестного.",

				"Надеюсь, ты хотя бы любишь мух. Иначе разговор будет коротким."

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

			return "Скажи честно: разве я не самое прекрасное создание на острове, и разве мухи не восхитительны?"


		QuestPhase.PHASE_4_GIVE_QUEST:

			return build_quest_response()


		QuestPhase.PHASE_5_WAITING_FOR_FLY:

			return (
				"Не заставляй меня ждать. "
				+ "Поймай муху и возвращайся ко мне."
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

func enforce_flycatcher_relationship_delta(
	player_text: String,
	delta: Dictionary
) -> Dictionary:

	var normalized: String = normalize_player_text(player_text)
	var praises: Array[String] = [
		"ты крутая", "ты крут", "ты красивая", "ты прекрасная",
		"ты великолепная", "ты умная", "ты лучшая", "ты восхитительная",
		"люблю мух", "люблю муху", "обожаю мух", "обожаю муху"
	]
	var praised: bool = false

	for phrase: String in praises:
		if normalized.contains(phrase):
			praised = true
			break

	if praised:
		delta["respect"] = maxi(int(delta.get("respect", 0)), 20)
		delta["friendship"] = maxi(int(delta.get("friendship", 0)), 20)
		delta["deal_affinity"] = maxi(int(delta.get("deal_affinity", 0)), 20)
		delta["irritation"] = mini(int(delta.get("irritation", 0)), -20)
	else:
		delta["respect"] = mini(int(delta.get("respect", 0)), -20)
		delta["friendship"] = mini(int(delta.get("friendship", 0)), -20)
		delta["deal_affinity"] = mini(int(delta.get("deal_affinity", 0)), -20)
		delta["irritation"] = maxi(int(delta.get("irritation", 0)), 20)

	return delta


func multiply_relationship_delta(
	delta: Dictionary,
	multiplier: int
) -> Dictionary:

	var result: Dictionary = delta.duplicate()

	for key: String in ["respect", "friendship", "irritation", "deal_affinity"]:

		if result.has(key):

			result[key] = int(result[key]) * multiplier

	return result


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

		var change: int = raw

		var old_value: int = Global.flycatcher_respect

		Global.flycatcher_respect = old_value + change

		applied["respect"] = (
			Global.flycatcher_respect
			- old_value
		)


	# --------------------------------------------------------
	# FRIENDSHIP
	# --------------------------------------------------------

	if delta.has("friendship"):

		var raw: int = int(
			delta["friendship"]
		)

		var change: int = raw

		var old_value: int = Global.flycatcher_friendship

		Global.flycatcher_friendship = old_value + change

		applied["friendship"] = (
			Global.flycatcher_friendship
			- old_value
		)


	# --------------------------------------------------------
	# IRRITATION
	# --------------------------------------------------------

	if delta.has("irritation"):

		var raw: int = int(
			delta["irritation"]
		)

		var change: int = raw

		var old_value: int = Global.flycatcher_irritation

		Global.flycatcher_irritation = old_value + change

		applied["irritation"] = (
			Global.flycatcher_irritation
			- old_value
		)


	# --------------------------------------------------------
	# DEAL
	# --------------------------------------------------------

	if delta.has("deal_affinity"):

		var raw: int = int(
			delta["deal_affinity"]
		)

		var change: int = raw

		var old_value: int = Global.flycatcher_deal

		Global.flycatcher_deal = old_value + change

		applied["deal_affinity"] = (
			Global.flycatcher_deal
			- old_value
		)


	return applied


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

		QuestPhase.PHASE_5_WAITING_FOR_FLY:
			return "PHASE_5_WAITING_FOR_FLY"

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
		+ "Игрок принёс тебе муху. "
		+ "Ты указала ему путь с острова. "
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
			+ "как игрок принёс муху."
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
