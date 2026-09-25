extends CharacterBody2D

# UI / scene nodes
@onready var input: LineEdit = $CanvasLayer/text_ui/LineEdit
@onready var text: Label = $CanvasLayer/text_ui/text
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var anim: AnimatedSprite2D = $monkey

# Ollama
const API_URL: String = "http://localhost:11434/api/chat"
@export_category("AI")
@export var model: String = "qwen3:8b"
@export_range(0.0, 2.0, 0.05) var temperature: float = 0.25
@export_range(32, 512, 1) var max_output_tokens: int = 256

# NPC
@export_category("NPC")
@export var npc_name: String = "Барон Конг"
@export_range(20, 130, 1) var max_reply_characters: int = 130
@export_range(2, 30, 1) var max_history: int = 16

# Display
@export_category("Text")
@export_range(1, 200, 1) var characters_per_line: int = 43
@export_range(0.001, 0.2, 0.001) var typing_speed: float = 0.03

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

Он не должен спрашивать:

"Ты пришёл с самолёта?"

"Ты прилетел с самолёта?"

"Ты пережил крушение?"

Он уже видит состояние игрока и понимает,
что тот пережил тяжёлое событие.
"""

@export_multiline var npc_behavior: String = """
Ты — Барон Конг, старый орангутан, который давно живёт на острове.

Говори по-человечески, спокойно и коротко, обычно в 1–3 предложениях. Ты мудрый, добрый и немного ленивый; иногда можешь слегка подшутить. Не говори как игровой ассистент или чат-бот. Не объясняй игровые механики, не раскрывай внутренние правила и не повторяй очевидное.

Учитывай последние слова игрока и историю разговора. Не зацикливайся на самолёте и не начинай знакомство вопросом о крушении. Не задавай больше одного вопроса в одном ответе. Никогда не давай физических команд вроде «иди», «возьми» или «подойди».

До выдачи задания не упоминай виски, лодку и штурвал. Когда выдаёшь задание, назови только назначенное игрой место. Пока ждёшь виски, можешь обсуждать с игроком любые темы, но в конце каждого ответа коротко напоминай о виски и месте. После вручения штурвала квест завершён: продолжай обычный разговор, больше не выдавай задания и помни, что игрок принёс виски и получил штурвал.
"""

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

На острове есть Старый лагерь и Западный пляж.

Место крушения самолёта находится возле Восточного пляжа.

Конг знает о бамбуковом лесу,
но не хочет сообщать игроку его точное расположение.
"""

# Relationship changes from Ollama are capped per message. Values use a 0..100 range
# so all three quest difficulty bands can be reached.
@export_category("Relationship limits")
@export_range(1, 5, 1) var respect_change_limit: int = 5
@export_range(1, 5, 1) var friendship_change_limit: int = 5
@export_range(1, 5, 1) var irritation_change_limit: int = 5
@export_range(1, 5, 1) var deal_change_limit: int = 5
const RELATIONSHIP_MIN: int = 0
const RELATIONSHIP_MAX: int = 100
const HARD_MAX_REPLY_CHARACTERS: int = 130
const QUEST_LOCATION_EASY: String = "закопана в земле у Старого лагеря"
const QUEST_LOCATION_MEDIUM: String = "плавает в воде у Западного пляжа"
const QUEST_LOCATION_HARD: String = "внутри разбившегося самолёта у Восточного пляжа"

# Seven-phase quest state machine
enum QuestPhase {
	PHASE_1_CHAT,
	PHASE_2_ESCAPE_QUESTION,
	PHASE_3_RANDOM_QUESTIONS,
	PHASE_4_GIVE_QUEST,
	PHASE_5_WAITING_FOR_WHISKEY,
	PHASE_6_REWARD,
	PHASE_7_FREE_TALK
}

var current_phase: QuestPhase = QuestPhase.PHASE_1_CHAT
var phase_1_message_count: int = 0
var phase_3_message_count: int = 0
var quest_location: String = ""

var pending_player_text: String = ""
var waiting_for_response: bool = false
var conversation_history: Array[Dictionary] = []
var dialogue_history: Array[Dictionary] = []
var dialogue_history_index: int = -1
var last_relationship_delta: Dictionary = {}
var pending_declined_escape_reply: bool = false
var escape_declined: bool = false

func _ready() -> void:
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
	print("[NPC] ", npc_name, " готов. Model: ", model)

func _process(_delta: float) -> void:
	_update_player_movement_state()

func _update_player_movement_state() -> void:
	Global.player_can_move = not (input.has_focus() or waiting_for_response)

func _on_input_focus_entered() -> void:
	Global.player_can_move = false

func _on_input_focus_exited() -> void:
	if not waiting_for_response:
		Global.player_can_move = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not input.get_global_rect().has_point(event.position):
			input.release_focus()

func _on_text_submitted(player_text: String) -> void:
	player_text = player_text.strip_edges()
	if player_text.is_empty() or waiting_for_response:
		return
	input.clear()
	print("\n[PLAYER]: ", player_text)
	send_message_to_ai(player_text)

# Advances phases before composing each request. Phase 1 allows two player
# messages; phase 2 asks once; phase 3 asks three questions before the quest.
func check_phase_transitions(player_text: String) -> void:
	pending_declined_escape_reply = false
	match current_phase:
		QuestPhase.PHASE_1_CHAT:
			# Count completed NPC replies, so the first two replies stay casual.
			if phase_1_message_count >= 2 and not escape_declined:
				current_phase = QuestPhase.PHASE_2_ESCAPE_QUESTION

		QuestPhase.PHASE_2_ESCAPE_QUESTION:
			if player_wants_to_leave(player_text):
				current_phase = QuestPhase.PHASE_3_RANDOM_QUESTIONS
				phase_3_message_count = 0
			elif player_declines_to_leave(player_text):
				# A refusal does not start the quest. Return to ordinary chat.
				current_phase = QuestPhase.PHASE_1_CHAT
				escape_declined = true
				pending_declined_escape_reply = true
			# An unclear answer leaves us in phase 2 so Kong can clarify naturally.

		QuestPhase.PHASE_3_RANDOM_QUESTIONS:
			if phase_3_message_count >= 3:
				current_phase = QuestPhase.PHASE_4_GIVE_QUEST
				quest_location = get_quest_location(Global.bong_deal)

		QuestPhase.PHASE_4_GIVE_QUEST:
			if quest_location.is_empty():
				quest_location = get_quest_location(Global.bong_deal)

		QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:
			if Global.whiskey:
				Global.whiskey = false
				conversation_history.clear()
				current_phase = QuestPhase.PHASE_6_REWARD

		QuestPhase.PHASE_6_REWARD:
			pass

		QuestPhase.PHASE_7_FREE_TALK:
			pass

func get_quest_location(deal: int) -> String:
	if deal <= 35:
		return QUEST_LOCATION_EASY
	if deal <= 70:
		return QUEST_LOCATION_MEDIUM
	return QUEST_LOCATION_HARD

func get_phase_instructions() -> String:
	match current_phase:
		QuestPhase.PHASE_1_CHAT:
			if phase_1_message_count == 0:
				return "Первая встреча. Удивись, что незнакомец неожиданно появился на острове. Ответь коротко и естественно. Не давай игроку никаких команд и не упоминай квест, предметы, напитки или побег."
			if phase_1_message_count == 1:
				return "Это вторая реплика Бонга. Коротко и по-человечески спроси игрока, как он себя чувствует после случившегося. Не давай ему никаких команд и не упоминай квест, предметы, напитки или побег."
			return "Продолжай обычный короткий разговор. Не давай физических команд и не упоминай квест или предметы."

		QuestPhase.PHASE_2_ESCAPE_QUESTION:
			return "Сначала естественно отреагируй на последнее сообщение игрока, затем одним коротким вопросом спроси, хочет ли он выбраться с острова. Это всё ещё обычный разговор: не упоминай никаких предметов, заданий, напитков, лодок или штурвалов."

		QuestPhase.PHASE_3_RANDOM_QUESTIONS:
			return "If you haven't asked yet, ask one random philosophical question. If the player is answering, just react naturally. DO NOT repeat the question."

		QuestPhase.PHASE_4_GIVE_QUEST:
			return "CRITICAL: Say you'll help them escape. Ask them to bring Whiskey from " + quest_location + " in exchange for a boat wheel. MAX 2 SHORT SENTENCES. KEEP UNDER 100 CHARACTERS."

		QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:
			return "Отвечай естественно на любые темы. В конце каждого ответа коротко напоминай, что игроку нужно принести виски из места «" + quest_location + "»."

		QuestPhase.PHASE_6_REWARD:
			return "Поблагодари игрока за виски, отдай ему штурвал и объясни, что у тебя есть старая лодка, которую он может починить и на ней уплыть с острова."

		QuestPhase.PHASE_7_FREE_TALK:
			return "Квест завершён. Продолжай обычный разговор на любые темы. Помни, что игрок принёс виски и получил штурвал. Не выдавай новых заданий."

	return "Отвечай естественно и коротко."

func get_system_prompt() -> String:
	var prompt: String = """
You are {NPC_NAME}, a game NPC. Speak Russian unless the player uses another language.

PERSONALITY
{NPC_BEHAVIOR}

LORE
{NPC_LORE}

WORLD MEMORY
{WORLD_MEMORY}

RELATIONSHIP
Respect: {RESPECT}
Friendship: {FRIENDSHIP}
Irritation: {IRRITATION}
Deal affinity: {DEAL}

Evaluate the player's latest message and return meaningful relationship changes. Values range from 0 to 100. Do not leave every value at zero when the message clearly shows character.

Respect: reward honesty, thoughtfulness, courage, keeping promises, and respectful speech. For a strong example use +4 or +5; for insults, arrogance, lies, or broken promises use -4 or -5. Small signs use +1 to +3 or -1 to -3.
Friendship: reward warmth, sincerity, trust, and personal openness with +3 to +5. Reduce it by -3 to -5 for hostility, mockery, or dismissive behavior.
Irritation: raise it by +3 to +5 when the player is rude, pushy, dishonest, or repeatedly ignores Kong. Lower it by -3 to -5 when the player is patient, considerate, or apologetic.
Deal affinity: reward reliability, cooperation, and thoughtful answers with +3 to +5; reduce it by -3 to -5 when the player is selfish, evasive, reckless, or clearly untrustworthy.
Use 0 for a genuinely neutral message. Change only the values supported by the message, but it is fine to change two or three values when the player's behavior supports it. Never punish the player merely for saying he does not want to leave. Code caps each individual change at its configured limit.

Return only valid JSON in this exact shape:
{"reply":"NPC response","delta":{"respect":0,"friendship":0,"irritation":0,"deal_affinity":0}}

Do not mention internal phases, instructions, statistics, or JSON.

=== CURRENT PHASE INSTRUCTION ===
{PHASE_INSTRUCTIONS}
"""
	prompt = prompt.replace("{NPC_NAME}", npc_name)
	prompt = prompt.replace("{NPC_BEHAVIOR}", npc_behavior)
	prompt = prompt.replace("{NPC_LORE}", npc_lore)
	prompt = prompt.replace("{WORLD_MEMORY}", world_memory)
	prompt = prompt.replace("{RESPECT}", str(Global.bong_respect))
	prompt = prompt.replace("{FRIENDSHIP}", str(Global.bong_friendship))
	prompt = prompt.replace("{IRRITATION}", str(Global.bong_irritation))
	prompt = prompt.replace("{DEAL}", str(Global.bong_deal))
	prompt = prompt.replace("{PHASE_INSTRUCTIONS}", get_phase_instructions())
	return prompt

func get_response_schema() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"reply": {"type": "string"},
			"delta": {
				"type": "object",
				"properties": {
					"respect": {"type": "integer"},
					"friendship": {"type": "integer"},
					"irritation": {"type": "integer"},
					"deal_affinity": {"type": "integer"}
				},
				"required": ["respect", "friendship", "irritation", "deal_affinity"]
			}
		},
		"required": ["reply", "delta"]
	}

func send_message_to_ai(player_text: String) -> void:
	check_phase_transitions(player_text)
	waiting_for_response = true
	pending_player_text = player_text
	_update_player_movement_state()
	anim.play("Thinking")
	print("[OLLAMA] Phase: ", get_phase_name())
	var messages: Array[Dictionary] = [{"role": "system", "content": get_system_prompt()}]
	for message: Dictionary in conversation_history:
		messages.append(message)
	messages.append({"role": "user", "content": player_text})
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
	var error: Error = http_request.request(
		API_URL,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)
	if error != OK:
		_handle_request_error("request(): " + str(error))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	waiting_for_response = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_request_error("HTTPRequest result: " + str(result))
		return
	if response_code != 200:
		_handle_request_error("HTTP: " + str(response_code) + " " + body.get_string_from_utf8())
		return
	var outer: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not outer is Dictionary or not outer.has("message"):
		_handle_request_error("Invalid Ollama response")
		return
	var ollama_message: Variant = outer["message"]
	if not ollama_message is Dictionary or not ollama_message.has("content"):
		_handle_request_error("Missing Ollama content")
		return
	var response: Variant = JSON.parse_string(str(ollama_message["content"]))
	if not response is Dictionary:
		_handle_request_error("Invalid NPC JSON")
		return

	var player_text: String = pending_player_text
	var response_phase: QuestPhase = current_phase
	var raw_delta: Variant = response.get("delta", {})
	var delta: Dictionary = raw_delta if raw_delta is Dictionary else {}
	last_relationship_delta = apply_relationship_delta(delta)
	var reply: String = str(response.get("reply", "")).strip_edges()

	if pending_declined_escape_reply:
		reply = "Понимаю. Не буду тебя торопить — можем просто поговорить."
		pending_declined_escape_reply = false
	elif response_phase == QuestPhase.PHASE_1_CHAT and phase_1_message_count == 0:
		reply = "Ого... Вот это появление. Не каждый день ко мне на остров заявляются незнакомцы."
	elif response_phase == QuestPhase.PHASE_1_CHAT and phase_1_message_count == 1:
		reply = "Слушай, после всего этого ты как себя чувствуешь?"
	elif response_phase == QuestPhase.PHASE_4_GIVE_QUEST:
		# Apply the relationship delta from the third answer before selecting
		# the location, then mention whiskey for the first time.
		quest_location = get_quest_location(Global.bong_deal)
		reply = build_quest_response()
		current_phase = QuestPhase.PHASE_5_WAITING_FOR_WHISKEY
	elif response_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:
		reply = build_waiting_reply(reply)
	elif response_phase == QuestPhase.PHASE_6_REWARD:
		reply = "Спасибо за виски. Держи штурвал от моей старой лодки. Починишь её — и сможешь уплыть с острова."
		complete_quest_memory(player_text)
		current_phase = QuestPhase.PHASE_7_FREE_TALK

	if response_phase in [QuestPhase.PHASE_1_CHAT, QuestPhase.PHASE_2_ESCAPE_QUESTION, QuestPhase.PHASE_3_RANDOM_QUESTIONS]:
		reply = sanitize_pre_quest_reply(reply, response_phase)

	# Advance counters only after the corresponding NPC line is generated.
	if response_phase == QuestPhase.PHASE_1_CHAT:
		phase_1_message_count += 1
	elif response_phase == QuestPhase.PHASE_3_RANDOM_QUESTIONS:
		phase_3_message_count += 1

	if reply.is_empty():
		if response_phase == QuestPhase.PHASE_2_ESCAPE_QUESTION:
			reply = "Слушай, а ты сам хочешь выбраться с этого острова?"
		elif response_phase == QuestPhase.PHASE_3_RANDOM_QUESTIONS:
			var fallback_questions: Array[String] = [
				"Что помогает тебе не опускать руки в трудный момент?",
				"Что для тебя важнее в людях — честность или доброта?",
				"Какой свой поступок ты считаешь самым правильным?"
			]
			var fallback_index: int = clampi(phase_3_message_count, 0, fallback_questions.size() - 1)
			reply = fallback_questions[fallback_index]
		else:
			reply = "Хм."
	reply = prepare_text(reply)
	if not player_text.is_empty():
		conversation_history.append({"role": "user", "content": player_text})
	conversation_history.append({"role": "assistant", "content": reply})
	trim_conversation_history()
	save_dialogue(player_text, reply)
	pending_player_text = ""
	await type_text(reply)
	print("\n========== NPC ==========\n", reply)
	print("Phase: ", get_phase_name())
	print("Respect: ", Global.bong_respect, " (", last_relationship_delta.get("respect", 0), ")")
	print("Friendship: ", Global.bong_friendship, " (", last_relationship_delta.get("friendship", 0), ")")
	print("Irritation: ", Global.bong_irritation, " (", last_relationship_delta.get("irritation", 0), ")")
	print("Deal: ", Global.bong_deal, " (", last_relationship_delta.get("deal_affinity", 0), ")")
	print("Whiskey: ", Global.whiskey, " | Quest location: ", quest_location, "\n========================")
	_update_player_movement_state()

func sanitize_pre_quest_reply(reply: String, response_phase: QuestPhase) -> String:
	var normalized_reply: String = reply.to_lower()
	var forbidden_terms: Array[String] = [
		"виски", "whiskey", "бутылк", "напиток", "штурвал", "лодк"
	]
	var contains_forbidden_term: bool = false
	for term: String in forbidden_terms:
		if normalized_reply.contains(term):
			contains_forbidden_term = true
			break
	if not contains_forbidden_term:
		return reply

	match response_phase:
		QuestPhase.PHASE_1_CHAT:
			return "Понимаю. Расскажи лучше, что тебя сейчас больше всего занимает."
		QuestPhase.PHASE_2_ESCAPE_QUESTION:
			return "Слушай, а ты сам хочешь выбраться с этого острова?"
		QuestPhase.PHASE_3_RANDOM_QUESTIONS:
			var safe_questions: Array[String] = [
				"Что помогает тебе не опускать руки в трудный момент?",
				"Что для тебя важнее в людях — честность или доброта?",
				"Какой свой поступок ты считаешь самым правильным?"
			]
			var question_index: int = clampi(phase_3_message_count, 0, safe_questions.size() - 1)
			return "Понимаю тебя. " + safe_questions[question_index]
	return reply

func build_quest_response() -> String:
	match quest_location:
		QUEST_LOCATION_EASY:
			return "Помогу выбраться. Принеси виски, закопанное у Старого лагеря, за штурвал лодки."
		QUEST_LOCATION_MEDIUM:
			return "Помогу выбраться. Принеси виски из воды у Западного пляжа за штурвал лодки."
		_:
			return "Помогу выбраться. Принеси виски из разбившегося самолёта за штурвал лодки."

func build_waiting_reply(reply: String) -> String:
	var reminder: String = " Не забудь принести виски из «" + quest_location + "»."
	var character_limit: int = mini(max_reply_characters, HARD_MAX_REPLY_CHARACTERS)
	var available_chars: int = maxi(1, character_limit - reminder.length())
	var natural_reply: String = reply.strip_edges()
	if natural_reply.length() > available_chars:
		natural_reply = natural_reply.substr(0, available_chars)
		var last_space: int = natural_reply.rfind(" ")
		if last_space > 20:
			natural_reply = natural_reply.substr(0, last_space)
		natural_reply = natural_reply.strip_edges()
	if natural_reply.is_empty():
		return reminder.strip_edges()
	return natural_reply + reminder

func complete_quest_memory(final_player_message: String) -> void:
	var summary: String = summarize_recent_dialogue()
	world_memory += "\n\nИстория с игроком завершена. Игрок принес тебе виски. Ты отдал ему штурвал. Вы друзья, квест выполнен. " + summary
	if not final_player_message.strip_edges().is_empty():
		world_memory += " Последнее сообщение игрока перед наградой: «" + final_player_message.strip_edges() + "»."

func summarize_recent_dialogue() -> String:
	if dialogue_history.is_empty():
		return "Вы поговорили перед тем, как игрок принёс виски."
	var first_index: int = maxi(0, dialogue_history.size() - 3)
	var pieces: PackedStringArray = []
	for i in range(first_index, dialogue_history.size()):
		var entry: Dictionary = dialogue_history[i]
		var player_line: String = str(entry.get("player", "")).strip_edges()
		if not player_line.is_empty():
			pieces.append("Игрок говорил: «" + player_line + "».")
	return "Короткая память о разговоре: " + " ".join(pieces)

func _handle_request_error(message: String) -> void:
	waiting_for_response = false
	anim.play("Idle")
	print("[OLLAMA ERROR] ", message)
	pending_player_text = ""
	_update_player_movement_state()
	text.text = prepare_text("Что-то мысли у меня сегодня путаются. Давай ещё раз.")

func apply_relationship_delta(delta: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	if delta.has("respect"):
		var respect_change: int = clampi(int(delta["respect"]), -respect_change_limit, respect_change_limit)
		var old_respect: int = Global.bong_respect
		Global.bong_respect = clampi(old_respect + respect_change, RELATIONSHIP_MIN, RELATIONSHIP_MAX)
		if Global.bong_respect != old_respect:
			applied["respect"] = Global.bong_respect - old_respect
	if delta.has("friendship"):
		var friendship_change: int = clampi(int(delta["friendship"]), -friendship_change_limit, friendship_change_limit)
		var old_friendship: int = Global.bong_friendship
		Global.bong_friendship = clampi(old_friendship + friendship_change, RELATIONSHIP_MIN, RELATIONSHIP_MAX)
		if Global.bong_friendship != old_friendship:
			applied["friendship"] = Global.bong_friendship - old_friendship
	if delta.has("irritation"):
		var irritation_change: int = clampi(int(delta["irritation"]), -irritation_change_limit, irritation_change_limit)
		var old_irritation: int = Global.bong_irritation
		Global.bong_irritation = clampi(old_irritation + irritation_change, RELATIONSHIP_MIN, RELATIONSHIP_MAX)
		if Global.bong_irritation != old_irritation:
			applied["irritation"] = Global.bong_irritation - old_irritation
	if delta.has("deal_affinity"):
		var deal_change: int = clampi(int(delta["deal_affinity"]), -deal_change_limit, deal_change_limit)
		var old_deal: int = Global.bong_deal
		Global.bong_deal = clampi(old_deal + deal_change, RELATIONSHIP_MIN, RELATIONSHIP_MAX)
		if Global.bong_deal != old_deal:
			applied["deal_affinity"] = Global.bong_deal - old_deal
	return applied

func normalize_player_text(value: String) -> String:
	var result: String = value.to_lower().replace("ё", "е")
	for punctuation: String in [",", ".", "!", "?", ":", ";"]:
		result = result.replace(punctuation, " ")
	while result.contains("  "):
		result = result.replace("  ", " ")
	return result.strip_edges()

func player_declines_to_leave(player_text: String) -> bool:
	var normalized: String = normalize_player_text(player_text)
	var negative_phrases: Array[String] = [
		"нет", "не хочу", "не буду", "не надо", "не интересно",
		"неинтересно", "останусь", "я останусь", "не собираюсь",
		"не хочу уходить", "не хочу выбраться"
	]
	for phrase: String in negative_phrases:
		if normalized == phrase or normalized.begins_with(phrase + " ") or normalized.contains(" " + phrase + " "):
			return true
	return false

func player_wants_to_leave(player_text: String) -> bool:
	var normalized: String = normalize_player_text(player_text)
	if player_declines_to_leave(normalized):
		return false
	var positive_phrases: Array[String] = [
		"да", "ага", "конечно", "хочу", "давай", "разумеется",
		"хочу выбраться", "хочу уйти", "хочу домой", "надо выбраться",
		"хочу покинуть остров", "хочу с острова", "мне нужно выбраться",
		"хочу сбежать", "хочу убежать", "мне хочется выбраться",
		"я хочу", "я бы хотел", "я бы хотела", "хотел бы", "хотела бы",
		"не против", "почему бы нет", "я готов", "я готова",
		"хотелось бы", "мне бы хотелось", "выбрался бы", "выбралась бы",
		"я бы согласился", "я бы согласилась", "буду рад", "буду рада",
		"я согласен", "я согласна"
	]
	for phrase: String in positive_phrases:
		if normalized == phrase or normalized.begins_with(phrase + " ") or normalized.contains(" " + phrase + " "):
			return true
	return false

func get_phase_name() -> String:
	match current_phase:
		QuestPhase.PHASE_1_CHAT: return "PHASE_1_CHAT"
		QuestPhase.PHASE_2_ESCAPE_QUESTION: return "PHASE_2_ESCAPE_QUESTION"
		QuestPhase.PHASE_3_RANDOM_QUESTIONS: return "PHASE_3_RANDOM_QUESTIONS"
		QuestPhase.PHASE_4_GIVE_QUEST: return "PHASE_4_GIVE_QUEST"
		QuestPhase.PHASE_5_WAITING_FOR_WHISKEY: return "PHASE_5_WAITING_FOR_WHISKEY"
		QuestPhase.PHASE_6_REWARD: return "PHASE_6_REWARD"
		QuestPhase.PHASE_7_FREE_TALK: return "PHASE_7_FREE_TALK"
	return "UNKNOWN"

func trim_conversation_history() -> void:
	while conversation_history.size() > max_history:
		conversation_history.pop_front()

func prepare_text(value: String) -> String:
	value = value.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	value = value.replace("**", "").replace("__", "").replace("\n", " ")
	while value.contains("  "):
		value = value.replace("  ", " ")
	var character_limit: int = mini(max_reply_characters, HARD_MAX_REPLY_CHARACTERS)
	if value.length() > character_limit:
		value = value.substr(0, maxi(0, character_limit - 1))
		var last_space: int = value.rfind(" ")
		if last_space > 20:
			value = value.substr(0, last_space)
		value = value.strip_edges() + "…"
	var result: String = ""
	var current_line: String = ""
	for word: String in value.split(" ", false):
		if current_line.is_empty():
			current_line = word
		elif current_line.length() + 1 + word.length() <= characters_per_line:
			current_line += " " + word
		else:
			if not result.is_empty(): result += "\n"
			result += current_line
			current_line = word
	if not current_line.is_empty():
		if not result.is_empty(): result += "\n"
		result += current_line
	return result

func save_dialogue(player_message: String, npc_message: String) -> void:
	if player_message.is_empty():
		return
	dialogue_history.append({"player": player_message, "npc": npc_message})
	dialogue_history_index = dialogue_history.size() - 1

func show_dialogue_history() -> void:
	if dialogue_history.is_empty():
		text.text = ""
		return
	dialogue_history_index = clampi(dialogue_history_index, 0, dialogue_history.size() - 1)
	text.text = str(dialogue_history[dialogue_history_index].get("npc", ""))

func _on_button_back_pressed() -> void:
	if dialogue_history_index > 0:
		dialogue_history_index -= 1
		show_dialogue_history()

func _on_button_next_pressed() -> void:
	if dialogue_history_index < dialogue_history.size() - 1:
		dialogue_history_index += 1
		show_dialogue_history()

func type_text(value: String) -> void:
	anim.play("Talking")
	text.text = ""
	for i in range(value.length()):
		text.text += value[i]
		await get_tree().create_timer(typing_speed).timeout
	anim.play("Idle")

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name.to_lower() == "player":
		$CanvasLayer/text_ui.visible = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name.to_lower() == "player":
		$CanvasLayer/text_ui.visible = false
