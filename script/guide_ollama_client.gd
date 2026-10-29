extends Node

signal token_received(text: String)
signal completed(reply: String, metrics: Dictionary)
signal failed(reason: String)

var busy: bool = false
var timeout_seconds: float = 45.0
var _http: HTTPClient = HTTPClient.new()
var _buffer: PackedByteArray = PackedByteArray()
var _reply: String = ""
var _body: String = ""
var _sent: bool = false
var _headers_checked: bool = false
var _elapsed: float = 0.0
var _started_ms: int = 0
var _first_token_ms: int = -1
var _structured: bool = false
var _raw_content: String = ""


func _ready() -> void:
	set_process(false)


func send(host: String, port: int, payload: Dictionary) -> void:
	if busy:
		return
	_http.close()
	_buffer.clear()
	_reply = ""
	_raw_content = ""
	_structured = payload.get("format") is Dictionary
	_body = JSON.stringify(payload)
	_sent = false
	_headers_checked = false
	_elapsed = 0.0
	_started_ms = Time.get_ticks_msec()
	_first_token_ms = -1
	busy = true
	set_process(true)
	if _http.connect_to_host(host, port) != OK:
		_fail("connection")


func _process(delta: float) -> void:
	if not busy:
		return
	_elapsed += delta
	if _elapsed > timeout_seconds:
		_fail("timeout")
		return
	_http.poll()
	match _http.get_status():
		HTTPClient.STATUS_CONNECTED:
			if not _sent:
				_sent = true
				var error := _http.request(HTTPClient.METHOD_POST, "/api/chat", ["Content-Type: application/json"], _body)
				if error != OK:
					_fail("connection")
			else:
				# A final JSON event can arrive without a trailing newline.
				if not _buffer.is_empty():
					_consume_line(_buffer)
					_buffer.clear()
				if busy:
					_fail("interrupted")
		HTTPClient.STATUS_BODY:
			if not _headers_checked:
				_headers_checked = true
				var code := _http.get_response_code()
				if code != 200:
					_fail("model_not_found" if code == 404 else "http_" + str(code))
					return
			for _chunk_index in 32:
				var chunk := _http.read_response_body_chunk()
				if chunk.is_empty():
					break
				feed_bytes(chunk)
				if not busy:
					break
		HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR, HTTPClient.STATUS_DISCONNECTED:
			_fail("connection")


func feed_bytes(chunk: PackedByteArray) -> void:
	# Decode only whole NDJSON records, so split UTF-8 characters stay intact.
	_buffer.append_array(chunk)
	if _buffer.size() > 131072:
		_fail("invalid_response")
		return
	var newline := _buffer.find(10)
	while newline >= 0 and busy:
		var line := _buffer.slice(0, newline)
		_buffer = _buffer.slice(newline + 1)
		_consume_line(line)
		newline = _buffer.find(10)


func _consume_line(bytes: PackedByteArray) -> void:
	var line := bytes.get_string_from_utf8().strip_edges()
	if line.is_empty():
		return
	var event: Variant = JSON.parse_string(line)
	if not event is Dictionary:
		_fail("invalid_response")
		return
	if event.has("error"):
		_fail(str(event.error))
		return
	var message: Variant = event.get("message", {})
	if message is Dictionary:
		# Deliberate thinking is never displayed as character dialogue.
		var content: String = str(message.get("content", ""))
		if not content.is_empty():
			if _structured:
				_raw_content += content
				var spoken_prefix := _spoken_reply_prefix(_raw_content)
				if spoken_prefix.length() > _reply.length():
					_emit_spoken_text(spoken_prefix.substr(_reply.length()))
			else:
				_emit_spoken_text(content)
	if event.get("done", false):
		var reflection_words: int = 0
		if _structured:
			var result: Variant = JSON.parse_string(_raw_content)
			if not result is Dictionary or not result.get("reply") is String or not result.get("intent") is String:
				_fail("invalid_response")
				return
			_reply = result.reply
			reflection_words = str(result.intent).split(" ", false).size()
		if _reply.strip_edges().is_empty():
			_fail("empty_response")
			return
		var metrics: Dictionary = event.duplicate()
		metrics["first_token_ms"] = _first_token_ms
		metrics["response_ms"] = Time.get_ticks_msec() - _started_ms
		metrics["reflection_words"] = reflection_words
		var reply := _reply.strip_edges()
		cancel()
		completed.emit(reply, metrics)


func _emit_spoken_text(content: String) -> void:
	if _first_token_ms < 0:
		_first_token_ms = Time.get_ticks_msec() - _started_ms
	_reply += content
	token_received.emit(content)


func _spoken_reply_prefix(raw: String) -> String:
	# Extract the growing reply string without displaying the private intent,
	# JSON punctuation, incomplete escape sequences or half a surrogate pair.
	var key := raw.find('"reply"')
	if key < 0:
		return ""
	var colon := raw.find(":", key + 7)
	if colon < 0:
		return ""
	var opening_quote := raw.find('"', colon + 1)
	if opening_quote < 0:
		return ""
	var output := ""
	var index := opening_quote + 1
	var escapes := {'"': '"', "\\": "\\", "/": "/", "n": "\n", "r": "\r", "t": "\t", "b": "\b", "f": "\f"}
	while index < raw.length():
		var character := raw[index]
		if character == '"':
			break
		if character != "\\":
			output += character
			index += 1
			continue
		if index + 1 >= raw.length():
			break
		var escape := raw[index + 1]
		if escape != "u":
			if not escapes.has(escape):
				break
			output += escapes[escape]
			index += 2
			continue
		if index + 6 > raw.length():
			break
		var hex := raw.substr(index + 2, 4)
		if not _is_hex(hex):
			break
		var codepoint := hex.hex_to_int()
		index += 6
		if codepoint >= 0xD800 and codepoint <= 0xDBFF:
			if index + 6 > raw.length() or raw.substr(index, 2) != "\\u":
				break
			var low_hex := raw.substr(index + 2, 4)
			if not _is_hex(low_hex):
				break
			var low := low_hex.hex_to_int()
			if low < 0xDC00 or low > 0xDFFF:
				break
			codepoint = 0x10000 + ((codepoint - 0xD800) << 10) + low - 0xDC00
			index += 6
		elif codepoint >= 0xDC00 and codepoint <= 0xDFFF:
			break
		output += String.chr(codepoint)
	return output


func _is_hex(value: String) -> bool:
	for character: String in value:
		if not character in "0123456789abcdefABCDEF":
			return false
	return value.length() == 4


func _fail(reason: String) -> void:
	cancel()
	failed.emit(reason)


func cancel() -> void:
	busy = false
	_http.close()
	set_process(false)


func _exit_tree() -> void:
	cancel()
