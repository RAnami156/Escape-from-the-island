extends CharacterBody2D

# ============================================================
# NODES
# ============================================================

@onready var input: LineEdit = $CanvasLayer/LineEdit
@onready var text: Label = $CanvasLayer/text
@onready var http_request: HTTPRequest = $HTTPRequest


# ============================================================
# OLLAMA
# ============================================================

const API_URL: String = "http://localhost:11434/api/chat"

var model: String = "qwen3:8b"

var temperature: float = 0.85
var max_output_tokens: int = 256

var pending_player_text: String = ""
var waiting_for_response: bool = false


# ============================================================
# NPC
# ============================================================

var npc_name: String = "Baron Kong"
var max_reply_characters: int = 220
const CHARS_PER_LINE: int = 46

var conversation_history: Array = []
var max_history: int = 12


# ============================================================
# RELATIONSHIP
# ============================================================

var relationship: Dictionary = {
	"respect": 30,
	"trust": 25,
	"friendship": 35,
	"affection": 20,
	"curiosity": 30,
	"patience": 70,
	"stress": 5,
	"empathy": 40,
	"humor": 50,
	"greed": 30,
	"player_wisdom": 0,
	"familiarity": 10
}


# ============================================================
# WORLD MEMORY
# ============================================================

var world_memory: Array[String] = [
	"Jsme na ostrově.",
	"Hráč spadl na ostrov po havárii letadla.",
	"Kong slyšel pád letadla.",
	"Kong říká letadlu „ocelový pták“.",
	"Kong je líný, klidný a zkušený orangutan.",
	"Kong má rád suchý humor a lehké popichování.",
	"Kong nezná budoucí události.",
	"Kong si nesmí vymýšlet neznámá fakta."
]


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	input.text = ""
	text.text = ""

	if not input.text_submitted.is_connected(_on_text_submitted):
		input.text_submitted.connect(_on_text_submitted)
	if not input.focus_entered.is_connected(block_player_movement):
		input.focus_entered.connect(block_player_movement)
	if not input.focus_exited.is_connected(allow_player_movement):
		input.focus_exited.connect(allow_player_movement)
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	print("[OLLAMA NPC] Baron Kong je připraven.")
	print("[OLLAMA NPC] Model: ", model)


# ============================================================
# FOCUS
# ============================================================

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if not input.get_global_rect().has_point(mouse_event.position):
				input.release_focus()


# ============================================================
# INPUT
# ============================================================

func _on_text_submitted(player_text: String) -> void:
	player_text = player_text.strip_edges()

	if player_text.is_empty():
		return

	if waiting_for_response:
		print("[OLLAMA] Čekám na předchozí odpověď...")
		return

	input.clear()

	print("")
	print("[Hráč]: ", player_text)

	send_message_to_ai(player_text)


# ============================================================
# SYSTEM PROMPT
# ============================================================

func get_system_prompt() -> String:
	return """
Jsi Baron Kong, orangutan a postava z videohry.

NEJSI AI ASISTENT.
NEJSI chatbot.
Jsi živá herní postava, která mluví přímo s hráčem.

CHARAKTER:
- Jsi zkušený orangutan.
- Jsi líný, klidný a sebevědomý.
- Máš suchý humor.
- Rád hráče lehce popichuješ.
- Nejsi přehnaně upovídaný.
- Mluvíš přirozeně.
- Mluv jako živý člověk, ne jako příručka nebo chatbot.
- Nejprve reaguj na význam poslední hráčovy zprávy.
- Obvykle odpovídej jednou nebo dvěma krátkými větami.
- Nepoužívej seznamy, úřední fráze, obecné úvody ani opakující se šablony.
- Nežertuj v každé odpovědi a neopakuj stále stejný vtip.
- Odpověď má být krátká.
- Maximální délka odpovědi je přibližně 220 znaků.

DŮLEŽITÉ PRAVIDLO KONVERZACE:

VŽDY reaguj na POSLEDNÍ zprávu hráče.

Starší zprávy slouží POUZE jako kontext.

NIKDY automaticky neopakuj svou předchozí odpověď.

Pokud hráč změní téma, okamžitě reaguj na nové téma.

Například:

Hráč: „PŘÍVĚT“
Kong: odpověď na pozdrav.

Hráč: „ty jsi to viděl“
Kong: odpověď na to, zda něco viděl.

Hráč: „jak se odsud dostanu“
Kong: odpověď na otázku o cestě.

Nesmíš odpovědět znovu stejnou odpovědí jen proto, že podobná odpověď byla použita předtím.

JAZYK:

Odpovídej v jazyce poslední zprávy hráče.

Pokud hráč píše rusky, odpověz rusky.
Pokud hráč píše česky, odpověz česky.
Pokud hráč píše anglicky, odpověz anglicky.

Není nutné překládat hráčovu zprávu.

SVĚT:

Víš pouze informace uvedené ve WORLD MEMORY a v historii rozhovoru.

Nejsi vševědoucí.

Nevymýšlej si fakta.

Neznáš budoucí události.

VZTAH:

Vztahové hodnoty měň pouze tehdy, když to opravdu vyplývá z poslední zprávy hráče.

U obyčejného pozdravu nebo běžné otázky většinou nech všechny hodnoty na 0.

Není normální změnit 10 nebo 12 hodnot kvůli jedné větě.

Obvykle změň pouze 0 až 2 relevantní hodnoty.

Každá změna musí být celé číslo od -2 do 2.

Například:
Pozdrav -> všechny hodnoty 0.
Hráč pomůže Kongovi -> trust nebo friendship může +1/+2.
Hráč uráží Konga -> respect nebo friendship může -1/-2.
Hráč řekne něco vtipného -> humor může +1.

Nikdy neměň všechny hodnoty bez důvodu.

VÝSTUP:

Vrať POUZE JSON.

Žádný markdown.
Žádné vysvětlení.
Žádný text před JSON.

Formát:

{
  "reply": "odpověď Konga",
  "delta": {
	"respect": 0,
	"trust": 0,
	"friendship": 0,
	"affection": 0,
	"curiosity": 0,
	"patience": 0,
	"stress": 0,
	"empathy": 0,
	"humor": 0,
	"greed": 0,
	"player_wisdom": 0,
	"familiarity": 0
  }
}
"""


# ============================================================
# WORLD MEMORY
# ============================================================

func get_world_memory() -> String:
	var result := "WORLD MEMORY:\n"

	for memory in world_memory:
		result += "- " + memory + "\n"

	return result


# ============================================================
# RELATIONSHIP CONTEXT
# ============================================================

func get_relationship_context() -> String:
	var result := "CURRENT RELATIONSHIP VALUES:\n"

	for key in relationship.keys():
		result += "- " + str(key) + ": " + str(relationship[key]) + "\n"

	return result


# ============================================================
# JSON SCHEMA
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
					"respect": {"type": "integer"},
					"trust": {"type": "integer"},
					"friendship": {"type": "integer"},
					"affection": {"type": "integer"},
					"curiosity": {"type": "integer"},
					"patience": {"type": "integer"},
					"stress": {"type": "integer"},
					"empathy": {"type": "integer"},
					"humor": {"type": "integer"},
					"greed": {"type": "integer"},
					"player_wisdom": {"type": "integer"},
					"familiarity": {"type": "integer"}
				},
				"required": [
					"respect",
					"trust",
					"friendship",
					"affection",
					"curiosity",
					"patience",
					"stress",
					"empathy",
					"humor",
					"greed",
					"player_wisdom",
					"familiarity"
				]
			}
		},
		"required": [
			"reply",
			"delta"
		]
	}


# ============================================================
# SEND TO OLLAMA
# ============================================================

func send_message_to_ai(player_text: String) -> void:

	waiting_for_response = true
	pending_player_text = player_text

	print("[OLLAMA] Odesílám požadavek...")
	print("[OLLAMA] Model: ", model)

	var messages: Array = []

	# --------------------------------------------------------
	# SYSTEM
	# --------------------------------------------------------

	var system_message := (
		get_system_prompt()
		+ "\n\n"
		+ get_world_memory()
		+ "\n"
		+ get_relationship_context()
	)

	messages.append({
		"role": "system",
		"content": system_message
	})


	# --------------------------------------------------------
	# HISTORY
	# --------------------------------------------------------

	for message in conversation_history:
		messages.append(message)


	# --------------------------------------------------------
	# CURRENT MESSAGE
	# --------------------------------------------------------
	# DŮLEŽITÉ:
	# Aktuální zpráva je vždy úplně poslední.
	# --------------------------------------------------------

	messages.append({
		"role": "user",
		"content": (
			"CURRENT PLAYER MESSAGE:\n"
			+ player_text
			+ "\n\n"
			+ "Respond specifically to this message."
		)
	})


	# --------------------------------------------------------
	# REQUEST
	# --------------------------------------------------------

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
			"repeat_penalty": 1.20
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

		print("[OLLAMA ERROR] request() error: ", error)


# ============================================================
# RESPONSE
# ============================================================

func _on_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	waiting_for_response = false

	print("")
	print("========== OLLAMA ==========")
	print("HTTP: ", response_code)

	if result != HTTPRequest.RESULT_SUCCESS:
		print("[OLLAMA ERROR] HTTPRequest result: ", result)

		pending_player_text = ""
		return

	if response_code != 200:
		print("[OLLAMA ERROR] HTTP code: ", response_code)
		print(body.get_string_from_utf8())

		pending_player_text = ""
		return


	var raw_text := body.get_string_from_utf8()

	print("[OLLAMA RAW]: ", raw_text)

	var outer_json = JSON.parse_string(raw_text)

	if outer_json == null or not outer_json is Dictionary:
		print("[OLLAMA ERROR] Nelze parsovat Ollama JSON.")

		pending_player_text = ""
		return


	if not outer_json.has("message"):
		print("[OLLAMA ERROR] Chybí message.")

		pending_player_text = ""
		return


	var ollama_message: Dictionary = outer_json["message"]

	if not ollama_message.has("content"):
		print("[OLLAMA ERROR] Chybí message.content.")

		pending_player_text = ""
		return


	var ai_content: String = str(ollama_message["content"]).strip_edges()

	var response_json = JSON.parse_string(ai_content)

	if response_json == null or not response_json is Dictionary:
		print("[OLLAMA ERROR] Model nevrátil validní JSON.")
		print("[OLLAMA CONTENT]: ", ai_content)

		pending_player_text = ""
		return


	# --------------------------------------------------------
	# REPLY
	# --------------------------------------------------------

	var response_text: String = str(
		response_json.get("reply", "")
	).strip_edges()

	if response_text.is_empty():
		response_text = "Hmm."

	response_text = prepare_text(response_text)


	# --------------------------------------------------------
	# DELTA
	# --------------------------------------------------------

	var delta: Dictionary = {}

	if response_json.has("delta"):
		if response_json["delta"] is Dictionary:
			delta = response_json["delta"]


	# --------------------------------------------------------
	# APPLY RELATIONSHIP
	# --------------------------------------------------------

	apply_relationship_delta(delta)


	# --------------------------------------------------------
	# SAVE CORRECT HISTORY
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
	# LIMIT HISTORY
	# --------------------------------------------------------

	while conversation_history.size() > max_history:
		conversation_history.pop_front()


	pending_player_text = ""


	# --------------------------------------------------------
	# DISPLAY
	# --------------------------------------------------------

	text.text = response_text

	print("[NPC]: ", response_text)

	print("")
	print("------ VZTAH ------")

	for key in relationship.keys():
		print(
			key,
			": ",
			relationship[key]
		)

	print("-------------------")
	print("============================")


# ============================================================
# RELATIONSHIP DELTA
# ============================================================

func apply_relationship_delta(delta: Dictionary) -> void:

	for key in relationship.keys():

		if not delta.has(key):
			continue

		var change: int = int(delta[key])

		# Bezpečnostní omezení.
		change = clampi(change, -2, 2)

		relationship[key] += change

		# Hodnoty držíme v rozumném rozsahu.
		relationship[key] = clampi(
			relationship[key],
			0,
			100
		)


# ============================================================
# TEXT PREPARATION
# ============================================================

func prepare_text(value: String) -> String:

	value = value.replace("\n", " ")
	value = value.strip_edges()

	# Pokud model omylem vrátí markdown.
	value = value.replace("**", "")
	value = value.replace("```", "")

	if value.length() > max_reply_characters:
		value = value.substr(
			0,
			max_reply_characters
		)

	var lines: Array[String] = []
	var position: int = 0

	while position < value.length():
		var line_length: int = min(
			CHARS_PER_LINE,
			value.length() - position
		)
		var line: String = value.substr(position, line_length)

		if position + line_length < value.length():
			var space_position: int = line.rfind(" ")
			if space_position > 0:
				line_length = space_position
				line = value.substr(position, line_length)

		line = line.strip_edges()
		if not line.is_empty():
			lines.append(line)

		position += line_length
		while position < value.length() and value[position] == " ":
			position += 1

	return "\n".join(lines)


# ============================================================
# MOVEMENT
# ============================================================

func block_player_movement() -> void:
	Global.player_can_move = false
	print("[NPC] Pohyb zablokován.")


func allow_player_movement() -> void:
	Global.player_can_move = true
	print("[NPC] Pohyb povolen.")
