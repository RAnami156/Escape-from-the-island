extends CharacterBody2D

@onready var input: LineEdit = $CanvasLayer/text_ui/LineEdit
@onready var text: Label = $CanvasLayer/text_ui/text
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var anim = $monkey


# ============================================================
# NPC SETTINGS
# ============================================================

@export_category("NPC")
@export var npc_name: String = "Токсичная Мухоловка"

@export_category("Fly")
@export var fly_scene: PackedScene


# ============================================================
# ITEM STATE
# ============================================================

var fly: bool = false


# ============================================================
# DIALOGUE STATE
# ============================================================

var is_waiting_for_response: bool = false
var dialogue_history: Array = []
var max_history: int = 20


# ============================================================
# RELATIONSHIP
# ============================================================

var relationship: Dictionary = {
	"flycatcher_respect": -40,
	"flycatcher_friendship": -30,
	"flycatcher_irritation": 100,
	"flycatcher_deal": -67
}

var relationship_names: Dictionary = {
	"flycatcher_respect": "Уважение Мухоловки",
	"flycatcher_friendship": "Дружба Мухоловки",
	"flycatcher_irritation": "Раздражение Мухоловки",
	"flycatcher_deal": "Расположение к сделке"
}


# ============================================================
# LORE
# ============================================================

var npc_lore: String = """
Ты — Токсичная Мухоловка.

Ты необычное хищное растение, которое живёт на острове.
Ты ловишь и ешь мух и считаешь мух невероятно прекрасными существами.

Ты очень самовлюблённая, токсичная, язвительная и высокомерная.
Ты искренне считаешь себя очень крутой, опасной и особенной.

Ты не считаешь себя обычным растением.
Для тебя ты — элитная хищница, перед которой другие должны испытывать уважение.

Ты любишь, когда игрок говорит, что ты крутая, опасная, красивая, особенная,
необычная или великолепная.

Особенно тебе нравится, когда игрок говорит, что любит мух.

Ты можешь быть дружелюбной, если игрок относится к тебе с уважением.
Но если игрок отвечает скучно, холодно или безразлично, ты легко раздражаешься.

Ты можешь язвить, подкалывать игрока и заставлять его доказывать,
что он достоин разговаривать с тобой.

Ты не обязана соглашаться с игроком.

Ты не знаешь будущего.
Ты не знаешь событий, которых не могла видеть, слышать или о которых тебе
никто не рассказывал.

Ты знаешь только то, что происходило рядом с тобой,
что ты сама наблюдала или что тебе рассказал игрок/другие персонажи.
"""


# ============================================================
# BEHAVIOR
# ============================================================

var npc_behavior: String = """
ПРАВИЛА ПОВЕДЕНИЯ:

1. Ты всегда говоришь от лица Токсичной Мухоловки.

2. Ты должна оставаться токсичной, самоуверенной и язвительной.

3. Ты считаешь себя очень крутой.

4. Если игрок прямо говорит, что ты крутая, прекрасная, опасная,
   особенная, великолепная или другим способом искренне тебя хвалит —
   реагируй положительно.

5. Если игрок прямо говорит, что любит мух —
   реагируй особенно положительно.

6. Если игрок не хвалит тебя, отвечает сухо, скучно или нейтрально,
   это НЕ обязательно должно оставаться нейтральным.

7. Обычный вопрос без комплимента может тебя раздражать.
   Ты можешь решить, что игрок недостаточно уважителен.

8. Если игрок отвечает холодно, безразлично, скучно или пытается
   перевести тему, можно уменьшать уважение и дружбу и увеличивать раздражение.

9. Если игрок говорит, что ты обычная, слабая, бесполезная,
   неинтересная или вообще не заслуживаешь уважения —
   реагируй резко и негативно.

10. Если игрок говорит, что не любит мух —
    реагируй негативно.

11. Если игрок прямо оскорбляет тебя —
    отношение должно сильно ухудшаться.

12. Не выдавай игроку скрытые значения relationship.

13. Не говори игроку напрямую:
	"я поставила тебе -3 дружбы" или что-то подобное.

14. Изменения отношений должны зависеть от смысла ответа игрока,
    а не просто от отдельных слов.

15. Не нужно каждый раз менять все четыре параметра.
    Меняй только те, которые действительно подходят ситуации.

16. Максимальное изменение одного параметра за один ответ:
    от -5 до +5.

ПРИМЕРНЫЕ ИЗМЕНЕНИЯ:

Сильная похвала:
- flycatcher_respect: +3...+5
- flycatcher_friendship: +2...+5
- flycatcher_irritation: -2...-5
- flycatcher_deal: +1...+4

Игрок говорит, что любит мух:
- flycatcher_respect: +2...+5
- flycatcher_friendship: +2...+5
- flycatcher_irritation: -2...-5
- flycatcher_deal: +1...+4

Обычный вопрос без похвалы:
- flycatcher_respect: 0...-2
- flycatcher_friendship: 0...-2
- flycatcher_irritation: 0...+2

Холодный/скучный ответ:
- flycatcher_respect: -2...-3
- flycatcher_friendship: -2...-3
- flycatcher_irritation: +2...+4

Прямое оскорбление:
- flycatcher_respect: -4...-5
- flycatcher_friendship: -4...-5
- flycatcher_irritation: +4...+5

Игрок говорит, что не любит мух:
- flycatcher_respect: -2...-5
- flycatcher_friendship: -2...-5
- flycatcher_irritation: +2...+5
"""


# ============================================================
# WORLD MEMORY
# ============================================================

var world_memory: String = """
Место действия — остров.

Игрок оказался на острове после авиакатастрофы и пытается выжить.

Токсичная Мухоловка находится на острове и знает только то,
что она могла наблюдать сама или услышать от других.

Она любит мух.

Она не знает будущего и не может достоверно знать события,
которые ещё не произошли.
"""


# ============================================================
# OLLAMA SETTINGS
# ============================================================

@export_category("AI")
@export var ollama_url: String = "http://localhost:11434/api/chat"
@export var model: String = "llama3.1"


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Получаем начальные значения из Global.
	# Они должны быть объявлены в Global.gd.

	relationship["flycatcher_respect"] = Global.flycatcher_respect
	relationship["flycatcher_friendship"] = Global.flycatcher_friendship
	relationship["flycatcher_irritation"] = Global.flycatcher_irritation
	relationship["flycatcher_deal"] = Global.flycatcher_deal

	if input:
		input.text_submitted.connect(_on_text_submitted)

	if http_request:
		http_request.request_completed.connect(_on_http_request_completed)

	update_text("...")


# ============================================================
# INPUT
# ============================================================

func _on_text_submitted(user_message: String) -> void:
	if is_waiting_for_response:
		return

	user_message = user_message.strip_edges()

	if user_message.is_empty():
		return

	input.clear()

	send_message_to_ai(user_message)


# ============================================================
# SYSTEM PROMPT
# ============================================================

func build_system_prompt() -> String:
	var relationship_text := ""

	for key in relationship.keys():
		var value = relationship[key]
		var readable_name = relationship_names.get(key, key)

		relationship_text += "%s: %s\n" % [
			readable_name,
			str(value)
		]

	var prompt := """
Ты — NPC в игре.

Твоё имя: %s

=== LORE ===
%s

=== WORLD MEMORY ===
%s

=== BEHAVIOR ===
%s

=== CURRENT RELATIONSHIP ===
%s

=== IMPORTANT ===

Ты разговариваешь с игроком.

Отвечай естественно, как живой персонаж.

Твоя реплика должна соответствовать характеру Токсичной Мухоловки.

Помни:
- ты токсичная;
- ты самоуверенная;
- ты считаешь себя очень крутой;
- ты любишь мух;
- ты хочешь, чтобы игрок уважал тебя;
- ты особенно любишь, когда игрок говорит, что любит мух;
- сухие и безразличные ответы могут тебя раздражать;
- оскорбления должны вызывать сильную негативную реакцию.

Очень важно:
Если игрок прямо хвалит тебя — это должно положительно влиять на отношения.

Если игрок прямо говорит, что любит мух — это должно положительно влиять
на отношения.

Если игрок отвечает безразлично, скучно или холодно —
ты можешь ухудшить отношения.

Если игрок тебя оскорбляет или говорит, что ты бесполезная/обычная/слабая —
отношения должны ухудшаться сильно.

Ты не должна раскрывать скрытые значения отношений игроку.

Ты должна вернуть ТОЛЬКО JSON согласно указанной схеме.

JSON должен иметь такой вид:

{
	"reply": "Твоя реплика игроку",
	"delta": {
		"flycatcher_respect": 0,
		"flycatcher_friendship": 0,
		"flycatcher_irritation": 0,
		"flycatcher_deal": 0
	}
}

Для каждого delta используй целое число от -5 до 5.

Не используй другие названия ключей.

Не добавляй Markdown.
Не добавляй ```json.
Не добавляй пояснения вне JSON.

Отвечай на русском языке.
""" % [
		npc_name,
		npc_lore,
		world_memory,
		npc_behavior,
		relationship_text
	]

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
					"flycatcher_respect": {
						"type": "integer"
					},
					"flycatcher_friendship": {
						"type": "integer"
					},
					"flycatcher_irritation": {
						"type": "integer"
					},
					"flycatcher_deal": {
						"type": "integer"
					}
				},
				"required": [
					"flycatcher_respect",
					"flycatcher_friendship",
					"flycatcher_irritation",
					"flycatcher_deal"
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

func send_message_to_ai(user_message: String) -> void:
	if is_waiting_for_response:
		return

	is_waiting_for_response = true

	dialogue_history.append({
		"role": "user",
		"content": user_message
	})

	if dialogue_history.size() > max_history:
		dialogue_history.pop_front()

	var messages: Array = []

	messages.append({
		"role": "system",
		"content": build_system_prompt()
	})

	for message in dialogue_history:
		messages.append(message)

	var request_body := {
		"model": model,
		"messages": messages,
		"stream": false,
		"format": get_response_schema()
	}

	var json_body := JSON.stringify(request_body)

	var headers := [
		"Content-Type: application/json"
	]

	var error := http_request.request(
		ollama_url,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if error != OK:
		is_waiting_for_response = false
		update_text("Мухоловка недовольно смотрит на тебя.")

		print("HTTP request error: ", error)


# ============================================================
# HTTP RESPONSE
# ============================================================

func _on_http_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	is_waiting_for_response = false

	if response_code < 200 or response_code >= 300:
		update_text("Мухоловка раздражённо молчит.")

		print("HTTP response code: ", response_code)
		print("Response: ", body.get_string_from_utf8())

		return

	var response_text := body.get_string_from_utf8()

	var outer_json = JSON.parse_string(response_text)

	if outer_json == null:
		update_text("Мухоловка смотрит на тебя с недоверием.")

		print("Failed to parse outer JSON")
		print(response_text)

		return

	if not outer_json is Dictionary:
		update_text("Мухоловка ничего не поняла.")

		print("Outer response is not Dictionary")

		return

	if not outer_json.has("message"):
		update_text("Мухоловка молчит.")

		print("No message field in response")

		return

	var message_data = outer_json["message"]

	if not message_data is Dictionary:
		update_text("Мухоловка раздражённо щёлкает пастью.")

		print("Message is not Dictionary")

		return

	if not message_data.has("content"):
		update_text("Мухоловка не отвечает.")

		print("No content field")

		return

	var ai_content: String = str(message_data["content"])

	var ai_json = JSON.parse_string(ai_content)

	if ai_json == null:
		# Иногда модель может вернуть JSON в виде строки с лишними символами.
		# Попробуем найти первый { и последний }.

		var first_brace := ai_content.find("{")
		var last_brace := ai_content.rfind("}")

		if first_brace >= 0 and last_brace > first_brace:
			var extracted := ai_content.substr(
				first_brace,
				last_brace - first_brace + 1
			)

			ai_json = JSON.parse_string(extracted)

	if ai_json == null:
		update_text(ai_content)

		dialogue_history.append({
			"role": "assistant",
			"content": ai_content
		})

		return

	if not ai_json is Dictionary:
		update_text("Мухоловка смотрит на тебя с подозрением.")
		return

	var reply: String = str(
		ai_json.get(
			"reply",
			"Мухоловка молчит."
		)
	)

	var delta = ai_json.get("delta", {})

	update_text(reply)

	dialogue_history.append({
		"role": "assistant",
		"content": reply
	})

	if dialogue_history.size() > max_history:
		dialogue_history.pop_front()

	apply_relationship_delta(delta)


# ============================================================
# RELATIONSHIP DELTA
# ============================================================

func apply_relationship_delta(delta) -> void:
	if not delta is Dictionary:
		return

	var keys := [
		"flycatcher_respect",
		"flycatcher_friendship",
		"flycatcher_irritation",
		"flycatcher_deal"
	]

	for key in keys:
		if not delta.has(key):
			continue

		var change = delta[key]

		if not (change is int or change is float):
			continue

		var numeric_change := int(change)

		# Безопасное ограничение изменения за одну реплику.
		numeric_change = clamp(
			numeric_change,
			-5,
			5
		)

		var current_value: int = int(
			relationship.get(key, 0)
		)

		var new_value: int = current_value + numeric_change

		# Значения могут быть как отрицательными,
		# так и положительными.
		new_value = clamp(
			new_value,
			-100,
			100
		)

		relationship[key] = new_value

	# ========================================================
	# СИНХРОНИЗАЦИЯ С GLOBAL
	# ========================================================

	Global.flycatcher_respect = int(
		relationship["flycatcher_respect"]
	)

	Global.flycatcher_friendship = int(
		relationship["flycatcher_friendship"]
	)

	Global.flycatcher_irritation = int(
		relationship["flycatcher_irritation"]
	)

	Global.flycatcher_deal = int(
		relationship["flycatcher_deal"]
	)


# ============================================================
# TEXT
# ============================================================

func update_text(new_text: String) -> void:
	if text:
		text.text = new_text


# ============================================================
# TYPING TEXT
# ============================================================

func type_text(new_text: String, speed: float = 0.02) -> void:
	if not text:
		return

	text.text = ""

	for character in new_text:
		text.text += character
		await get_tree().create_timer(speed).timeout


# ============================================================
# PUBLIC FUNCTIONS
# ============================================================

func get_relationship_value(key: String) -> int:
	return int(
		relationship.get(key, 0)
	)


func set_relationship_value(key: String, value: int) -> void:
	if not relationship.has(key):
		return

	relationship[key] = clamp(
		value,
		-100,
		100
	)

	_sync_global_relationship()


func add_relationship_value(key: String, value: int) -> void:
	if not relationship.has(key):
		return

	var current_value := int(
		relationship[key]
	)

	relationship[key] = clamp(
		current_value + value,
		-100,
		100
	)

	_sync_global_relationship()


func _sync_global_relationship() -> void:
	Global.flycatcher_respect = int(
		relationship["flycatcher_respect"]
	)

	Global.flycatcher_friendship = int(
		relationship["flycatcher_friendship"]
	)

	Global.flycatcher_irritation = int(
		relationship["flycatcher_irritation"]
	)

	Global.flycatcher_deal = int(
		relationship["flycatcher_deal"]
	)
