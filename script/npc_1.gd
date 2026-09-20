extends CharacterBody2D

@onready var input: LineEdit = $CanvasLayer/LineEdit
@onready var text: Label = $CanvasLayer/text
@onready var http_request: HTTPRequest = $HTTPRequest

# API klíč nedávej přímo do veřejného repozitáře.
@export var api_key: String = ""

const API_URL: String = "https://api.groq.com/openai/v1/chat/completions"
const MODEL: String = "openai/gpt-oss-20b"

const MAX_HISTORY: int = 4
const MAX_LINES: int = 3
const CHARS_PER_LINE: int = 51
const TYPE_DELAY: float = 0.035

var player_in: bool = false
var request_in_progress: bool = false

var conversation_history: Array = []
var text_tween: Tween


var relationship: Dictionary = {
	"respect": 20,
	"trust": 10,
	"stress": 5,
	"empathy": 15,
	"greed": 35,
	"player_wisdom": 0
}


var world_memory: Array[String] = [
	"Jsme na ostrově.",
	"Hráč spadl po havárii letadla.",
	"Kong slyšel pád letadla.",
	"Kong říká letadlu ocelový pták.",
	"Kong je líný, klidný a zkušený orangutan.",
	"Kong má rád suchý humor a lehké popichování.",
	"Kong nezná budoucí události.",
	"Kong si nesmí vymýšlet neznámá fakta."
]


const SYSTEM_PROMPT: String = """
Jsi Baron Kong — líný zkušený orangutan,
bývalý pokořitel sedmi vrcholů.

Mluv jednoduchou hovorovou češtinou.
Buď klidný a občas používej suchý humor.
Nebuď typický herní NPC.
Nedávej úkoly.
Nenazývej hráče hrdinou.
Nevymýšlej si neznámá fakta.
Pokud něco nevíš — řekni, že to nevíš.
Neříkej hráči číselné hodnoty vztahu.

ODPOVĚĎ:
reply má maximálně 120 znaků.

POVINNĚ vrať pouze jeden JSON objekt.

Formát:
{
  "reply": "krátká Kongova replika",
  "delta": {
    "respect": 0,
    "trust": 0,
    "stress": 0,
    "empathy": 0,
    "greed": 0,
    "player_wisdom": 0
  }
}

Všech šest hodnot delta je povinných.
Všechny hodnoty delta jsou celá čísla od -3 do 3.
Nepřidávej žádná další pole.
Nepoužívej markdown.
Nepoužívej ```.

PRAVIDLA:
Můžeš se tím řídit, ale dělej to přirozeně a podle situace.
Slušnost -> respect nebo trust +1.
Hrubost -> respect -1 nebo -2, stress +1.
Chytrá otázka -> player_wisdom +1.
Snaha získat výhodu nebo odměnu -> greed +1 nebo +2.
Hráč na Konga spěchá -> respect -1, stress +1.
"""


func _ready() -> void:
	input.visible = false

	text.visible = false
	text.modulate.a = 0.0
	text.text = ""

	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.max_lines_visible = MAX_LINES

	if not input.text_submitted.is_connected(_on_text_submitted):
		input.text_submitted.connect(_on_text_submitted)

	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	if not input.focus_entered.is_connected(_on_input_focus_entered):
		input.focus_entered.connect(_on_input_focus_entered)

	if not input.focus_exited.is_connected(_on_input_focus_exited):
		input.focus_exited.connect(_on_input_focus_exited)

	print("[NPC AI] Kong je připraven.")


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


func _on_input_focus_entered() -> void:
	if player_in:
		Global.player_can_move = false
		print("[NPC] Pohyb zablokován.")


func _on_input_focus_exited() -> void:
	Global.player_can_move = true
	print("[NPC] Pohyb povolen.")


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


func get_context() -> String:
	var memory_text: String = "\n".join(world_memory)

	return """
AKTUÁLNÍ VZTAH:
respect=%d
trust=%d
stress=%d
empathy=%d
greed=%d
player_wisdom=%d

PAMĚŤ:
%s
""" % [
		int(relationship["respect"]),
		int(relationship["trust"]),
		int(relationship["stress"]),
		int(relationship["empathy"]),
		int(relationship["greed"]),
		int(relationship["player_wisdom"]),
		memory_text
	]


func send_message_to_ai(player_text: String) -> void:
	if api_key.is_empty():
		print("[NPC AI] API klíč není nastaven.")
		return

	print("")
	print("[Hráč]: ", player_text)

	conversation_history.append({
		"role": "user",
		"content": player_text
	})

	# Ponecháme pouze 4 poslední zprávy.
	while conversation_history.size() > MAX_HISTORY:
		conversation_history.pop_front()


	var messages: Array = [
		{
			"role": "system",
			"content": SYSTEM_PROMPT
		},
		{
			"role": "system",
			"content": get_context()
		}
	]

	messages.append_array(conversation_history)


	var request_body: Dictionary = {
		"model": MODEL,
		"messages": messages,

		"max_completion_tokens": 1024,

		"temperature": 0.2,

		"reasoning_effort": "low",

		"include_reasoning": false
	}


	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]


	var json_data: String = JSON.stringify(
		request_body
	)


	request_in_progress = true


	var error: Error = http_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		json_data
	)


	if error != OK:
		request_in_progress = false

		print(
			"[NPC AI] Chyba Godotu: ",
			error
		)


func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	request_in_progress = false

	var raw: String = body.get_string_from_utf8()

	print("")
	print("========== NPC AI ==========")
	print("HTTP: ", response_code)


	if response_code != 200:
		print("[NPC AI] CHYBA API:")
		print(raw)
		print("============================")

		if player_in:
			input.grab_focus()

		return


	var json: JSON = JSON.new()

	var parse_error: Error = json.parse(raw)

	if parse_error != OK:
		print("[NPC AI] Chyba JSON odpovědi API.")
		print(raw)
		return


	var data: Variant = json.data

	if not data is Dictionary:
		print("[NPC AI] Odpověď API není Dictionary.")
		return


	var data_dict: Dictionary = data


	var choices_value: Variant = data_dict.get(
		"choices",
		[]
	)


	if not choices_value is Array:
		print("[NPC AI] choices není Array.")
		return


	var choices: Array = choices_value


	if choices.is_empty():
		print("[NPC AI] choices je prázdné.")
		return


	var choice_value: Variant = choices[0]


	if not choice_value is Dictionary:
		print("[NPC AI] choice není Dictionary.")
		return


	var choice: Dictionary = choice_value


	var finish_reason: String = str(
		choice.get(
			"finish_reason",
			""
		)
	)


	print(
		"[NPC] Důvod ukončení: ",
		finish_reason
	)


	if finish_reason == "length":
		print(
			"[NPC AI] Odpověď byla ukončena kvůli limitu tokenů."
		)

		if player_in:
			input.grab_focus()

		return


	var message_value: Variant = choice.get(
		"message",
		{}
	)


	if not message_value is Dictionary:
		print("[NPC AI] message není Dictionary.")
		return


	var message: Dictionary = message_value


	var content_value: Variant = message.get(
		"content",
		""
	)


	var content: String = str(
		content_value
	).strip_edges()


	if content.is_empty():
		print("[NPC AI] Prázdná odpověď.")
		return


	print("[NPC RAW]: ", content)


	var result: Variant = JSON.parse_string(
		content
	)


	if not result is Dictionary:
		print("[NPC AI] Odpověď není platný JSON.")
		print("[NPC AI] Pokusím se najít JSON uvnitř odpovědi.")

		result = extract_json(content)


	if not result is Dictionary:
		print("[NPC AI] Nepodařilo se získat JSON.")
		return


	var result_dict: Dictionary = result


	var reply: String = str(
		result_dict.get(
			"reply",
			""
		)
	).strip_edges()


	if reply.is_empty():
		print("[NPC AI] Prázdná reply.")
		return


	var delta_value: Variant = result_dict.get(
		"delta",
		{}
	)


	if delta_value is Dictionary:
		var delta: Dictionary = delta_value
		apply_delta(delta)


	conversation_history.append({
		"role": "assistant",
		"content": reply
	})


	while conversation_history.size() > MAX_HISTORY:
		conversation_history.pop_front()


	print("[NPC]: ", reply)

	print_relationship()

	print("============================")

	show_npc_text(reply)


func extract_json(content: String) -> Variant:
	var start: int = content.find("{")
	var finish: int = content.rfind("}")

	if start < 0:
		return null

	if finish <= start:
		return null


	var possible_json: String = content.substr(
		start,
		finish - start + 1
	)


	return JSON.parse_string(
		possible_json
	)


func apply_delta(delta: Dictionary) -> void:
	var stats: Array[String] = [
		"respect",
		"trust",
		"stress",
		"empathy",
		"greed",
		"player_wisdom"
	]


	for stat: String in stats:
		if not delta.has(stat):
			continue


		var value: int = clamp(
			int(delta[stat]),
			-3,
			3
		)


		var old_value: int = int(
			relationship[stat]
		)


		var new_value: int = clamp(
			old_value + value,
			0,
			100
		)


		relationship[stat] = new_value


func print_relationship() -> void:
	print("")
	print("------ VZTAH ------")

	print(
		"Respekt: ",
		relationship["respect"]
	)

	print(
		"Důvěra: ",
		relationship["trust"]
	)

	print(
		"Stres: ",
		relationship["stress"]
	)

	print(
		"Empatie: ",
		relationship["empathy"]
	)

	print(
		"Chamtivost: ",
		relationship["greed"]
	)

	print(
		"Moudrost hráče: ",
		relationship["player_wisdom"]
	)

	print("-------------------")


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
		if lines.size() >= MAX_LINES:
			break


		var remaining: int = (
			total_length - position
		)


		var line_length: int = min(
			CHARS_PER_LINE,
			remaining
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
	if text_tween != null:
		if text_tween.is_valid():
			text_tween.kill()


	var display: String = prepare_text(message)


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
			TYPE_DELAY
		).timeout


	if player_in:
		input.grab_focus()


func add_world_memory(memory: String) -> void:
	memory = memory.strip_edges()

	if memory.is_empty():
		return

	if world_memory.has(memory):
		return

	world_memory.append(memory)


func reset_conversation() -> void:
	conversation_history.clear()

	print("[NPC] Historie konverzace byla vymazána.")
