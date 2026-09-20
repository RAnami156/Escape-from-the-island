extends CharacterBody2D


# ============================================================
# ODKAZY NA UZLY
# ============================================================

@onready var input: LineEdit = $CanvasLayer/LineEdit
@onready var text: Label = $CanvasLayer/text
@onready var http_request: HTTPRequest = $HTTPRequest


# ============================================================
# NASTAVENÍ GEMINI
# ============================================================

@export_category("Gemini")

# API klíč nedávej přímo do veřejného repozitáře.
@export var gemini_api_key: String = ""

@export var model: String = "gemini-3.6-flash"

@export_range(0.0, 2.0, 0.1)
var temperature: float = 0.8

@export_range(256, 4096, 256)
var max_output_tokens: int = 1024


# ============================================================
# NASTAVENÍ NPC
# ============================================================

@export_category("NPC")

@export var npc_name: String = "Baron Kong"

@export_multiline var npc_description: String = """
Jsi Baron Kong — líný, zkušený orangutan,
bývalý pokořitel sedmi vrcholů.
"""

@export_range(0.0, 1.0, 0.05)
var friendliness: float = 0.85

@export_range(0.0, 2.0, 0.1)
var relationship_sensitivity: float = 1.0

@export_range(0.0, 1.0, 0.05)
var humor: float = 0.70

@export_range(0.0, 1.0, 0.05)
var patience: float = 0.85

@export_range(0.0, 1.0, 0.05)
var curiosity: float = 0.65


# ============================================================
# NASTAVENÍ PAMĚTI
# ============================================================

@export_category("Paměť")

@export_range(2, 30, 1)
var max_history: int = 12

@export_range(1, 20, 1)
var max_world_memory: int = 10


# ============================================================
# NASTAVENÍ TEXTU
# ============================================================

@export_category("Text")

@export_range(20, 200, 10)
var max_reply_characters: int = 140

@export_range(1, 5, 1)
var max_lines: int = 3

@export_range(20, 80, 1)
var chars_per_line: int = 51

@export_range(0.01, 0.1, 0.005)
var type_delay: float = 0.035


# ============================================================
# API
# ============================================================

const API_URL: String = \
	"https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s"


# ============================================================
# STAV
# ============================================================

var player_in: bool = false
var request_in_progress: bool = false

var conversation_history: Array = []

var world_memory: Array[String] = [
	"Jsme na ostrově.",
	"Hráč spadl na ostrov po havárii letadla.",
	"Kong slyšel pád letadla.",
	"Kong říká letadlu ocelový pták.",
	"Kong je líný, klidný a zkušený orangutan.",
	"Kong má rád suchý humor a lehké popichování.",
	"Kong nezná budoucí události.",
	"Kong si nesmí vymýšlet neznámá fakta."
]


# ============================================================
# SYSTÉM VZTAHU
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
# SYSTÉMOVÝ PROMPT
# ============================================================

func get_system_prompt() -> String:

	return """
Jsi živá postava z videohry, ne asistent.

Tvé jméno: %s.

%s

CHARAKTER:
Jsi klidný, líný a zkušený orangutan.
Jsi bývalý pokořitel sedmi vrcholů.
Mluvíš jednoduchou, přirozenou češtinou.
Můžeš vtipkovat, divit se, pochybovat, souhlasit
a občas hráči nerozumět.

NESMÍŠ znít jako ChatGPT.
Nemluv úředně.
Nepoužívej dlouhé filozofické monology.
Neříkej „jako AI“.
Nemluv o promptech.
Nemluv o JSON.
Nenazývej hráče hrdinou.
Nevystupuj jako vševědoucí postava.

NEJSI VŠEVĚDOUCÍ:
Pokud Kong něco neví, může jednoduše říct:
„Nevím.“
Nevymýšlej si fakta o ostrově.

STYL:
Jednoduchá hovorová čeština.
Krátké přirozené repliky.
Občas suchý humor.
Občas lehké popichování.
Občas vážnost.
Reaguj na konkrétní slova hráče.

PŘÁTELSKOST:
Aktuální úroveň přátelskosti: %.2f / 1.0.

Na začátku setkání se Kong k hráči chová spíše přátelsky.
Hráč si NEMUSÍ neustále získávat respekt.
Běžné pozdravy, otázky a normální rozhovor
obvykle vztah trochu zlepší.

VZTAH:
Aktuální hodnoty jsou předány samostatně.
Používej je pro své chování.

Vztah se má měnit postupně, ale živě.
Nenechávej všechny hodnoty delta vždy na nule.

Příklady:
přátelskost -> friendship +1, trust +1
zajímavá otázka -> curiosity +1
chytrá myšlenka -> player_wisdom +1, respect +1
vtip -> humor +1, friendship +1
urážka -> respect -1/-3, stress +1/+3
výhrůžka -> trust -2/-5, stress +2/+5
pomoc Kongovi -> trust +1/+5, friendship +1/+4
upřímnost -> trust +1/+3
lež -> trust -2/-5
zájem o Konga -> familiarity +1/+3
chamtivé chování hráče -> greed +1
klidný rozhovor -> stress -1
agresivita hráče -> stress +1/+4
hloupý, ale neškodný vtip -> humor +1
zajímavá informace -> curiosity +1, player_wisdom +1

Neměň vztah náhodně.
Změna musí souviset se zprávou hráče.

CITLIVOST VZTAHU:
Citlivost: %.2f.

Sílu reakce přibližně násob touto citlivostí.
Nikdy ale nepřekroč rozsah -5...+5.

DŮLEŽITÉ:
Neříkej hráči číselné hodnoty vztahu.

ODPOVĚĎ:
reply — jedna krátká Kongova replika.
Maximum %d znaků.

delta obsahuje změny hodnot vztahu.

Vrať POUZE JSON.
Žádný text před JSON.
Žádný text za JSON.
Žádný markdown.
""" % [
		npc_name,
		npc_description,
		friendliness,
		relationship_sensitivity,
		max_reply_characters
	]


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	input.visible = false

	text.visible = false
	text.modulate.a = 0.0
	text.text = ""

	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.max_lines_visible = max_lines

	if not input.text_submitted.is_connected(_on_text_submitted):
		input.text_submitted.connect(_on_text_submitted)

	if not http_request.request_completed.is_connected(
		_on_request_completed
	):
		http_request.request_completed.connect(
			_on_request_completed
		)

	if not input.focus_entered.is_connected(
		_on_input_focus_entered
	):
		input.focus_entered.connect(
			_on_input_focus_entered
		)

	if not input.focus_exited.is_connected(
		_on_input_focus_exited
	):
		input.focus_exited.connect(
			_on_input_focus_exited
		)

	print("[GEMINI NPC] ", npc_name, " je připraven.")


# ============================================================
# POHYB
# ============================================================

func _physics_process(_delta: float) -> void:

	input.visible = player_in

	move_and_slide()


func _input(event: InputEvent) -> void:

	if not player_in:
		return

	if event is InputEventMouseButton:

		var mouse_event: InputEventMouseButton = event

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:

				if not input.get_global_rect().has_point(
					mouse_event.position
				):
					input.release_focus()


# ============================================================
# OBLAST HRÁČE
# ============================================================

func _on_area_2d_body_entered(body: Node2D) -> void:

	if body.name == "player":

		player_in = true

		input.visible = true


func _on_area_2d_body_exited(body: Node2D) -> void:

	if body.name == "player":

		player_in = false

		input.visible = false

		input.release_focus()

		input.clear()

		Global.player_can_move = true


# ============================================================
# FOKUS VSTUPNÍHO POLE
# ============================================================

func _on_input_focus_entered() -> void:

	if player_in:

		Global.player_can_move = false

		print("[NPC] Pohyb zablokován.")


func _on_input_focus_exited() -> void:

	Global.player_can_move = true

	print("[NPC] Pohyb povolen.")


# ============================================================
# ZPRÁVA HRÁČE
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
# KONTEXT VZTAHU
# ============================================================

func get_relationship_context() -> String:

	return """
AKTUÁLNÍ VZTAH K HRÁČI:

respect = %d
trust = %d
friendship = %d
affection = %d
curiosity = %d
patience = %d
stress = %d
empathy = %d
humor = %d
greed = %d
player_wisdom = %d
familiarity = %d
""" % [
		int(relationship["respect"]),
		int(relationship["trust"]),
		int(relationship["friendship"]),
		int(relationship["affection"]),
		int(relationship["curiosity"]),
		int(relationship["patience"]),
		int(relationship["stress"]),
		int(relationship["empathy"]),
		int(relationship["humor"]),
		int(relationship["greed"]),
		int(relationship["player_wisdom"]),
		int(relationship["familiarity"])
	]


# ============================================================
# PAMĚŤ SVĚTA
# ============================================================

func get_world_memory() -> String:

	var memory: Array[String] = []

	var start: int = max(
		0,
		world_memory.size() - max_world_memory
	)

	for i: int in range(start, world_memory.size()):

		memory.append(
			"- " + world_memory[i]
		)

	return "\n".join(memory)


# ============================================================
# ODESLÁNÍ POŽADAVKU GEMINI
# ============================================================

func send_message_to_ai(player_text: String) -> void:

	if gemini_api_key.is_empty():

		print(
			"[GEMINI] API klíč není nastaven."
		)

		return


	print("")
	print("[Hráč]: ", player_text)


	conversation_history.append({
		"role": "user",
		"content": player_text
	})


	while conversation_history.size() > max_history:

		conversation_history.pop_front()


	var contents: Array = []


	# Systémová instrukce.
	contents.append({
		"role": "user",
		"parts": [
			{
				"text": get_system_prompt()
			}
		]
	})


	# Aktuální stav světa.
	contents.append({
		"role": "user",
		"parts": [
			{
				"text": (
					"STAV SVĚTA:\n"
					+ get_world_memory()
					+ "\n\n"
					+ get_relationship_context()
				)
			}
		]
	})


	# Historie.
	for message_value: Variant in conversation_history:

		if not message_value is Dictionary:
			continue

		var message: Dictionary = message_value

		var role: String = str(
			message.get("role", "user")
		)

		var content: String = str(
			message.get("content", "")
		)

		if role == "assistant":
			role = "model"
		else:
			role = "user"

		contents.append({
			"role": role,
			"parts": [
				{
					"text": content
				}
			]
		})


	var response_schema: Dictionary = {
		"type": "OBJECT",

		"properties": {
			"reply": {
				"type": "STRING"
			},

			"delta": {
				"type": "OBJECT",

				"properties": {
					"respect": {
						"type": "INTEGER"
					},

					"trust": {
						"type": "INTEGER"
					},

					"friendship": {
						"type": "INTEGER"
					},

					"affection": {
						"type": "INTEGER"
					},

					"curiosity": {
						"type": "INTEGER"
					},

					"patience": {
						"type": "INTEGER"
					},

					"stress": {
						"type": "INTEGER"
					},

					"empathy": {
						"type": "INTEGER"
					},

					"humor": {
						"type": "INTEGER"
					},

					"greed": {
						"type": "INTEGER"
					},

					"player_wisdom": {
						"type": "INTEGER"
					},

					"familiarity": {
						"type": "INTEGER"
					}
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


	var request_body: Dictionary = {

		"contents": contents,

		"generationConfig": {

			"temperature": temperature,

			"maxOutputTokens": max_output_tokens,

			"responseMimeType": "application/json",

			"responseSchema": response_schema
		}
	}


	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]


	var url: String = API_URL % [
		model,
		gemini_api_key
	]


	var json_data: String = JSON.stringify(
		request_body
	)


	request_in_progress = true


	var error: Error = http_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json_data
	)


	if error != OK:

		request_in_progress = false

		print(
			"[GEMINI] Chyba Godotu: ",
			error
		)


# ============================================================
# ODPOVĚĎ GEMINI
# ============================================================

func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	request_in_progress = false


	var raw: String = body.get_string_from_utf8()


	print("")
	print("========== GEMINI ==========")
	print("HTTP: ", response_code)


	if response_code != 200:

		print("[GEMINI] CHYBA API:")
		print(raw)

		if player_in:
			input.grab_focus()

		return


	var json: JSON = JSON.new()

	var parse_error: Error = json.parse(raw)


	if parse_error != OK:

		print("[GEMINI] Chyba JSON odpovědi API.")
		print(raw)

		return


	var data: Variant = json.data


	if not data is Dictionary:

		print("[GEMINI] Odpověď není Dictionary.")

		return


	var data_dict: Dictionary = data


	var candidates_value: Variant = data_dict.get(
		"candidates",
		[]
	)


	if not candidates_value is Array:

		print("[GEMINI] candidates není Array.")

		return


	var candidates: Array = candidates_value


	if candidates.is_empty():

		print("[GEMINI] candidates je prázdné.")

		return


	var candidate_value: Variant = candidates[0]


	if not candidate_value is Dictionary:

		print("[GEMINI] candidate není Dictionary.")

		return


	var candidate: Dictionary = candidate_value


	var content_value: Variant = candidate.get(
		"content",
		{}
	)


	if not content_value is Dictionary:

		print("[GEMINI] content není Dictionary.")

		return


	var content: Dictionary = content_value


	var parts_value: Variant = content.get(
		"parts",
		[]
	)


	if not parts_value is Array:

		print("[GEMINI] parts není Array.")

		return


	var parts: Array = parts_value


	if parts.is_empty():

		print("[GEMINI] parts je prázdné.")

		return


	var part_value: Variant = parts[0]


	if not part_value is Dictionary:

		print("[GEMINI] part není Dictionary.")

		return


	var part: Dictionary = part_value


	var response_text: String = str(
		part.get(
			"text",
			""
		)
	).strip_edges()


	if response_text.is_empty():

		print("[GEMINI] Prázdná odpověď.")

		return


	print(
		"[GEMINI RAW]: ",
		response_text
	)


	var result: Variant = JSON.parse_string(
		response_text
	)


	if not result is Dictionary:

		print(
			"[GEMINI] Nepodařilo se analyzovat JSON."
		)

		return


	var result_dict: Dictionary = result


	var reply: String = str(
		result_dict.get(
			"reply",
			""
		)
	).strip_edges()


	if reply.is_empty():

		print(
			"[GEMINI] Prázdná reply."
		)

		return


	var delta_value: Variant = result_dict.get(
		"delta",
		{}
	)


	if delta_value is Dictionary:

		var delta: Dictionary = delta_value

		apply_relationship_delta(delta)


	conversation_history.append({
		"role": "model",
		"content": response_text
	})


	while conversation_history.size() > max_history:

		conversation_history.pop_front()


	print("[NPC]: ", reply)

	print_relationship()

	print("============================")


	show_npc_text(reply)


# ============================================================
# AKTUALIZACE VZTAHU
# ============================================================

func apply_relationship_delta(
	delta: Dictionary
) -> void:

	var stats: Array[String] = [
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


	for stat: String in stats:

		if not delta.has(stat):
			continue


		var change: int = int(
			delta[stat]
		)


		change = clamp(
			change,
			-5,
			5
		)


		# Citlivost vztahu.
		change = roundi(
			float(change)
			* relationship_sensitivity
		)


		change = clamp(
			change,
			-5,
			5
		)


		var old_value: int = int(
			relationship[stat]
		)


		var new_value: int = clamp(
			old_value + change,
			0,
			100
		)


		relationship[stat] = new_value


# ============================================================
# VÝPIS VZTAHU
# ============================================================

func print_relationship() -> void:

	print("")
	print("------ VZTAH ------")

	for stat: String in relationship.keys():

		print(
			stat,
			": ",
			int(relationship[stat])
		)

	print("-------------------")


# ============================================================
# ZOBRAZENÍ
# ============================================================

func prepare_text(message: String) -> String:

	message = message.replace(
		"\n",
		" "
	).strip_edges()


	if message.is_empty():
		return ""


	var lines: Array[String] = []

	var position: int = 0

	var total_length: int = message.length()


	while position < total_length:

		if lines.size() >= max_lines:
			break


		var line_length: int = min(
			chars_per_line,
			total_length - position
		)


		var line: String = message.substr(
			position,
			line_length
		)


		if position + line_length < total_length:

			var space_position: int = line.rfind(" ")

			if space_position > 0:

				line_length = space_position

				line = message.substr(
					position,
					line_length
				)


		line = line.strip_edges()


		if not line.is_empty():

			lines.append(line)


		position += line_length


		while (
			position < total_length
			and message[position] == " "
		):

			position += 1


	return "\n".join(lines)


func show_npc_text(message: String) -> void:

	var display: String = prepare_text(
		message
	)


	if display.is_empty():
		return


	text.visible = true

	text.modulate.a = 1.0

	text.text = ""


	var length: int = display.length()


	for i: int in range(length):

		if not is_inside_tree():
			return


		text.text = display.substr(
			0,
			i + 1
		)


		await get_tree().create_timer(
			type_delay
		).timeout


	if player_in:

		input.grab_focus()


# ============================================================
# PAMĚŤ SVĚTA
# ============================================================

func add_world_memory(memory: String) -> void:

	memory = memory.strip_edges()


	if memory.is_empty():
		return


	if world_memory.has(memory):
		return


	world_memory.append(memory)


	while world_memory.size() > max_world_memory:

		world_memory.pop_front()


# ============================================================
# RESET
# ============================================================

func reset_conversation() -> void:

	conversation_history.clear()

	print(
		"[GEMINI] Historie konverzace byla vymazána."
	)


func reset_relationship() -> void:

	relationship = {
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

	print(
		"[GEMINI] Vztah byl resetován."
	)
