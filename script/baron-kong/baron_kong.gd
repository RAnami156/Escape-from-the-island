extends CharacterBody2D

# ============================================================
# BARON KONG
# Main orchestrator
# ============================================================

const API_URL := "http://localhost:11434/api/chat"

# ------------------------------------------------------------
# CHILD SYSTEMS
# ------------------------------------------------------------

var dialogue_state: DialogueState
var relationship_system: RelationshipSystem
var quest_system: KongQuest
var history_system: DialogueHistory
var ollama: OllamaClient
var prompt_builder: PromptBuilder
var dialogue_intent: DialogueIntent
var presenter: DialoguePresenter


# ============================================================
# NODES
# ============================================================

@onready var input: LineEdit = $CanvasLayer/text_ui/LineEdit
@onready var text: Label = $CanvasLayer/text_ui/text
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var anim: AnimatedSprite2D = $monkey


# ============================================================
# AI SETTINGS
# ============================================================

@export_category("AI")

@export var model := "qwen3:8b"

@export_range(0.0, 2.0, 0.05)
var temperature := 0.25

@export_range(32, 512, 1)
var max_output_tokens := 180

@export_range(2, 30, 1)
var max_history := 16


# ============================================================
# NPC
# ============================================================

@export_category("NPC")

@export var npc_name := "Барон Конг"

@export_range(20, 500, 1)
var max_reply_characters := 180


# ============================================================
# TEXT
# ============================================================

@export_category("Text")

@export_range(1, 200, 1)
var characters_per_line := 43

@export_range(0.001, 0.2, 0.001)
var typing_speed := 0.03


# ============================================================
# LORE
# ============================================================

@export_multiline
var npc_lore := """
Барон Конг — старый орангутан, который давно живёт на острове.

Он много лет находится здесь и знает остров очень хорошо.

Когда-то у Конга был корабль.

Он много плавал на нём, но со временем корабль разрушился.

Конг знает способ выбраться с острова.

Он спокойный, мудрый, немного ленивый и добрый.

Он может слегка подшучивать, но не превращается в клоуна.

Он способен сочувствовать.

Когда он видит игрока, он понимает, что тот пережил тяжёлое событие.

Конг не должен постоянно говорить о самолёте.

Он не должен начинать разговор с вопроса о самолёте.
"""


# ============================================================
# WORLD
# ============================================================

@export_multiline
var world_memory := """
Мы на острове.

Игрок оказался на острове после крушения самолёта.

Конг знает остров.

На острове есть:

Западный пляж.

Восточный пляж.

Бамбуковый лес.

Место крушения самолёта находится возле восточного пляжа.

В западной части острова возле берега можно найти бутылку в воде.

В бамбуковом лесу можно найти закопанную бутылку.

Возле места крушения самолёта можно найти бутылку.

У Конга есть старая разрушенная лодка.

Если её восстановить, на ней можно покинуть остров.

Конг знает о бамбуковом лесу,
но не раскрывает его точное расположение.
"""


# ============================================================
# BEHAVIOUR
# ============================================================

@export_multiline
var npc_behavior := """
Ты — Барон Конг.

Говори как живой старый человек.

Ты спокойный, мудрый, немного ленивый.

Обычно отвечай 1-2 предложениями.

Не говори как чат-бот.

Не объясняй игровые механики.

Не говори о правилах, стадиях, JSON или Ollama.

Не используй длинные монологи.

Не давай игроку физических команд.

Не говори:

"иди",
"подойди",
"садись",
"встань",
"следуй за мной",
"возьми",
"принеси",
"посмотри туда",
"повернись"
и подобные команды.

Не упоминай виски до финального квеста.

Не упоминай штурвал до финального квеста.

Не задавай больше одного вопроса за сообщение.

Не повторяй одинаковые фразы.
"""


# ============================================================
# INTERNAL
# ============================================================

var waiting_for_response := false
var pending_player_text := ""


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	dialogue_state = DialogueState.new()
	relationship_system = RelationshipSystem.new()
	quest_system = KongQuest.new()
	history_system = DialogueHistory.new()
	ollama = OllamaClient.new()
	prompt_builder = PromptBuilder.new()
	dialogue_intent = DialogueIntent.new()
	presenter = DialoguePresenter.new()

	relationship_system.setup()

	ollama.api_url = API_URL
	ollama.model = model
	ollama.temperature = temperature
	ollama.max_output_tokens = max_output_tokens
	ollama.max_history = max_history

	presenter.setup(
		text,
		anim,
		typing_speed,
		max_reply_characters,
		characters_per_line
	)

	$CanvasLayer/text_ui.visible = false

	input.text = ""
	text.text = ""

	anim.play("Idle")

	input.text_submitted.connect(_on_text_submitted)
	input.focus_entered.connect(_on_input_focus_entered)
	input.focus_exited.connect(_on_input_focus_exited)

	http_request.request_completed.connect(
		_on_request_completed
	)

	print("[KONG] Ready")


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:
	_update_player_movement_state()


# ============================================================
# PLAYER MOVEMENT
# ============================================================

func _update_player_movement_state() -> void:

	var blocked := (
		input.has_focus()
		or waiting_for_response
	)

	if is_instance_valid(Global):
		Global.player_can_move = not blocked


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

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:

				if not input.get_global_rect().has_point(
					event.position
				):
					input.release_focus()


# ============================================================
# PLAYER MESSAGE
# ============================================================

func _on_text_submitted(player_text: String) -> void:

	player_text = player_text.strip_edges()

	if player_text.is_empty():
		return

	if waiting_for_response:
		return

	if dialogue_state.is_finished():
		return

	input.clear()

	pending_player_text = player_text
	waiting_for_response = true

	_update_player_movement_state()

	anim.play("Thinking")

	_process_player_message(player_text)


# ============================================================
# DIALOGUE PROCESSOR
# ============================================================

func _process_player_message(player_text: String) -> void:

	var stage := dialogue_state.stage

	print(
		"[KONG] Player message: ",
		dialogue_state.player_message_count + 1
	)

	print(
		"[KONG] Stage: ",
		dialogue_state.get_stage_name()
	)

	# --------------------------------------------------------
	# FIRST TWO MESSAGES
	# --------------------------------------------------------

	if stage == DialogueState.Stage.FIRST_TWO_MESSAGES:

		await _request_ai(player_text)
		return


	# --------------------------------------------------------
	# INTRODUCTION
	# --------------------------------------------------------

	if stage == DialogueState.Stage.INTRODUCTION:

		var response := _build_introduction()

		_finish_dialogue_turn(
			player_text,
			response
		)

		return


	# --------------------------------------------------------
	# EXIT DECISION
	# --------------------------------------------------------

	if stage == DialogueState.Stage.ASKING_EXIT:

		if dialogue_intent.wants_to_leave(player_text):

			dialogue_state.wants_to_leave = true
			dialogue_state.stage = DialogueState.Stage.QUESTION_1
			dialogue_state.question_number = 1

			await _request_ai(player_text)
			return

		if dialogue_intent.declines_to_leave(player_text):

			dialogue_state.stage = DialogueState.Stage.DECLINED

			_finish_dialogue_turn(
				player_text,
				_build_declined()
			)

			return

		# Если ответ неясный — AI естественно просит уточнить.
		await _request_ai(player_text)
		return


	# --------------------------------------------------------
	# QUESTION 1
	# --------------------------------------------------------

	if stage == DialogueState.Stage.QUESTION_1:

		dialogue_state.stage = DialogueState.Stage.QUESTION_2
		dialogue_state.question_number = 2

		await _request_ai(player_text)
		return


	# --------------------------------------------------------
	# QUESTION 2
	# --------------------------------------------------------

	if stage == DialogueState.Stage.QUESTION_2:

		dialogue_state.stage = DialogueState.Stage.QUESTION_3
		dialogue_state.question_number = 3

		await _request_ai(player_text)
		return


	# --------------------------------------------------------
	# QUESTION 3
	# --------------------------------------------------------

	if stage == DialogueState.Stage.QUESTION_3:

		# Последний ответ игрока.
		# Ollama больше НЕ вызывается.

		dialogue_state.stage = DialogueState.Stage.FINAL_DEAL

		var final_response := quest_system.build_final_response(
			relationship_system,
			world_memory
		)

		quest_system.quest_given = true

		dialogue_state.stage = DialogueState.Stage.FINISHED

		_finish_dialogue_turn(
			player_text,
			final_response
		)

		return


# ============================================================
# AI REQUEST
# ============================================================

func _request_ai(player_text: String) -> void:

	var system_prompt := prompt_builder.build(
		npc_name,
		npc_lore,
		npc_behavior,
		world_memory,
		dialogue_state,
		relationship_system,
		quest_system
	)

	var messages := history_system.get_messages()

	var request_body := ollama.build_request(
		system_prompt,
		messages,
		player_text
	)

	var error := http_request.request(
		API_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)

	if error != OK:

		_handle_error(
			"Не удалось отправить запрос."
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

	if result != HTTPRequest.RESULT_SUCCESS:

		_handle_error(
			"Что-то с мыслями у меня сегодня не так. Давай ещё раз."
		)

		return

	if response_code != 200:

		_handle_error(
			"Что-то с мыслями у меня сегодня не так. Давай ещё раз."
		)

		return

	var parsed := ollama.parse_response(body)

	if parsed.is_empty():

		_handle_error(
			"Что-то с мыслями у меня сегодня не так. Давай ещё раз."
		)

		return

	var reply := str(
		parsed.get("reply", "")
	).strip_edges()

	var delta: Dictionary = parsed.get(
		"delta",
		{}
	)

	relationship_system.apply_delta(delta)

	var player_text := pending_player_text

	# Сохраняем AI conversation.
	history_system.add_user(player_text)
	history_system.add_assistant(reply)
	history_system.trim(max_history)

	# Увеличиваем количество сообщений игрока
	# только ПОСЛЕ полноценного ответа.
	dialogue_state.player_message_count += 1

	# --------------------------------------------------------
	# IMPORTANT:
	# После второго ответа автоматически переходим
	# к INTRODUCTION.
	# --------------------------------------------------------

	if dialogue_state.player_message_count == 2:

		dialogue_state.stage = (
			DialogueState.Stage.INTRODUCTION
		)

	# --------------------------------------------------------
	# После ответа на первый character question
	# stage уже был переключён ДО запроса.
	# --------------------------------------------------------

	_finish_dialogue_turn(
		player_text,
		reply
	)


# ============================================================
# FINISH TURN
# ============================================================

func _finish_dialogue_turn(
	player_text: String,
	reply: String
) -> void:

	reply = presenter.prepare(reply)

	if reply.is_empty():
		reply = "Хм."

	history_system.add_dialogue(
		player_text,
		reply
	)

	pending_player_text = ""
	waiting_for_response = false

	await presenter.type_text(reply)

	_update_player_movement_state()

	print("[KONG]")
	print(reply)
	print(
		"Stage: ",
		dialogue_state.get_stage_name()
	)


# ============================================================
# INTRODUCTION
# ============================================================

func _build_introduction() -> String:

	dialogue_state.player_message_count += 1

	dialogue_state.stage = (
		DialogueState.Stage.ASKING_EXIT
	)

	return """
Я Барон Конг. Давно живу на этом острове и знаю его лучше, чем хотелось бы. И знаю способ отсюда выбраться. Хочешь уйти?
"""


# ============================================================
# DECLINED
# ============================================================

func _build_declined() -> String:
	return "Ну, дело твоё. Если передумаешь — дай мне знать."


# ============================================================
# ERROR
# ============================================================

func _handle_error(message: String) -> void:

	waiting_for_response = false
	pending_player_text = ""

	anim.play("Idle")

	text.text = presenter.prepare(message)

	_update_player_movement_state()


# ============================================================
# AREA
# ============================================================

func _on_area_2d_body_entered(body: Node2D) -> void:

	if body.name.to_lower() == "player":
		$CanvasLayer/text_ui.visible = true


func _on_area_2d_body_exited(body: Node2D) -> void:

	if body.name.to_lower() == "player":
		$CanvasLayer/text_ui.visible = false
