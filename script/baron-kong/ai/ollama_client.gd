class_name OllamaClient
extends RefCounted


# ============================================================
# CONFIGURATION
# ============================================================

var api_url: String = ""
var model: String = ""

var temperature: float = 0.25
var max_output_tokens: int = 180
var max_history: int = 16


# ============================================================
# BUILD REQUEST
# ============================================================

func build_request(
	system_prompt: String,
	history: Array[Dictionary],
	player_text: String
) -> Dictionary:

	var messages: Array[Dictionary] = []

	# --------------------------------------------------------
	# SYSTEM
	# --------------------------------------------------------

	messages.append({
		"role": "system",
		"content": system_prompt
	})

	# --------------------------------------------------------
	# HISTORY
	# --------------------------------------------------------

	for message: Dictionary in history:
		messages.append(message)

	# --------------------------------------------------------
	# CURRENT PLAYER MESSAGE
	# --------------------------------------------------------

	messages.append({
		"role": "user",
		"content": player_text
	})

	# --------------------------------------------------------
	# REQUEST
	# --------------------------------------------------------

	var request_body: Dictionary = {
		"model": model,

		"messages": messages,

		"stream": false,

		"think": false,

		"format": {
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
		},

		"options": {
			"temperature": temperature,
			"num_predict": max_output_tokens,
			"top_p": 0.9,
			"top_k": 40,
			"repeat_penalty": 1.10
		}
	}

	return request_body


# ============================================================
# PARSE RESPONSE
# ============================================================

func parse_response(
	body: PackedByteArray
) -> Dictionary:

	# --------------------------------------------------------
	# BYTES → STRING
	# --------------------------------------------------------

	var raw: String = body.get_string_from_utf8()

	if raw.is_empty():
		push_error("[OllamaClient] Empty response body.")
		return {}

	# --------------------------------------------------------
	# OUTER JSON
	# --------------------------------------------------------

	var outer: Variant = JSON.parse_string(raw)

	if outer == null:
		push_error("[OllamaClient] Invalid outer JSON.")
		return {}

	if not outer is Dictionary:
		push_error("[OllamaClient] Outer JSON is not a Dictionary.")
		return {}

	var outer_dict: Dictionary = outer

	# --------------------------------------------------------
	# MESSAGE
	# --------------------------------------------------------

	if not outer_dict.has("message"):
		push_error("[OllamaClient] Missing 'message'.")
		return {}

	var message_variant: Variant = outer_dict["message"]

	if not message_variant is Dictionary:
		push_error("[OllamaClient] 'message' is not a Dictionary.")
		return {}

	var message: Dictionary = message_variant

	# --------------------------------------------------------
	# CONTENT
	# --------------------------------------------------------

	if not message.has("content"):
		push_error("[OllamaClient] Missing 'content'.")
		return {}

	var content_variant: Variant = message["content"]

	var content: String = str(content_variant).strip_edges()

	if content.is_empty():
		push_error("[OllamaClient] Empty message content.")
		return {}

	# --------------------------------------------------------
	# NPC JSON
	# --------------------------------------------------------

	var result: Variant = JSON.parse_string(content)

	if result == null:
		push_error("[OllamaClient] NPC content is not valid JSON.")
		return {}

	if not result is Dictionary:
		push_error("[OllamaClient] NPC JSON is not a Dictionary.")
		return {}

	var result_dict: Dictionary = result

	# --------------------------------------------------------
	# VALIDATE RESPONSE
	# --------------------------------------------------------

	if not result_dict.has("reply"):
		push_error("[OllamaClient] Missing 'reply'.")
		return {}

	if not result_dict.has("delta"):
		push_error("[OllamaClient] Missing 'delta'.")
		return {}

	var reply_variant: Variant = result_dict["reply"]

	if not reply_variant is String:
		push_error("[OllamaClient] 'reply' is not a String.")
		return {}

	var delta_variant: Variant = result_dict["delta"]

	if not delta_variant is Dictionary:
		push_error("[OllamaClient] 'delta' is not a Dictionary.")
		return {}

	# --------------------------------------------------------
	# FINAL RESULT
	# --------------------------------------------------------

	return result_dict
