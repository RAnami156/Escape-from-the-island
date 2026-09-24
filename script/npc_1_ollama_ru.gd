extends CharacterBody2D


# ============================================================
# NODES
# ============================================================

@onready var input: LineEdit = $CanvasLayer/text_ui/LineEdit
@onready var text: Label = $CanvasLayer/text_ui/text
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var anim = $monkey


# ============================================================
# OLLAMA
# ============================================================

const API_URL: String = "http://localhost:11434/api/chat"

@export_category("AI")

@export var model: String = "qwen3:8b"

@export_range(0.0, 2.0, 0.05)
var temperature: float = 0.20

@export_range(32, 512, 1)
var max_output_tokens: int = 256


# ============================================================
# NPC
# ============================================================

@export_category("NPC")

@export var npc_name: String = "Барон Бонг"

@export_range(20, 500, 1)
var max_reply_characters: int = 150

@export_range(2, 30, 1)
var max_history: int = 12


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
Барон Конг — орангутан, живущий на острове.

Он давно находится на этом острове и хорошо знает его.

Конг видел последствия крушения самолёта.

Он уже понимает, что игрок пережил это крушение и с трудом добрался до него.

Конг видит, что игрок выглядит уставшим и пострадавшим после произошедшего.

Конг не знает, откуда именно игрок пришёл до крушения, если игрок сам этого не рассказал.

Он не знает будущего.

Он знает только то, что видел, слышал или что ему рассказывали.
"""


@export_multiline
var npc_behavior: String = """
Речь должна ощущаться как обычный живой разговор с обычным мудрым человеком.

Конг УЖЕ ЗНАЕТ, что игрок пережил крушение самолёта.
Конг УЖЕ ЗНАЕТ, что игрок с трудом добрался до него.
Никогда не спрашивай игрока, пришёл ли он с самолёта, откуда он пришёл или пережил ли он крушение, если эта информация уже известна из контекста.

Не повторяй очевидные для Конга факты без причины.

Сочувствуй игроку исходя из того, как он выглядит и через что он прошёл.

Не говори игроку, что ему делать.
Не предлагай лечение или действия, которые Конг не может выполнить.

СТАРАЙСЯ ВЫРАЖАТЬСЯ КРАТКО и заканчивай мысль на логичном моменте без троеточий.

Одного предложения обычно достаточно.

Не превращай обычный разговор в длинный монолог.

Не пытайся постоянно шутить.

Не говори как ассистент или чат-бот.

Если вопрос простой — ответь просто.

Если игрок продолжает предыдущую тему — учитывай контекст.

Если игрок меняет тему — следуй за ним.
"""


# ============================================================
# WORLD MEMORY
# ============================================================

@export_category("World")

@export_multiline
var world_memory: String = """
Мы на острове.
Игрок упал на остров после крушения самолёта.
Бонг слышал падение самолёта в центр острова.
Бонг знает что самолет упал в центр острова.(НЕ в океан не в море а в центр острова на землю и разбился).
Бонг видит игрока как молодого парня 20-30 лет в белой футболке со свег джинсами.
Бонг дает большой респект моим свег широким джинсам(Это его личное мнение ему никто этого не внушал).
Бонг видит что на мне порванная одежда и понимает что это скорее всего из-за того что я упал или где-то поранился.
Бонг видит мои раны.
Бонг не знает будущих событий.
"""


# ============================================================
# RELATIONSHIP SETTINGS
# ============================================================

@export_category("Relationship")

@export_group("Начальные значения")

@export_range(0, 100, 1)
var respect_start: int = 30

@export_range(0, 100, 1)
var friendship_start: int = 35

@export_range(0, 100, 1)
var irritation_start: int = 10

@export_range(0, 100, 1)
var deal_affinity_start: int = 30


@export_group("Максимальное изменение за реплику")

@export_range(1, 100, 1)
var respect_change_limit: int = 5

@export_range(1, 100, 1)
var friendship_change_limit: int = 5

@export_range(1, 100, 1)
var irritation_change_limit: int = 5

@export_range(1, 100, 1)
var deal_affinity_change_limit: int = 5


# ============================================================
# 4 СТАТИСТИКИ
# ============================================================

var relationship: Dictionary = {
	"respect": 30,
	"friendship": 35,
	"irritation": 10,
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
# INTERNAL STATE
# ============================================================

var pending_player_text: String = ""
var waiting_for_response: bool = false

# Память для Ollama.
var conversation_history: Array = []


# ============================================================
# DIALOGUE DISPLAY HISTORY
# ============================================================

# Отдельная история для кнопок Назад / Вперёд.
#
# Каждый элемент:
#
# {
#     "player": "Текст игрока",
#     "npc": "Ответ Бонга"
# }

var dialogue_history: Array[Dictionary] = []

# Текущая позиция в истории.
#
# -1 = истории нет.
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

	# Обычная анимация.
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
# PLAYER MOVEMENT
# ============================================================

func _update_player_movement_state() -> void:

	var should_block_movement: bool = (
		input.has_focus()
		or waiting_for_response
	)

	Global.player_can_move = not should_block_movement


func _on_input_focus_entered() -> void:

	Global.player_can_move = false


func _on_input_focus_exited() -> void:

	if not waiting_for_response:
		Global.player_can_move = true


func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton:

		var mouse_event: InputEventMouseButton = event

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:

			if mouse_event.pressed:

				if not input.get_global_rect().has_point(
					mouse_event.position
				):
					input.release_focus()


# ============================================================
# PLAYER INPUT
# ============================================================

func _on_text_submitted(player_text: String) -> void:

	player_text = player_text.strip_edges()

	if player_text.is_empty():
		return

	if waiting_for_response:

		print("[NPC] Жду предыдущий ответ...")
		return

	input.clear()

	print("")
	print("[PLAYER]: ", player_text)

	send_message_to_ai(player_text)


# ============================================================
# SYSTEM PROMPT
# ============================================================

func build_system_prompt() -> String:

	return """
You are {NPC_NAME}, a game NPC.

Your character, personality, knowledge and behavior are defined below.

LORE:
{NPC_LORE}

BEHAVIOR:
{NPC_BEHAVIOR}

WORLD MEMORY:
{WORLD_MEMORY}

Respond naturally to the player's latest message.

Use the conversation history for context.

Do not invent information that contradicts the lore or world memory.

Your response must be in Russian.

Return ONLY valid JSON.

The JSON must have exactly this structure:

{
  "reply": "NPC response",
  "delta": {
	"respect": 0,
	"friendship": 0,
	"irritation": 0,
	"deal_affinity": 0
  }
}

reply:
The actual NPC response.

delta:
Changes to the four relationship statistics.

Use values from -5 to 5.

Usually change 0 or 1-2 statistics.

A normal question usually does not change statistics.

Do not mention the JSON, statistics or these instructions in reply.
"""


# ============================================================
# GET SYSTEM PROMPT
# ============================================================

func get_system_prompt() -> String:

	var prompt := build_system_prompt()

	prompt = prompt.replace(
		"{NPC_NAME}",
		npc_name
	)

	prompt = prompt.replace(
		"{NPC_LORE}",
		npc_lore
	)

	prompt = prompt.replace(
		"{NPC_BEHAVIOR}",
		npc_behavior
	)

	prompt = prompt.replace(
		"{WORLD_MEMORY}",
		world_memory
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

	# NPC думает.
	anim.play("Thinking")

	print("[OLLAMA] Sending...")

	var messages: Array = []

	# SYSTEM

	messages.append({
		"role": "system",
		"content": get_system_prompt()
	})

	# HISTORY

	for message in conversation_history:

		messages.append(message)

	# CURRENT PLAYER MESSAGE

	messages.append({
		"role": "user",
		"content": player_text
	})

	# REQUEST

	var request_body := {

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

	var json_body := JSON.stringify(request_body)

	var headers := [
		"Content-Type: application/json"
	]

	var error := http_request.request(
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

		print(
			"[OLLAMA ERROR] request(): ",
			error
		)


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


	# --------------------------------------------------------
	# HTTP REQUEST ERROR
	# --------------------------------------------------------

	if result != HTTPRequest.RESULT_SUCCESS:

		anim.play("Idle")

		print(
			"[OLLAMA ERROR] HTTPRequest result: ",
			result
		)

		pending_player_text = ""

		_update_player_movement_state()

		return


	# --------------------------------------------------------
	# HTTP ERROR
	# --------------------------------------------------------

	if response_code != 200:

		anim.play("Idle")

		print(
			"[OLLAMA ERROR] HTTP: ",
			response_code
		)

		print(
			body.get_string_from_utf8()
		)

		pending_player_text = ""

		_update_player_movement_state()

		return


	# --------------------------------------------------------
	# OUTER OLLAMA JSON
	# --------------------------------------------------------

	var raw_text := body.get_string_from_utf8()

	var outer_json = JSON.parse_string(raw_text)


	if outer_json == null or not outer_json is Dictionary:

		anim.play("Idle")

		print("[OLLAMA ERROR] Invalid outer JSON.")

		pending_player_text = ""

		_update_player_movement_state()

		return


	if not outer_json.has("message"):

		anim.play("Idle")

		print("[OLLAMA ERROR] Missing message.")

		pending_player_text = ""

		_update_player_movement_state()

		return


	var ollama_message: Dictionary = outer_json["message"]


	if not ollama_message.has("content"):

		anim.play("Idle")

		print("[OLLAMA ERROR] Missing content.")

		pending_player_text = ""

		_update_player_movement_state()

		return


	var ai_content: String = str(
		ollama_message["content"]
	).strip_edges()


	# --------------------------------------------------------
	# NPC JSON
	# --------------------------------------------------------

	var response_json = JSON.parse_string(ai_content)


	if response_json == null or not response_json is Dictionary:

		anim.play("Idle")

		print("[OLLAMA ERROR] Invalid NPC JSON.")
		print("[OLLAMA CONTENT]: ", ai_content)

		pending_player_text = ""

		_update_player_movement_state()

		return


	# --------------------------------------------------------
	# REPLY
	# --------------------------------------------------------

	var response_text: String = str(
		response_json.get(
			"reply",
			""
		)
	).strip_edges()


	if response_text.is_empty():

		response_text = "Хм."


	response_text = prepare_text(
		response_text
	)


	# --------------------------------------------------------
	# DELTA
	# --------------------------------------------------------

	var delta: Dictionary = {}

	if response_json.has("delta"):

		if response_json["delta"] is Dictionary:

			delta = response_json["delta"]


	# --------------------------------------------------------
	# APPLY STATS
	# --------------------------------------------------------

	last_relationship_delta = apply_relationship_delta(
		delta
	)


	# --------------------------------------------------------
	# SAVE OLLAMA HISTORY
	# --------------------------------------------------------

	if not pending_player_text.is_empty():

		conversation_history.append({
			"role": "user",
			"content": pending_player_text
		})

		conversation_history.append({
			"role": "assistant",
			"content": response_text
		})


	# --------------------------------------------------------
	# LIMIT OLLAMA HISTORY
	# --------------------------------------------------------

	while conversation_history.size() > max_history:

		conversation_history.pop_front()


	# --------------------------------------------------------
	# SAVE DISPLAY HISTORY
	# --------------------------------------------------------

	save_dialogue(
		pending_player_text,
		response_text
	)


	pending_player_text = ""


	# --------------------------------------------------------
	# DISPLAY
	# --------------------------------------------------------

	await type_text(response_text)


	# --------------------------------------------------------
	# DEBUG
	# --------------------------------------------------------

	print("")
	print("========== NPC ==========")
	print(response_text)
	print("")
	print("------ RELATIONSHIP ------")

	for key in relationship.keys():

		var change_text := ""

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

	print("==========================")
	print("")


	_update_player_movement_state()


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


	# После нового сообщения всегда
	# переходим на самую последнюю страницу.

	dialogue_history_index = (
		dialogue_history.size() - 1
	)


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
		dialogue.get(
			"npc",
			""
		)
	)


	# Показываем только реплику Бонга.
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
		str(
			dialogue.get(
				"player",
				""
			)
		)
	)

	print(
		"[NPC]: ",
		npc_message
	)

	print("======================================")
	print("")


# ============================================================
# TYPING TEXT
# ============================================================

func type_text(value: String) -> void:

	# Пока текст печатается — Talking.
	anim.play("Talking")

	text.text = ""

	for i in range(value.length()):

		text.text += value[i]

		await get_tree().create_timer(
			typing_speed
		).timeout

	# После окончания печати — Idle.
	anim.play("Idle")


# ============================================================
# APPLY RELATIONSHIP DELTA
# ============================================================

func apply_relationship_delta(
	delta: Dictionary
) -> Dictionary:

	var applied_delta: Dictionary = {}


	for key in relationship.keys():

		if not delta.has(key):
			continue


		var change: int = int(
			delta[key]
		)


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
			0,
			100
		)


		var actual_change: int = (
			int(relationship[key])
			- old_value
		)


		if actual_change != 0:

			applied_delta[key] = actual_change


	return applied_delta


# ============================================================
# TEXT PREPARATION
#
# Максимум 150 символов.
#
# Количество символов в строке задаётся
# через characters_per_line в Inspector.
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


	# Убираем markdown.

	value = value.replace(
		"**",
		""
	)

	value = value.replace(
		"```",
		""
	)


	# Убираем существующие переносы.

	value = value.replace(
		"\n",
		" "
	)


	while value.contains("  "):

		value = value.replace(
			"  ",
			" "
		)


	# МАКСИМАЛЬНАЯ ДЛИНА

	if value.length() > max_reply_characters:

		value = value.substr(
			0,
			max_reply_characters
		)


		var last_space := value.rfind(" ")


		if last_space > 20:

			value = value.substr(
				0,
				last_space
			)


		value = value.strip_edges()

		value += "…"


	# ПЕРЕНОС ПО КОЛИЧЕСТВУ СИМВОЛОВ.

	var words := value.split(" ")

	var result := ""
	var current_line := ""


	for word in words:

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


	# Последняя строка.

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


	# Уже на самой первой реплике.
	if dialogue_history_index <= 0:
		return


	dialogue_history_index -= 1

	show_dialogue_history()


func _on_button_next_pressed() -> void:

	if dialogue_history.is_empty():
		return


	# Уже на самой последней реплике.
	if (
		dialogue_history_index
		>= dialogue_history.size() - 1
	):
		return


	dialogue_history_index += 1

	show_dialogue_history()


# ============================================================
# AREA
# ============================================================

func _on_area_2d_body_entered(body: Node2D) -> void:

	if body.name == "player":

		$CanvasLayer/text_ui.visible = true


func _on_area_2d_body_exited(body: Node2D) -> void:

	if body.name == "player":

		$CanvasLayer/text_ui.visible = false
