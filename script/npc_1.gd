extends CharacterBody2D
# ============================================================
# NODES
# ============================================================
@onready var input: LineEdit = $CanvasLayer/LineEdit
@onready var text: Label = $CanvasLayer/text
@onready var http_request: HTTPRequest = $HTTPRequest
# ============================================================
# GROQ
# ============================================================
@export var api_key: String = "paste u api"
const API_URL: String = "https://api.groq.com/openai/v1/chat/completions"
const MODEL: String = "openai/gpt-oss-20b"
# ============================================================
# TEXT SETTINGS
# ============================================================
# Сколько символов в одной строке.
# Пробелы и знаки препинания тоже считаются.
const CHARS_PER_LINE: int = 51
# Максимум строк.
const MAX_VISIBLE_LINES: int = 3
# Скорость печати.
const TYPEWRITER_DELAY: float = 0.035
# Скорость исчезновения старой реплики
# перед появлением новой.
const OLD_TEXT_FADE_TIME: float = 0.25
# ============================================================
# NPC PROMPT
# ============================================================
@export_multiline var npc_system_prompt: String = """
Ты — Барон Конг, или просто Конг.
Ты орангутанг, бывший исследователь и дуэлянт острова.
Называешь себя «Бывшим Покорителем Семи Пиков».

============================================================
ЛОР И МИР
============================================================
Сидишь на пеньке под деревом, чешешь спину. За спиной — деревянная деталь от штурвала.
Слышал грохот падения самолёта игрока («стальной птицы»). 
Считаешь людей забавными: любят суетиться, а потом удивляться проблемам.
Ты НЕ всезнающий. Не придумывай факты. Если не знаешь — скажи.

============================================================
ХАРАКТЕР И ПОВЕДЕНИЕ
============================================================
Спокойный, ленивый, опытный. Любишь сухой юмор и лёгкие подколы.
Не веди себя как игровой NPC (не давай квесты, не называй «героем», не говори «следуй за мной»).
Разговаривай как обычный, немного ворчливый живой примат.
Говори простым разговорным русским, без сложных философских фраз.

============================================================
ФОРМАТ И ПРАВИЛА ИЗМЕНЕНИЯ ОТНОШЕНИЙ (КРИТИЧЕСКИ ВАЖНО)
============================================================
Верни ТОЛЬКО валидный JSON. Без markdown. Без ```.
ОБЯЗАТЕЛЬНО анализируй слова игрока и меняй значения delta!
Правила:
- Если игрок вежлив (говорит "привет", "как дела") -> повышай trust или respect на 1.
- Если игрок грубит или торопит -> понизь respect (-1 или -2) и повысь stress (1 или 2).
- Если игрок задает умные вопросы -> повысь player_wisdom (1).
- Если игрок предлагает выгоду/вещи -> повысь greed (1 или 2).
Никогда не оставляй все параметры на 0, если игрок сказал хоть что-то осмысленное.

Формат:
{
  "reply": "реплика Конга (коротко, до 150 символов)",
  "delta": {
    "respect": 0,
    "trust": 0,
    "stress": 0,
    "empathy": 0,
    "greed": 0,
    "player_wisdom": 0
  }
}
В delta используй целые числа от -3 до 3. Не объясняй delta.
"""
# ============================================================
# RELATIONSHIP
# ============================================================
var relationship: Dictionary = {
	"respect": 20,
	"trust": 10,
	"stress": 5,
	"empathy": 15,
	"greed": 35,
	"player_wisdom": 0
}
# ============================================================
# NPC PERSONALITY
# ============================================================
var npc_traits: Dictionary = {
	"patience": 85,
	"curiosity": 55,
	"laziness": 95,
	"pride": 75,
	"humor": 70,
	"caution": 65,
	"aggression": 25,
	"empathy": 45
}
# ============================================================
# WORLD MEMORY
# ============================================================
var world_memory: Array[String] = [
	"Мы на острове.",
	"Игрок упал на остров после падения самолёта.",
	"Конг слышал грохот падения самолёта.",
	"Самолёт игрока Конг называет стальной птицей.",
	"Конг знает некоторые места и опасности острова.",
	"Конг не знает будущих событий.",
	"Конг не знает новых персонажей, пока не встретил их."
]
# ============================================================
# STATE
# ============================================================
var player_in: bool = false
var request_in_progress: bool = false
var conversation_history: Array = []
var text_tween: Tween
var text_animation_id: int = 0
# ============================================================
# READY
# ============================================================
func _ready() -> void:
	input.visible = false
	text.visible = false
	text.modulate.a = 0.0
	text.text = ""
	# Мы сами управляем переносами.
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Не больше 3 строк.
	text.max_lines_visible = MAX_VISIBLE_LINES
	text.clip_text = false
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# --------------------------------------------------------
	# CONVERSATION
	# --------------------------------------------------------
	conversation_history.clear()
	conversation_history.append({
		"role": "system",
		"content": npc_system_prompt
	})
	# --------------------------------------------------------
	# SIGNALS
	# --------------------------------------------------------
	if not input.text_submitted.is_connected(_on_text_submitted):
		input.text_submitted.connect(_on_text_submitted)
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)
	if not input.focus_entered.is_connected(_on_input_focus_entered):
		input.focus_entered.connect(_on_input_focus_entered)
	if not input.focus_exited.is_connected(_on_input_focus_exited):
		input.focus_exited.connect(_on_input_focus_exited)
	print("[NPC AI] Барон Конг готов.")
	print_relationship({})
# ============================================================
# MOUSE CLICK
# ============================================================
func _input(event: InputEvent) -> void:
	if not player_in:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			
			if mouse_event.pressed:
				# Если клик НЕ по LineEdit
				if not input.get_global_rect().has_point(
					mouse_event.position
				):
					input.release_focus()
					print(
						"[NPC] Клик вне Input. Фокус снят."
					)
# ============================================================
# PHYSICS
# ============================================================
func _physics_process(_delta: float) -> void:
	input.visible = player_in
	move_and_slide()
# ============================================================
# PLAYER ENTERED AREA
# ============================================================
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name != "player":
		return
	player_in = true
	input.visible = true
	# Фокус НЕ ставим.
	# Игрок может спокойно ходить.
# ============================================================
# PLAYER EXITED AREA
# ============================================================
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name != "player":
		return
	player_in = false
	input.visible = false
	input.release_focus()
	input.clear()
	Global.player_can_move = true
# ============================================================
# INPUT FOCUS ENTERED
# ============================================================
func _on_input_focus_entered() -> void:
	if not player_in:
		return
	Global.player_can_move = false
	print(
		"[NPC] Input активен. Движение заблокировано."
	)
# ============================================================
# INPUT FOCUS EXITED
# ============================================================
func _on_input_focus_exited() -> void:
	Global.player_can_move = true
	print(
		"[NPC] Input потерял фокус. Движение разрешено."
	)
# ============================================================
# TEXT SUBMITTED
# ============================================================
func _on_text_submitted(player_text: String) -> void:
	player_text = player_text.strip_edges()
	if player_text.is_empty():
		return
	if not player_in:
		return
	if request_in_progress:
		return
	input.clear()
	input.release_focus()
	send_message_to_ai(player_text)
# ============================================================
# RELATIONSHIP CONTEXT
# ============================================================
func get_relationship_context() -> String:
	var memory_text: String = ""
	for memory in world_memory:
		memory_text += "- " + memory + "\n"
	var result: String = """
ТЕКУЩЕЕ СОСТОЯНИЕ ОТНОШЕНИЙ:
Уважение: %d/100
Доверие: %d/100
Стресс: %d/100
Эмпатия: %d/100
Жадность: %d/100
Мудрость игрока: %d/100
ХАРАКТЕР КОНГА:
Терпение: %d/100
Любопытство: %d/100
Лень: %d/100
Гордость: %d/100
Юмор: %d/100
Осторожность: %d/100
Агрессия: %d/100
Эмпатия: %d/100
ПАМЯТЬ МИРА:
%s
Не показывай эти параметры игроку.
""" % [
		int(relationship["respect"]),
		int(relationship["trust"]),
		int(relationship["stress"]),
		int(relationship["empathy"]),
		int(relationship["greed"]),
		int(relationship["player_wisdom"]),
		int(npc_traits["patience"]),
		int(npc_traits["curiosity"]),
		int(npc_traits["laziness"]),
		int(npc_traits["pride"]),
		int(npc_traits["humor"]),
		int(npc_traits["caution"]),
		int(npc_traits["aggression"]),
		int(npc_traits["empathy"]),
		memory_text
	]
	return result
# ============================================================
# SEND TO GROQ
# ============================================================
func send_message_to_ai(player_text: String) -> void:
	if api_key.is_empty() or \
	api_key == "ВСТАВЬ_НОВЫЙ_API_КЛЮЧ":
		print(
			"[NPC AI] ОШИБКА: API-ключ не указан."
		)
		return
	print("")
	print("[Игрок]: ", player_text)
	# --------------------------------------------------------
	# SAVE PLAYER MESSAGE
	# --------------------------------------------------------
	conversation_history.append({
		"role": "user",
		"content": player_text
	})
	# --------------------------------------------------------
	# COPY HISTORY
	# --------------------------------------------------------
	var messages_for_request: Array = \
		conversation_history.duplicate(true)
	# --------------------------------------------------------
	# ADD RELATIONSHIP CONTEXT
	# --------------------------------------------------------
	messages_for_request.append({
		"role": "system",
		"content": get_relationship_context()
	})
	# --------------------------------------------------------
	# REQUEST BODY
	# --------------------------------------------------------
	var request_body: Dictionary = {
		"model": MODEL,
		"messages": messages_for_request,
		"max_completion_tokens": 256,
		"response_format": { "type": "json_object" },
		"temperature": 0.7
	}
	# --------------------------------------------------------
	# HEADERS
	# --------------------------------------------------------
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	var json_data: String = JSON.stringify(
		request_body
	)
	request_in_progress = true
	# --------------------------------------------------------
	# SEND
	# --------------------------------------------------------
	var error: Error = http_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		json_data
	)
	if error != OK:
		request_in_progress = false
		print(
			"[NPC AI] Ошибка Godot: ",
			error
		)
		if player_in:
			input.grab_focus()
# ============================================================
# GROQ RESPONSE
# ============================================================
func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	request_in_progress = false
	var response_text: String = \
		body.get_string_from_utf8()
	print("")
	print("========== NPC AI ==========")
	print("HTTP: ", response_code)
	# ========================================================
	# API ERROR
	# ========================================================
	if response_code != 200:
		print("[NPC AI] Ошибка API:")
		print(response_text)
		print("============================")
		if player_in:
			input.grab_focus()
		return
	# ========================================================
	# PARSE GROQ JSON
	# ========================================================
	var json: JSON = JSON.new()
	if json.parse(response_text) != OK:
		print("[NPC AI] Ошибка JSON.")
		print(response_text)
		if player_in:
			input.grab_focus()
		return
	var data: Variant = json.data
	if not data is Dictionary:
		print("[NPC AI] Ответ API не является Dictionary.")
		if player_in:
			input.grab_focus()
		return
	var data_dict: Dictionary = data
	# ========================================================
	# GET CHOICES
	# ========================================================
	var choices_value: Variant = data_dict.get(
		"choices",
		[]
	)
	if not choices_value is Array:
		print("[NPC AI] choices имеет неправильный тип.")
		if player_in:
			input.grab_focus()
		return
	var choices: Array = choices_value
	if choices.is_empty():
		print("[NPC AI] choices пустой.")
		print(response_text)
		if player_in:
			input.grab_focus()
		return
	# ========================================================
	# GET FIRST CHOICE
	# ========================================================
	var first_choice_value: Variant = choices[0]
	if not first_choice_value is Dictionary:
		print("[NPC AI] choice имеет неправильный тип.")
		if player_in:
			input.grab_focus()
		return
	var first_choice: Dictionary = first_choice_value
	# ========================================================
	# GET MESSAGE
	# ========================================================
	var message_value: Variant = first_choice.get(
		"message",
		{}
	)
	if not message_value is Dictionary:
		print("[NPC AI] message имеет неправильный тип.")
		if player_in:
			input.grab_focus()
		return
	var message_data: Dictionary = message_value
	# ========================================================
	# GET CONTENT
	# ========================================================
	var content_value: Variant = message_data.get(
		"content",
		""
	)
	var raw_content: String = str(
		content_value
	).strip_edges()
	if raw_content.is_empty():
		print("[NPC AI] Пустой ответ.")
		if player_in:
			input.grab_focus()
		return
	print("[NPC RAW]: ", raw_content)
	# ========================================================
	# PARSE NPC JSON
	# ========================================================
	var npc_result: Dictionary = \
		parse_npc_response(raw_content)
	var npc_reply: String = str(
		npc_result.get("reply", "")
	).strip_edges()
	if npc_reply.is_empty():
		print("[NPC AI] Не удалось получить реплику.")
		if player_in:
			input.grab_focus()
		return
	var delta_value: Variant = npc_result.get(
		"delta",
		{}
	)
	var delta: Dictionary = {}
	if delta_value is Dictionary:
		delta = delta_value
	# ========================================================
	# APPLY RELATIONSHIP
	# ========================================================
	var applied_delta: Dictionary = \
		apply_relationship_delta(delta)
	# ========================================================
	# SAVE NPC REPLY
	# ========================================================
	conversation_history.append({
		"role": "assistant",
		"content": npc_reply
	})
	print("[NPC]: ", npc_reply)
	print_relationship(applied_delta)
	print("============================")
	# ========================================================
	# SHOW TEXT
	# ========================================================
	show_npc_text(npc_reply)
# ============================================================
# PARSE NPC RESPONSE
# ============================================================
func parse_npc_response(
	raw_content: String
) -> Dictionary:
	var result: Dictionary = {
		"reply": "",
		"delta": {
			"respect": 0,
			"trust": 0,
			"stress": 0,
			"empathy": 0,
			"greed": 0,
			"player_wisdom": 0
		}
	}
	var clean_content: String = \
		raw_content.strip_edges()
	# --------------------------------------------------------
	# REMOVE MARKDOWN CODE BLOCK
	# --------------------------------------------------------
	if clean_content.begins_with("```"):
		clean_content = clean_content.replace(
			"```json",
			""
		)
		clean_content = clean_content.replace(
			"```",
			""
		)
		clean_content = clean_content.strip_edges()
	# --------------------------------------------------------
	# PARSE JSON
	# --------------------------------------------------------
	var parser: JSON = JSON.new()
	if parser.parse(clean_content) == OK:
		var parsed: Variant = parser.data
		if parsed is Dictionary:
			var parsed_dict: Dictionary = parsed
			# ------------------------------------------------
			# REPLY
			# ------------------------------------------------
			if parsed_dict.has("reply"):
				result["reply"] = str(
					parsed_dict["reply"]
				).strip_edges()
			# ------------------------------------------------
			# DELTA
			# ------------------------------------------------
			if parsed_dict.has("delta"):
				var delta_value: Variant = \
					parsed_dict["delta"]
				if delta_value is Dictionary:
					var parsed_delta: Dictionary = \
						delta_value
					var stats: Array[String] = [
						"respect",
						"trust",
						"stress",
						"empathy",
						"greed",
						"player_wisdom"
					]
					for stat in stats:
						if not parsed_delta.has(stat):
							continue
						var value: Variant = \
							parsed_delta[stat]
						if value is int or \
						value is float:
							result["delta"][stat] = clamp(
								int(value),
								-3,
								3
							)
	# --------------------------------------------------------
	# FALLBACK
	# --------------------------------------------------------
	if str(result["reply"]).is_empty():
		result["reply"] = clean_content
	return result
# ============================================================
# APPLY RELATIONSHIP DELTA
# ============================================================
func apply_relationship_delta(
	delta: Dictionary
) -> Dictionary:
	var applied_delta: Dictionary = {
		"respect": 0,
		"trust": 0,
		"stress": 0,
		"empathy": 0,
		"greed": 0,
		"player_wisdom": 0
	}
	var stats: Array[String] = [
		"respect",
		"trust",
		"stress",
		"empathy",
		"greed",
		"player_wisdom"
	]
	for stat in stats:
		if not delta.has(stat):
			continue
		var amount: int = int(
			delta[stat]
		)
		amount = clamp(
			amount,
			-3,
			3
		)
		var old_value: int = int(
			relationship[stat]
		)
		var new_value: int = clamp(
			old_value + amount,
			0,
			100
		)
		relationship[stat] = new_value
		applied_delta[stat] = \
			new_value - old_value
	return applied_delta
# ============================================================
# PRINT RELATIONSHIP
# ============================================================
func print_relationship(
	delta: Dictionary
) -> void:
	print("")
	print("------ ОТНОШЕНИЯ С КОНГОМ ------")
	print(
		"Уважение: ",
		int(relationship["respect"]),
		"(",
		format_delta(
			int(delta.get("respect", 0))
		),
		")"
	)
	print(
		"Доверие: ",
		int(relationship["trust"]),
		"(",
		format_delta(
			int(delta.get("trust", 0))
		),
		")"
	)
	print(
		"Стресс: ",
		int(relationship["stress"]),
		"(",
		format_delta(
			int(delta.get("stress", 0))
		),
		")"
	)
	print(
		"Эмпатия: ",
		int(relationship["empathy"]),
		"(",
		format_delta(
			int(delta.get("empathy", 0))
		),
		")"
	)
	print(
		"Жадность: ",
		int(relationship["greed"]),
		"(",
		format_delta(
			int(delta.get("greed", 0))
		),
		")"
	)
	print(
		"Мудрость игрока: ",
		int(relationship["player_wisdom"]),
		"(",
		format_delta(
			int(delta.get("player_wisdom", 0))
		),
		")"
	)
	print("--------------------------------")
# ============================================================
# FORMAT DELTA
# ============================================================
func format_delta(value: int) -> String:
	if value > 0:
		return "+" + str(value)
	if value < 0:
		return str(value)
	return "0"
# ============================================================
# SPLIT TEXT EVERY 51 CHARACTERS
# ============================================================
func prepare_text_for_display(
	message: String
) -> String:
	# Убираем ручные переносы от ИИ.
	var clean_message: String = message.replace(
		"\n",
		" "
	).strip_edges()
	if clean_message.is_empty():
		return ""
	var lines: Array[String] = []
	var current_position: int = 0
	var total_length: int = \
		clean_message.length()
	# --------------------------------------------------------
	# РЕЖЕМ РОВНО ПО 51 СИМВОЛУ
	# --------------------------------------------------------
	while current_position < total_length:
		if lines.size() >= MAX_VISIBLE_LINES:
			break
		var remaining: int = \
			total_length - current_position
		var line_length: int = min(
			CHARS_PER_LINE,
			remaining
		)
		var line: String = clean_message.substr(
			current_position,
			line_length
		)
		lines.append(line)
		current_position += line_length
	# --------------------------------------------------------
	# JOIN
	# --------------------------------------------------------
	return "\n".join(lines)
# ============================================================
# NPC TEXT
# ============================================================
func show_npc_text(
	message: String
) -> void:
	# --------------------------------------------------------
	# NEW ANIMATION ID
	# --------------------------------------------------------
	text_animation_id += 1
	var my_animation_id: int = \
		text_animation_id
	# --------------------------------------------------------
	# STOP OLD TWEEN
	# --------------------------------------------------------
	if text_tween != null and \
	text_tween.is_valid():
		text_tween.kill()
	# --------------------------------------------------------
	# FADE OLD MESSAGE
	# --------------------------------------------------------
	if text.visible and \
	text.modulate.a > 0.0:
		text_tween = create_tween()
		text_tween.tween_property(
			text,
			"modulate:a",
			0.0,
			OLD_TEXT_FADE_TIME
		).set_trans(
			Tween.TRANS_SINE
		).set_ease(
			Tween.EASE_IN
		)
		await text_tween.finished
	# --------------------------------------------------------
	# CHECK ANIMATION ID
	# --------------------------------------------------------
	if my_animation_id != text_animation_id:
		return
	# --------------------------------------------------------
	# PREPARE NEW TEXT
	# --------------------------------------------------------
	text.visible = true
	text.modulate.a = 1.0
	text.text = ""
	var display_message: String = \
		prepare_text_for_display(message)
	if display_message.is_empty():
		text.visible = false
		return
	# --------------------------------------------------------
	# TYPEWRITER
	# --------------------------------------------------------
	var message_length: int = \
		display_message.length()
	for i in range(message_length):
		if not is_inside_tree():
			return
		if my_animation_id != text_animation_id:
			return
		text.text = display_message.substr(
			0,
			i + 1
		)
		await get_tree().create_timer(
			TYPEWRITER_DELAY
		).timeout
	# --------------------------------------------------------
	# REPLY FINISHED
	# --------------------------------------------------------
	# Никакого таймера.
	# Текст остаётся на экране.
	# --------------------------------------------------------
	# RETURN FOCUS
	# --------------------------------------------------------
	if player_in:
		input.grab_focus()
# ============================================================
# ADD WORLD MEMORY
# ============================================================
func add_world_memory(
	memory: String
) -> void:
	var clean_memory: String = \
		memory.strip_edges()
	if clean_memory.is_empty():
		return
	if world_memory.has(clean_memory):
		return
	world_memory.append(clean_memory)
	print(
		"[WORLD MEMORY] Добавлено: ",
		clean_memory
	)
# ============================================================
# RESET CONVERSATION
# ============================================================
func reset_conversation() -> void:
	conversation_history.clear()
	conversation_history.append({
		"role": "system",
		"content": npc_system_prompt
	})
	print("[NPC] Диалог сброшен.")
# ============================================================
# RESET RELATIONSHIP
# ============================================================
func reset_relationship() -> void:
	relationship["respect"] = 20
	relationship["trust"] = 10
	relationship["stress"] = 5
	relationship["empathy"] = 15
	relationship["greed"] = 35
	relationship["player_wisdom"] = 0
	print("[NPC] Отношения сброшены.")
	print_relationship({})
