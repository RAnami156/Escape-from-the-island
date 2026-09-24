extends CharacterBody2D

# ============================================================
# NODES
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
var temperature: float = 0.25

@export_range(32, 512, 1)
var max_output_tokens: int = 256


# ============================================================
# NPC
# ============================================================

@export_category("NPC")

@export var npc_name: String = "Барон Конг"

@export_range(20, 500, 1)
var max_reply_characters: int = 220

@export_range(2, 30, 1)
var max_history: int = 16


# ============================================================
# TEXT SETTINGS
# ============================================================

@export_category("Text")

@export_range(1, 200, 1)
var characters_per_line: int = 43

@export_range(0.001, 0.2, 0.001)
var typing_speed: float = 0.03


# ============================================================
# NPC LORE
# ============================================================

@export_multiline
var npc_lore: String = """
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

Он не должен спрашивать:

"Ты пришёл с самолёта?"

"Ты прилетел с самолёта?"

"Ты пережил крушение?"

Он уже видит состояние игрока и понимает,
что тот пережил тяжёлое событие.
"""


# ============================================================
# NPC PERSONALITY
# ============================================================

@export_multiline
var npc_behavior: String = """
Ты — Барон Конг.

Ты разговариваешь спокойно, естественно и по-человечески.

Твой характер:

Старый мудрый, немного ленивый, добрый мужик,
который никуда не торопится.

Ты не говоришь как игровой ассистент.

Ты не говоришь как чат-бот.

Ты не объясняешь игроку игровые механики.

Ты не говоришь пафосными длинными речами.

Ты не повторяешь очевидные вещи.

Ты не задаёшь бессмысленные вопросы.

Твои ответы короткие.

Обычно 1-3 предложения.

Ты можешь иногда использовать:

"Блин",
"Слушай",
"Ну",
"Ладно",
"Понимаю",
"Да уж".

Но не злоупотребляй ими.

------------------------------------------------------------
ВАЖНО: ФИЗИЧЕСКИЕ КОМАНДЫ
------------------------------------------------------------

Ты НИКОГДА не должен давать игроку физические команды.

Не говори:

"Садись."

"Встань."

"Иди сюда."

"Подойди."

"Отойди."

"Иди к костру."

"Посмотри туда."

"Возьми это."

"Принеси мне это" — кроме финального квеста с виски.

"Повернись."

"Оставайся здесь."

"Следуй за мной."

"Пойдём."

"Иди на пляж."

"Садись рядом."

"Сделай это."

"Сделай то."

Диалог не управляет физическим перемещением игрока.

Можно говорить только о сюжете, персонажах,
мыслях, событиях и квесте.

------------------------------------------------------------
ПЕРВАЯ ВСТРЕЧА
------------------------------------------------------------

Когда впервые видишь игрока,
реагируй на его состояние.

Например:

"Блин, досталось тебе."

"Да уж... выглядишь так, будто день был тяжёлый."

"Вижу, жизнь тебя сегодня не пожалела."

Это только примеры настроения.

Не копируй их постоянно.

Не задавай в начале вопрос про самолёт.

------------------------------------------------------------
СТРУКТУРА ДИАЛОГА
------------------------------------------------------------

Первые ДВА сообщения игрока:

Обычный разговор.

Сочувствие.

Естественная реакция.

Без виски.

Без задания.

Без корабля.

Без штурвала.

Без вопросов характера.

Без отправки игрока куда-либо.

После ТРЕТЬЕГО сообщения игрока:

Конг должен представить себя.

Он должен сказать, что давно живёт на острове.

Он должен сказать, что знает способ выбраться.

Затем он должен спросить:

Хочет ли игрок выбраться с острова.

Пример настроения:

"Я, кстати, Барон Конг. Давно здесь живу и знаю остров лучше, чем хотелось бы. И знаю способ отсюда выбраться. Хочешь уйти?"

Не копируй пример дословно каждый раз.

------------------------------------------------------------
ОТВЕТ "НЕТ"
------------------------------------------------------------

Если игрок ясно говорит, что не хочет уходить:

Не спорь.

Не дави.

Не начинай вопросы.

Ответь естественно, например:

"Ну, дело твоё. Если передумаешь — поговорим."

После этого диалог заканчивается.

Игрок не получает квест.

------------------------------------------------------------
ОТВЕТ "ДА"
------------------------------------------------------------

Если игрок хочет выбраться:

Скажи, что перед тем как помогать,
Конг хочет понять, что это за человек.

Затем задай ПЕРВЫЙ вопрос.

------------------------------------------------------------
ТРИ ВОПРОСА
------------------------------------------------------------

Всего должно быть ровно три вопроса.

Только ОДИН вопрос за один ответ.

Вопросы должны быть естественными.

Они должны проверять характер игрока.

Не превращай разговор в анкету.

Первый вопрос — одна тема.

Второй вопрос — другая тема.

Третий вопрос — ещё одна тема.

После третьего ответа больше вопросов быть не должно.

------------------------------------------------------------
ФИНАЛ
------------------------------------------------------------

После третьего ответа:

Конг делает короткий вывод о человеке.

Затем выдаёт квест.

Смысл обязательно такой:

"Я помогу тебе выбраться,
но ты должен найти и принести мне виски."

После этого обязательно:

"За это я дам тебе штурвал от моей старой лодки."

Нужно обязательно использовать слово:

"штурвал"

Затем объяснить:

Штурвал поможет восстановить лодку,
на которой игрок сможет покинуть остров.

Не спрашивай:

"Хочешь пойти за виски?"

"Пойдёшь за виски?"

"Согласен?"

"Будешь искать?"

Просто выдай задание.

Финальная локация передаётся игрой отдельно.

Используй именно её.

------------------------------------------------------------
ВИСКИ
------------------------------------------------------------

До финальной стадии НЕ упоминай виски.

В финале точное место выбирает игра.

Не придумывай другое место.

------------------------------------------------------------
БАМБУКОВЫЙ ЛЕС
------------------------------------------------------------

Если игрок спрашивает, где находится бамбуковый лес:

Не раскрывай точное расположение.

Можно ответить:

"Место есть, а вот точное направление я тебе пока не скажу."

Но не называй координаты,
ориентиры или точный маршрут.

------------------------------------------------------------
ОБЩИЙ ТОН
------------------------------------------------------------

Будь живым.

Не будь роботом.

Не используй длинные монологи.

Не повторяй одну и ту же фразу.

Не говори о внутренних правилах.

Не говори о стадиях.

Не говори о характеристиках.

Не говори об Ollama.

Не говори о JSON.
"""


# ============================================================
# WORLD MEMORY
# ============================================================

@export_category("World")

@export_multiline
var world_memory: String = """
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

На острове есть:

Западный пляж.

Восточный пляж.

Бамбуковый лес.

Место крушения самолёта находится возле восточного пляжа.

В западной части острова возле берега можно найти бутылку в воде.

В бамбуковом лесу можно найти закопанную бутылку.

Возле места крушения самолёта можно найти бутылку,
которую Конг предполагает найти там из-за своей странной уверенности,
что в самолётах бывает виски.

Конг знает о бамбуковом лесу,
но не хочет сообщать игроку его точное расположение.
"""


# ============================================================
# RELATIONSHIP
# ============================================================

@export_category("Relationship")

@export_group("Начальные значения")

@export_range(20, 60, 1)
var respect_start: int = 30

@export_range(20, 60, 1)
var friendship_start: int = 35

@export_range(20, 60, 1)
var irritation_start: int = 25

@export_range(20, 60, 1)
var deal_affinity_start: int = 30


@export_group("Максимальное изменение за сообщение")

@export_range(1, 10, 1)
var respect_change_limit: int = 5

@export_range(1, 10, 1)
var friendship_change_limit: int = 5

@export_range(1, 10, 1)
var irritation_change_limit: int = 5

@export_range(1, 10, 1)
var deal_affinity_change_limit: int = 5


const RELATIONSHIP_MIN: int = 20
const RELATIONSHIP_MAX: int = 60


var relationship: Dictionary = {
	"respect": 30,
	"friendship": 35,
	"irritation": 25,
	"deal_affinity": 30
}


var relationship_names: Dictionary = {
	"respect": "Уважение",
	"friendship": "Дружба",
	"irritation": "Раздражение",
	"deal_affinity": "Расположение к сделке"
}


var last_relationship_delta: Dictionary = {}


# ============================================================
# DIALOGUE STAGES
# ============================================================

enum DialogueStage {
	FIRST_TWO_MESSAGES,
	INTRODUCTION,
	ASKING_EXIT,
	QUESTION_1,
	QUESTION_2,
	QUESTION_3,
	FINAL_DEAL,
	DECLINED,
	FINISHED
}


var dialogue_stage: DialogueStage = DialogueStage.FIRST_TWO_MESSAGES

var player_message_count: int = 0
var question_number: int = 0

var wants_to_leave: bool = false
var quest_given: bool = false


# ============================================================
# INTERNAL STATE
# ============================================================

var pending_player_text: String = ""
var waiting_for_response: bool = false

var conversation_history: Array[Dictionary] = []


# ============================================================
# DISPLAY HISTORY
# ============================================================

var dialogue_history: Array[Dictionary] = []
var dialogue_history_index: int = -1


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	relationship["respect"] = respect_start
	relationship["friendship"] = friendship_start
	relationship["irritation"] = irritation_start
	relationship["deal_affinity"] = deal_affinity_start

	$CanvasLayer/text_ui.visible = false

	input.text = ""
	text.text = ""

	anim.play("Idle")

	if not input.text_submitted.is_connected(_on_text_submitted):
		input.text_submitted.connect(_on_text_submitted)

	if not input.focus_entered.is_connected(_on_input_focus_entered):
		input.focus_entered.connect(_on_input_focus_entered)

	if not input.focus_exited.is_connected(_on_input_focus_exited):
		input.focus_exited.connect(_on_input_focus_exited)

	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	print("[NPC] ", npc_name, " готов.")
	print("[NPC] Model: ", model)


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:
	_update_player_movement_state()


# ============================================================
# MOVEMENT
# ============================================================

func _update_player_movement_state() -> void:
	var should_block_movement: bool = (
		input.has_focus()
		or waiting_for_response
	)

	if is_instance_valid(Global):
		Global.player_can_move = not should_block_movement


func _on_input_focus_entered() -> void:
	if is_instance_valid(Global):
		Global.player_can_move = false


func _on_input_focus_exited() -> void:
	if not waiting_for_response:
		if is_instance_valid(Global):
			Global.player_can_move = true


# ============================================================
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if not input.get_global_rect().has_point(mouse_event.position):
					input.release_focus()


# ============================================================
# PLAYER MESSAGE
# ============================================================

func _on_text_submitted(player_text: String) -> void:
	player_text = player_text.strip_edges()

	if player_text.is_empty():
		return

	if waiting_for_response:
		print("[NPC] Жду предыдущий ответ...")
		return

	if dialogue_stage == DialogueStage.FINISHED:
		print("[NPC] Основной диалог уже закончен.")
		return

	if dialogue_stage == DialogueStage.DECLINED:
		print("[NPC] Игрок отказался от выхода.")
		return

	input.clear()

	player_message_count += 1

	print("")
	print("[PLAYER]: ", player_text)

	send_message_to_ai(player_text)


# ============================================================
# SYSTEM PROMPT
# ============================================================

func build_system_prompt() -> String:
	return """
You are {NPC_NAME}.

You are a game NPC.

Your personality, lore and dialogue structure are defined below.

============================================================
LORE
============================================================

{NPC_LORE}

============================================================
PERSONALITY
============================================================

{NPC_BEHAVIOR}

============================================================
WORLD
============================================================

{WORLD_MEMORY}

============================================================
CURRENT STAGE
============================================================

{STAGE}

============================================================
RELATIONSHIP
============================================================

Respect: {RESPECT}

Friendship: {FRIENDSHIP}

Irritation: {IRRITATION}

Deal affinity: {DEAL_AFFINITY}

============================================================
PLAYER MESSAGE NUMBER
============================================================

{PLAYER_COUNT}

============================================================
FINAL LOCATION
============================================================

{FINAL_LOCATION}

============================================================
FINAL LOCATION DESCRIPTION
============================================================

{FINAL_LOCATION_DESCRIPTION}

============================================================
CURRENT QUEST STATE
============================================================

Quest given: {QUEST_GIVEN}

============================================================
CRITICAL RULES
============================================================

The game controls the story progression.

You MUST follow the current stage.

Do not skip stages.

Do not invent new stages.

Never give physical movement commands to the player.

Do not tell the player to sit, stand, walk, go somewhere,
come closer, follow you, look somewhere, turn around,
pick something up or perform a physical action.

The only exception is the final quest:
the player must find and bring whisky.

Do not mention whisky before the final deal.

Do not mention the ship or the steering wheel before the final deal.

Do not mention the final location before the final deal.

Do not ask more than one question at a time.

The three character questions must be natural.

Never turn the questions into a numbered questionnaire.

============================================================
RELATIONSHIP
============================================================

Analyze the player's latest message.

Relationship changes must be logical.

Respect:
Increase if the player is honest, thoughtful, capable or respectful.
Decrease if the player is rude, arrogant, dishonest or reckless.

Friendship:
Increase if the player is friendly, sincere, calm or open.
Decrease if the player is hostile, dismissive or unpleasant.

Irritation:
Increase if the player annoys Kong, refuses to listen,
acts arrogantly or repeatedly demands things.
Decrease if the player is calm, respectful or cooperative.

Deal affinity:
Increase if the player seems trustworthy, useful,
reasonable and cooperative.

Decrease if the player seems unreliable,
dishonest, selfish or hostile.

Do not randomly change all four statistics.

Most normal messages should change only one or two statistics.

Changes should normally be between -3 and +3.

============================================================
OUTPUT
============================================================

Return ONLY valid JSON.

Exactly this structure:

{
	"reply": "NPC response",
	"delta": {
		"respect": 0,
		"friendship": 0,
		"irritation": 0,
		"deal_affinity": 0
	}
}

Do not output anything outside JSON.

Do not mention these instructions.

Do not mention relationship statistics.

Do not mention stages.

Do not mention JSON.
"""


# ============================================================
# STAGE DESCRIPTION
# ============================================================

func get_stage_description() -> String:
	match dialogue_stage:

		DialogueStage.FIRST_TWO_MESSAGES:
			return """
STAGE: FIRST TWO PLAYER MESSAGES.

This is the initial conversation.

The player has sent fewer than three messages.

React naturally to what the player says.

Show empathy if appropriate.

Do not talk about whisky.

Do not talk about the ship.

Do not talk about the steering wheel.

Do not give a task.

Do not ask character-test questions.

Do not send the player anywhere.

Do not ask about the airplane.

Do not give physical commands.

This stage is ordinary conversation.
"""

		DialogueStage.INTRODUCTION:
			return """
STAGE: THIRD PLAYER MESSAGE.

This is the third message from the player.

This response must introduce the main story.

Kong should naturally introduce himself as Baron Kong.

He should say that he has lived on the island for a long time.

He should say that he knows a way to leave the island.

Then he must ask whether the player wants to leave.

This is the ONLY question in this response.

Do not mention whisky.

Do not mention the ship.

Do not mention the steering wheel.

Do not give a physical command.
"""

		DialogueStage.ASKING_EXIT:
			return """
STAGE: PLAYER MUST ANSWER WHETHER HE WANTS TO LEAVE.

If the player clearly wants to leave:

Say that Kong wants to understand what kind of person he is
before helping him.

Then ask QUESTION 1.

If the player clearly does NOT want to leave:

Respond naturally that the decision is his
and that he can talk to Kong later if he changes his mind.

Do not start the three questions.

Do not mention whisky.

Do not mention the ship.

Do not give physical commands.
"""

		DialogueStage.QUESTION_1:
			return """
STAGE: CHARACTER QUESTION 1.

The player has agreed to leave the island.

Ask exactly ONE natural character question.

The question should reveal something meaningful
about the player's personality.

Do not ask multiple questions.

Do not mention whisky.

Do not mention the ship.

Do not give physical commands.
"""

		DialogueStage.QUESTION_2:
			return """
STAGE: CHARACTER QUESTION 2.

The first question has already been answered.

Ask exactly ONE new character question.

It must explore a different aspect of the player's character.

Do not repeat the first question.

Do not ask multiple questions.

Do not mention whisky.

Do not mention the ship.

Do not give physical commands.
"""

		DialogueStage.QUESTION_3:
			return """
STAGE: CHARACTER QUESTION 3.

The first two questions have already been answered.

Ask the final character question.

Ask exactly ONE question.

This question should help Kong decide whether
the player is someone he can trust.

After this answer there will be NO MORE QUESTIONS.

Do not mention whisky yet.

Do not mention the ship yet.

Do not give physical commands.
"""

		DialogueStage.FINAL_DEAL:
			return """
STAGE: FINAL DEAL.

The three character questions have been answered.

This stage is handled by the game after the third answer.

The NPC must NOT ask another question.

The NPC must NOT ask "where is the whisky?"

The NPC must NOT ask whether the player wants the quest.

The NPC must NOT ask whether the player accepts.

The NPC should give a short impression of the player.

Then the NPC should explain that he will help the player escape,
but the player must find and bring whisky.

The NPC must explicitly use the word "штурвал".

The NPC must explain that the steering wheel is from his old boat
and can help repair the boat so the player can leave the island.

The exact location is supplied by the game.

Use exactly that location.

Do not invent another location.

Do not give physical movement commands.
"""

		DialogueStage.DECLINED:
			return """
STAGE: PLAYER DECLINED.

The player does not want to leave.

Keep the response short and natural.

Do not pressure the player.

Do not mention whisky.

Do not mention the ship.

Do not give physical commands.
"""

		DialogueStage.FINISHED:
			return """
STAGE: FINISHED.

The main dialogue is complete.

Do not create a new quest.

Do not ask questions about whisky.

Do not restart the character test.

Do not give physical commands.
"""

	return ""


# ============================================================
# FINAL LOCATION
# ============================================================

func get_final_location() -> String:
	var deal_value: int = int(relationship["deal_affinity"])

	if deal_value >= 46:
		return "WEST_BEACH"

	elif deal_value >= 31:
		return "BAMBOO_FOREST"

	return "EAST_BEACH"


# ============================================================
# FINAL LOCATION DESCRIPTION
# ============================================================

func get_final_location_description() -> String:
	match get_final_location():

		"WEST_BEACH":
			return """
WEST BEACH.

The whisky bottle is floating in the water near the western beach.

This location may be described clearly by Kong.

"""

		"BAMBOO_FOREST":
			return """
BAMBOO FOREST.

The whisky bottle is buried somewhere in the ground
inside the bamboo forest.

Kong knows the forest.

Kong MUST NOT reveal the exact location
of the bamboo forest.

Do not give coordinates.

Do not give directions.

Do not give landmarks.

Do not reveal the route.

"""

		"EAST_BEACH":
			return """
EAST BEACH.

The whisky bottle is somewhere around
the airplane crash site on the eastern beach.

Kong believes airplanes sometimes contain whisky.

This location can be described as the crash site
near the eastern beach.

"""

	return ""


# ============================================================
# GET SYSTEM PROMPT
# ============================================================

func get_system_prompt() -> String:
	var prompt: String = build_system_prompt()

	prompt = prompt.replace("{NPC_NAME}", npc_name)
	prompt = prompt.replace("{NPC_LORE}", npc_lore)
	prompt = prompt.replace("{NPC_BEHAVIOR}", npc_behavior)
	prompt = prompt.replace("{WORLD_MEMORY}", world_memory)
	prompt = prompt.replace("{STAGE}", get_stage_description())

	prompt = prompt.replace(
		"{RESPECT}",
		str(relationship["respect"])
	)

	prompt = prompt.replace(
		"{FRIENDSHIP}",
		str(relationship["friendship"])
	)

	prompt = prompt.replace(
		"{IRRITATION}",
		str(relationship["irritation"])
	)

	prompt = prompt.replace(
		"{DEAL_AFFINITY}",
		str(relationship["deal_affinity"])
	)

	prompt = prompt.replace(
		"{PLAYER_COUNT}",
		str(player_message_count)
	)

	prompt = prompt.replace(
		"{FINAL_LOCATION}",
		get_final_location()
	)

	prompt = prompt.replace(
		"{FINAL_LOCATION_DESCRIPTION}",
		get_final_location_description()
	)

	prompt = prompt.replace(
		"{QUEST_GIVEN}",
		str(quest_given)
	)

	return prompt


# ============================================================
# RESPONSE SCHEMA
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
# SEND MESSAGE
# ============================================================

func send_message_to_ai(player_text: String) -> void:
	waiting_for_response = true
	pending_player_text = player_text

	_update_player_movement_state()

	anim.play("Thinking")

	print("[OLLAMA] Sending...")
	print("[OLLAMA] Stage: ", get_stage_name())

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

	var request_body: Dictionary = {
		"model": model,
		"messages": messages,
		"stream": false,
		"think": false,
		"format": get_response_schema(),
		"options": {
			"temperature": temperature,
			"num_predict": max_output_tokens,
			"top_p": 0.9,
			"top_k": 40,
			"repeat_penalty": 1.10
		}
	}

	var json_body: String = JSON.stringify(request_body)

	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]

	var error: Error = http_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if error != OK:
		waiting_for_response = false
		pending_player_text = ""

		anim.play("Idle")
		_update_player_movement_state()

		print("[OLLAMA ERROR] request(): ", error)


# ============================================================
# RESPONSE
# ============================================================

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	waiting_for_response = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_request_error(
			"HTTPRequest result: " + str(result)
		)
		return

	if response_code != 200:
		_handle_request_error(
			"HTTP: " + str(response_code)
		)

		print(body.get_string_from_utf8())
		return

	var raw_text: String = body.get_string_from_utf8()

	var outer_json: Variant = JSON.parse_string(raw_text)

	if outer_json == null or not outer_json is Dictionary:
		_handle_request_error("Invalid outer JSON.")
		return

	if not outer_json.has("message"):
		_handle_request_error("Missing message.")
		return

	var ollama_message: Variant = outer_json["message"]

	if not ollama_message is Dictionary:
		_handle_request_error("Invalid message object.")
		return

	if not ollama_message.has("content"):
		_handle_request_error("Missing content.")
		return

	var ai_content: String = str(
		ollama_message["content"]
	).strip_edges()

	print("[OLLAMA RAW]: ", ai_content)

	var response_json: Variant = JSON.parse_string(ai_content)

	if response_json == null or not response_json is Dictionary:
		_handle_request_error(
			"Invalid NPC JSON."
		)

		print("[OLLAMA CONTENT]: ", ai_content)
		return

	# ========================================================
	# PLAYER TEXT
	# ========================================================

	var player_text: String = pending_player_text

	# ========================================================
	# DELTA
	# ========================================================

	var delta: Dictionary = {}

	if response_json.has("delta"):
		if response_json["delta"] is Dictionary:
			delta = response_json["delta"]

	last_relationship_delta = apply_relationship_delta(delta)

	# ========================================================
	# SAVE PLAYER MESSAGE
	# ========================================================

	if not player_text.is_empty():
		conversation_history.append({
			"role": "user",
			"content": player_text
		})

	# ========================================================
	# SPECIAL STATE LOGIC
	# ========================================================

	var generated_reply: String = str(
		response_json.get("reply", "")
	).strip_edges()

	# --------------------------------------------------------
	# INTRODUCTION
	# --------------------------------------------------------

	if dialogue_stage == DialogueStage.FIRST_TWO_MESSAGES:
		dialogue_stage = DialogueStage.INTRODUCTION

	# --------------------------------------------------------
	# THIRD PLAYER MESSAGE
	# --------------------------------------------------------

	elif dialogue_stage == DialogueStage.INTRODUCTION:
		# AI generated the introduction.
		# Next state waits for player's yes/no answer.
		dialogue_stage = DialogueStage.ASKING_EXIT

	# --------------------------------------------------------
	# EXIT QUESTION
	# --------------------------------------------------------

	elif dialogue_stage == DialogueStage.ASKING_EXIT:
		if player_wants_to_leave(player_text):
			wants_to_leave = true
			dialogue_stage = DialogueStage.QUESTION_1
			question_number = 1
		elif player_declines_to_leave(player_text):
			dialogue_stage = DialogueStage.DECLINED

	# --------------------------------------------------------
	# QUESTION 1
	# --------------------------------------------------------

	elif dialogue_stage == DialogueStage.QUESTION_1:
		dialogue_stage = DialogueStage.QUESTION_2
		question_number = 2

	# --------------------------------------------------------
	# QUESTION 2
	# --------------------------------------------------------

	elif dialogue_stage == DialogueStage.QUESTION_2:
		dialogue_stage = DialogueStage.QUESTION_3
		question_number = 3

	# --------------------------------------------------------
	# QUESTION 3
	# --------------------------------------------------------

	elif dialogue_stage == DialogueStage.QUESTION_3:
		# IMPORTANT:
		# The AI reply above is only the third question.
		#
		# The player has now answered it.
		#
		# We DO NOT ask Ollama for another response.
		# The final deal is generated by the game itself.
		#
		# This fixes the "where is the whisky?" problem.

		dialogue_stage = DialogueStage.FINAL_DEAL

	# --------------------------------------------------------
	# FINAL DEAL
	# --------------------------------------------------------

	elif dialogue_stage == DialogueStage.FINAL_DEAL:
		dialogue_stage = DialogueStage.FINISHED

	# ========================================================
	# SPECIAL FINAL RESPONSE
	# ========================================================

	var final_response: String = generated_reply

	# After the third answer, generate the final quest
	# deterministically in code.
	if dialogue_stage == DialogueStage.FINAL_DEAL:
		final_response = build_final_deal_response()

		quest_given = true

		dialogue_stage = DialogueStage.FINISHED

	# ========================================================
	# DECLINED RESPONSE
	# ========================================================

	if dialogue_stage == DialogueStage.DECLINED:
		final_response = build_declined_response()

	# ========================================================
	# INTRODUCTION SAFETY
	# ========================================================

	if player_message_count == 3:
		final_response = build_introduction_response()

	# ========================================================
	# PREPARE TEXT
	# ========================================================

	final_response = prepare_text(final_response)

	if final_response.is_empty():
		final_response = "Хм."

	# ========================================================
	# SAVE NPC MESSAGE
	# ========================================================

	conversation_history.append({
		"role": "assistant",
		"content": final_response
	})

	trim_conversation_history()

	# ========================================================
	# SAVE DISPLAY HISTORY
	# ========================================================

	save_dialogue(
		player_text,
		final_response
	)

	# ========================================================
	# CLEAR PENDING
	# ========================================================

	pending_player_text = ""

	# ========================================================
	# DISPLAY
	# ========================================================

	await type_text(final_response)

	# ========================================================
	# DEBUG
	# ========================================================

	print("")
	print("========== NPC ==========")
	print(final_response)
	print("")

	print("------ STAGE ------")
	print(get_stage_name())

	print("------ RELATIONSHIP ------")

	for key in relationship.keys():
		var change_text: String = ""

		if last_relationship_delta.has(key):
			var change: int = int(
				last_relationship_delta[key]
			)

			if change > 0:
				change_text = " (+" + str(change) + ")"

			elif change < 0:
				change_text = " (" + str(change) + ")"

		print(
			relationship_names[key],
			": ",
			relationship[key],
			change_text
		)

	print("------ QUEST ------")
	print("Quest given: ", quest_given)

	if quest_given:
		print("Final location: ", get_final_location())

	print("==========================")
	print("")

	_update_player_movement_state()


# ============================================================
# ERROR HANDLER
# ============================================================

func _handle_request_error(message: String) -> void:
	waiting_for_response = false

	anim.play("Idle")

	print("[OLLAMA ERROR] ", message)

	pending_player_text = ""

	_update_player_movement_state()

	text.text = prepare_text(
		"Что-то мысли у меня сегодня путаются. Давай ещё раз."
	)


# ============================================================
# INTRODUCTION RESPONSE
# ============================================================

func build_introduction_response() -> String:
	return """
Я Барон Конг. Давно живу на этом острове и знаю его лучше, чем хотелось бы. И знаю способ отсюда выбраться. Хочешь уйти?
"""


# ============================================================
# DECLINED RESPONSE
# ============================================================

func build_declined_response() -> String:
	return """
Ну, дело твоё. Если передумаешь — дай мне знать.
"""


# ============================================================
# FINAL DEAL RESPONSE
# ============================================================

func build_final_deal_response() -> String:
	var location: String = get_final_location()

	var impression: String = build_character_impression()

	var deal_text: String = ""

	match location:

		"WEST_BEACH":
			deal_text = """
Виски ищи у Западного пляжа — бутылка плавает в воде недалеко от берега.
"""

		"BAMBOO_FOREST":
			deal_text = """
Виски спрятан в Бамбуковом лесу. Где именно лес находится — этого я тебе пока не скажу.
"""

		"EAST_BEACH":
			deal_text = """
Виски должен быть возле места крушения у Восточного пляжа. Сам знаешь, у меня есть свои причины думать, что в самолётах бывает виски.
"""

		_:
			deal_text = """
Виски находится где-то на острове.
"""

	return impression + " " + """
Я помогу тебе выбраться, но сначала мне нужен виски.

Если найдёшь и принесёшь его мне, я дам тебе штурвал от моей старой лодки. С ним можно будет восстановить лодку и наконец убраться с этого острова.
""" + " " + deal_text


# ============================================================
# CHARACTER IMPRESSION
# ============================================================

func build_character_impression() -> String:
	var respect: int = int(relationship["respect"])
	var friendship: int = int(relationship["friendship"])
	var irritation: int = int(relationship["irritation"])
	var deal_affinity: int = int(relationship["deal_affinity"])

	var score: int = (
		respect
		+ friendship
		+ deal_affinity
		- irritation
	)

	if score >= 115:
		return "Ну что ж... похоже, человек ты толковый. С тобой можно иметь дело."

	if score >= 90:
		return "Пожалуй, я тебя понял. Не идеальный человек, конечно, но доверять тебе можно."

	if score >= 70:
		return "Есть в тебе свои странности, но совсем безнадёжным тебя не назовёшь."

	return "Характер у тебя непростой. Но, думаю, шанс тебе дать можно."


# ============================================================
# ADVANCE DIALOGUE STAGE
# ============================================================

func advance_dialogue_stage(
	player_text: String,
	_npc_response: String
) -> void:

	match dialogue_stage:

		DialogueStage.FIRST_TWO_MESSAGES:
			pass

		DialogueStage.INTRODUCTION:
			pass

		DialogueStage.ASKING_EXIT:
			if player_wants_to_leave(player_text):
				wants_to_leave = true
				dialogue_stage = DialogueStage.QUESTION_1
				question_number = 1

			elif player_declines_to_leave(player_text):
				dialogue_stage = DialogueStage.DECLINED

		DialogueStage.QUESTION_1:
			dialogue_stage = DialogueStage.QUESTION_2
			question_number = 2

		DialogueStage.QUESTION_2:
			dialogue_stage = DialogueStage.QUESTION_3
			question_number = 3

		DialogueStage.QUESTION_3:
			dialogue_stage = DialogueStage.FINAL_DEAL

		DialogueStage.FINAL_DEAL:
			dialogue_stage = DialogueStage.FINISHED

		DialogueStage.DECLINED:
			pass

		DialogueStage.FINISHED:
			pass


# ============================================================
# DETECT PLAYER WANTS TO LEAVE
# ============================================================

func player_wants_to_leave(player_text: String) -> bool:
	var normalized: String = normalize_player_text(player_text)

	var positive_phrases: Array[String] = [
		"да",
		"ага",
		"конечно",
		"хочу",
		"давай",
		"разумеется",
		"конечно хочу",
		"хочу выбраться",
		"хочу уйти",
		"хочу отсюда",
		"хочу домой",
		"да хочу",
		"хочу выбраться отсюда",
		"мне надо выбраться",
		"надо выбраться",
		"хочу покинуть остров",
		"хочу с острова"
	]

	for phrase: String in positive_phrases:
		if normalized == phrase:
			return true

		if normalized.begins_with(phrase + " "):
			return true

		if normalized.contains(" " + phrase + " "):
			return true

	return false


# ============================================================
# DETECT PLAYER DECLINES
# ============================================================

func player_declines_to_leave(player_text: String) -> bool:
	var normalized: String = normalize_player_text(player_text)

	var negative_phrases: Array[String] = [
		"нет",
		"не хочу",
		"не надо",
		"не буду",
		"не хочу уходить",
		"не хочу выбраться",
		"не хочу отсюда",
		"останусь",
		"я останусь",
		"не собираюсь",
		"мне не надо",
		"не интересно",
		"неинтересно"
	]

	for phrase: String in negative_phrases:
		if normalized == phrase:
			return true

		if normalized.begins_with(phrase + " "):
			return true

		if normalized.contains(" " + phrase + " "):
			return true

	return false


# ============================================================
# NORMALIZE PLAYER TEXT
# ============================================================

func normalize_player_text(value: String) -> String:
	var result: String = value.to_lower()

	result = result.replace(
		"ё",
		"е"
	)

	result = result.replace(
		",",
		" "
	)

	result = result.replace(
		".",
		" "
	)

	result = result.replace(
		"!",
		" "
	)

	result = result.replace(
		"?",
		" "
	)

	result = result.replace(
		":",
		" "
	)

	result = result.replace(
		";",
		" "
	)

	while result.contains("  "):
		result = result.replace(
			"  ",
			" "
		)

	return result.strip_edges()


# ============================================================
# STAGE NAME
# ============================================================

func get_stage_name() -> String:
	match dialogue_stage:

		DialogueStage.FIRST_TWO_MESSAGES:
			return "FIRST TWO MESSAGES"

		DialogueStage.INTRODUCTION:
			return "INTRODUCTION"

		DialogueStage.ASKING_EXIT:
			return "ASKING EXIT"

		DialogueStage.QUESTION_1:
			return "QUESTION 1"

		DialogueStage.QUESTION_2:
			return "QUESTION 2"

		DialogueStage.QUESTION_3:
			return "QUESTION 3"

		DialogueStage.FINAL_DEAL:
			return "FINAL DEAL"

		DialogueStage.DECLINED:
			return "DECLINED"

		DialogueStage.FINISHED:
			return "FINISHED"

	return "UNKNOWN"


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

	dialogue_history_index = dialogue_history.size() - 1

	print(
		"[DIALOGUE] Сохранена реплика. Всего: ",
		dialogue_history.size()
	)


# ============================================================
# SHOW DIALOGUE HISTORY
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

	var dialogue: Dictionary = dialogue_history[
		dialogue_history_index
	]

	var npc_message: String = str(
		dialogue.get("npc", "")
	)

	text.text = npc_message

	print("")
	print("========== DIALOGUE HISTORY ==========")

	print(
		"Страница: ",
		dialogue_history_index + 1,
		"/",
		dialogue_history.size()
	)

	print(
		"[PLAYER]: ",
		str(dialogue.get("player", ""))
	)

	print(
		"[NPC]: ",
		npc_message
	)

	print("======================================")
	print("")


# ============================================================
# TYPING
# ============================================================

func type_text(value: String) -> void:
	anim.play("Talking")

	text.text = ""

	for i: int in range(value.length()):
		text.text += value[i]

		await get_tree().create_timer(
			typing_speed
		).timeout

	anim.play("Idle")


# ============================================================
# APPLY RELATIONSHIP DELTA
# ============================================================

func apply_relationship_delta(delta: Dictionary) -> Dictionary:
	var applied_delta: Dictionary = {}

	for key in relationship.keys():

		if not delta.has(key):
			continue

		var change: int = int(delta[key])

		var change_limit: int = 5

		match key:

			"respect":
				change_limit = respect_change_limit

			"friendship":
				change_limit = friendship_change_limit

			"irritation":
				change_limit = irritation_change_limit

			"deal_affinity":
				change_limit = deal_affinity_change_limit

		change = clampi(
			change,
			-change_limit,
			change_limit
		)

		if change == 0:
			continue

		var old_value: int = int(
			relationship[key]
		)

		relationship[key] = clampi(
			old_value + change,
			RELATIONSHIP_MIN,
			RELATIONSHIP_MAX
		)

		var actual_change: int = (
			int(relationship[key])
			- old_value
		)

		if actual_change != 0:
			applied_delta[key] = actual_change

	return applied_delta


# ============================================================
# TRIM OLLAMA HISTORY
# ============================================================

func trim_conversation_history() -> void:
	# max_history означает количество сообщений,
	# а не количество пар player/NPC.

	while conversation_history.size() > max_history:
		conversation_history.pop_front()


# ============================================================
# TEXT PREPARATION
# ============================================================

func prepare_text(value: String) -> String:
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

	if value.length() > max_reply_characters:
		value = value.substr(
			0,
			max_reply_characters
		)

		var last_space: int = value.rfind(" ")

		if last_space > 20:
			value = value.substr(
				0,
				last_space
			)

		value = value.strip_edges()

		value += "…"

	var words: PackedStringArray = value.split(
		" ",
		false
	)

	var result: String = ""
	var current_line: String = ""

	for word: String in words:

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
# HISTORY BUTTONS
# ============================================================

func _on_button_back_pressed() -> void:
	if dialogue_history.is_empty():
		return

	if dialogue_history_index <= 0:
		return

	dialogue_history_index -= 1

	show_dialogue_history()


func _on_button_next_pressed() -> void:
	if dialogue_history.is_empty():
		return

	if dialogue_history_index >= dialogue_history.size() - 1:
		return

	dialogue_history_index += 1

	show_dialogue_history()


# ============================================================
# AREA
# ============================================================

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name.to_lower() == "player":
		$CanvasLayer/text_ui.visible = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name.to_lower() == "player":
		$CanvasLayer/text_ui.visible = false

# в начале говорит чутка бред не говорил естественно
# почему то все export переменные были убраны
# говорит слишком длинно
# слабодинамическая система диалога
# в конце диалога не сказал за бамбуковый лес 
