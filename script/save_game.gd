extends Node
## One local slot. Only durable gameplay state is stored; requests and UI locks are not.

signal status_changed(message: String)

const MAIN_SCENE := "res://scene/main.tscn"
const SAVE_VERSION := 1
const AUTOSAVE_SECONDS := 60.0
const GLOBAL_FIELDS := [
	"bong_respect", "bong_friendship", "bong_irritation", "bong_deal", "whiskey", "helm",
	"flycatcher_respect", "flycatcher_friendship", "flycatcher_irritation", "flycatcher_deal", "fly", "parus",
	"panda_respect", "panda_friendship", "panda_irritation", "panda_deal", "book", "bamboo_boards",
]
const NPC_FIELDS := [
	"current_phase", "request_phase", "phase_1_message_count", "phase_3_message_count",
	"quest_location", "quest_location_type", "escape_question_asked", "player_wants_escape",
	"quest_was_given", "quest_reward_given", "phase_3_question", "selected_question",
	"previous_question_index", "conversation_history", "dialogue_history", "dialogue_history_index",
	"last_relationship_delta", "last_humor_score", "last_humor_reason",
]
const GUIDE_FIELDS := [
	"current_phase", "player_name", "conversation_history", "_has_met_player", "_introduction_started",
	"_last_observation", "_last_observation_zone", "_last_zone_lines", "_zone_cooldowns",
]
const QUEST_ITEMS := {
	"bong": ["whiskey", "whiskey_instance", "spawn_whiskey"],
	"flycather": ["fly", "fly_instance", "spawn_fly"],
	"panda": ["book", "book_instance", "spawn_book"],
}

# Tests override this with an isolated user:// directory, never the player's slot.
var save_path := "user://saves/island.json"
var last_error := ""
var _pending: Dictionary = {}
var _autosave_left := AUTOSAVE_SECONDS
var _transitioning := false
var _quit_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false


func is_in_game() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == MAIN_SCENE and is_instance_valid(Global.player)


func _process(delta: float) -> void:
	if not is_in_game() or _transitioning:
		return
	if _quit_pending:
		if can_save():
			if save_game():
				get_tree().quit()
			else:
				_quit_pending = false
		return
	if get_tree().paused:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_SECONDS if save_game(false) else 1.0


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if not is_in_game():
		get_tree().quit()
	elif can_save():
		if save_game():
			get_tree().quit()
	else:
		# Finish the active reply before writing its quest transition and closing.
		_quit_pending = true
		get_tree().paused = false
		status_changed.emit(_t("Завершаю ответ и сохраняю…", "Dokončuji odpověď a ukládám…"))


func _unhandled_input(event: InputEvent) -> void:
	if not is_in_game() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		save_game()
	elif event.physical_keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		load_game()


func can_save() -> bool:
	if not is_in_game() or _transitioning:
		return false
	var scene := get_tree().current_scene
	if scene.get_node("ship").leaving:
		return false
	for path: String in QUEST_ITEMS:
		var npc := scene.get_node(path)
		if npc.get("waiting_for_response") or npc.get("is_typing"):
			return false
	var guide := scene.get_node("guide_npc")
	return not guide._client.busy


func has_save() -> bool:
	return not _read_slot().is_empty()


func save_game(announce: bool = true) -> bool:
	if not can_save():
		return _fail(_t("Дождись окончания ответа NPC.", "Počkej na dokončení odpovědi NPC."), announce)
	var scene := get_tree().current_scene
	var data := {
		"version": SAVE_VERSION, "saved_at": Time.get_datetime_string_from_system(),
		"language": Global.language, "advanced_settings": Global.advanced_settings_enabled,
		"player": {"position": _position(Global.player), "direction": Global.player.last_direction},
		"globals": _capture_fields(Global, GLOBAL_FIELDS), "npcs": {},
		"ship": _capture_fields(scene.get_node("ship"), ["helm_repaired", "sail_repaired", "planks_repaired"]),
		"guide": {"position": _position(scene.get_node("guide_npc")), "state": _capture_fields(scene.get_node("guide_npc"), GUIDE_FIELDS)},
	}
	for path: String in QUEST_ITEMS:
		var npc := scene.get_node(path)
		data.npcs[path] = _capture_fields(npc, NPC_FIELDS)
	var directory := ProjectSettings.globalize_path(save_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return _fail(_t("Не удалось создать папку сохранений.", "Nelze vytvořit složku pro uložení."), announce)
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail(_t("Не удалось записать сохранение.", "Hru se nepodařilo uložit."), announce)
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _fail(_t("Ошибка записи сохранения.", "Chyba zápisu uložené hry."), announce)
	# Keep the last valid slot when replacing a damaged file or interrupted write.
	if not _read_file(save_path).is_empty():
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			return _fail(_t("Не удалось создать резервную копию.", "Nelze vytvořit záložní kopii."), announce)
	if DirAccess.rename_absolute(temporary, save_path) != OK:
		return _fail(_t("Не удалось обновить сохранение.", "Uloženou hru se nepodařilo aktualizovat."), announce)
	last_error = ""
	_autosave_left = AUTOSAVE_SECONDS
	status_changed.emit(_t("Игра сохранена", "Hra uložena"))
	return true


func load_game() -> bool:
	if _transitioning:
		return false
	var data := _read_slot()
	if data.is_empty():
		return _fail(_t("Нет исправного сохранения.", "Není k dispozici platná uložená hra."))
	_transitioning = true
	_pending = data
	var old_language := Global.language
	var old_advanced := Global.advanced_settings_enabled
	# Main selects the RU/CZ NPC scripts in _enter_tree, before their _ready.
	Global.language = data.language
	Global.advanced_settings_enabled = data.advanced_settings
	var error := get_tree().change_scene_to_file(MAIN_SCENE)
	if error != OK:
		Global.language = old_language
		Global.advanced_settings_enabled = old_advanced
		_pending.clear()
		_transitioning = false
		return _fail(_t("Не удалось открыть остров.", "Ostrov se nepodařilo načíst."))
	get_tree().paused = false
	return true


func new_game() -> void:
	_pending.clear()
	_reset_globals()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/start.tscn")


func prepare_main() -> void:
	# Direct F6 runs also start clean; loading restores only after all children are ready.
	_reset_globals()


func restore_main(scene: Node) -> void:
	if _pending.is_empty():
		_autosave_left = 2.0
		return
	var data := _pending
	_pending = {}
	_restore_fields(Global, data.globals, GLOBAL_FIELDS)
	Global.player_position = _vector(data.player.position)
	Global.player.last_direction = data.player.direction
	Global.player.update_animation(Vector2.ZERO, false)
	for path: String in QUEST_ITEMS:
		var npc := scene.get_node(path)
		_restore_fields(npc, data.npcs[path], NPC_FIELDS)
		if npc.has_method("show_dialogue_history"):
			npc.show_dialogue_history()
		var item: Array = QUEST_ITEMS[path]
		# Recreate only an outstanding item, at the NPC's original authored coordinates.
		if npc.quest_was_given and not npc.quest_reward_given and not Global.get(item[0]):
			npc.call(item[2])
	var ship := scene.get_node("ship")
	_restore_fields(ship, data.ship, ["helm_repaired", "sail_repaired", "planks_repaired"])
	ship.helm_anim.visible = ship.helm_repaired
	ship.sail_anim.visible = ship.sail_repaired
	if ship.helm_repaired:
		ship.helm_anim.play("default")
	if ship.sail_repaired:
		ship.sail_anim.play("default")
	ship.planks_anim.play("fixed" if ship.planks_repaired else "default")
	ship.check_ship()
	var guide := scene.get_node("guide_npc")
	_restore_fields(guide, data.guide.state, GUIDE_FIELDS)
	guide.global_position = _vector(data.guide.position)
	guide._trail.clear()
	guide._refresh_transcript()
	Global.player_can_move = true
	_transitioning = false
	_autosave_left = AUTOSAVE_SECONDS
	status_changed.emit(_t("Сохранение загружено", "Uložená hra načtena"))


func _reset_globals() -> void:
	var defaults: Node = Global.get_script().new()
	for field: String in GLOBAL_FIELDS:
		Global.set(field, defaults.get(field))
	defaults.free()
	Global.player_can_move = true


func _capture_fields(node: Node, fields: Array) -> Dictionary:
	var result := {}
	var properties := _properties(node)
	for field: String in fields:
		if properties.has(field):
			result[field] = node.get(field)
	return result.duplicate(true)


func _restore_fields(node: Node, data: Dictionary, fields: Array) -> void:
	var properties := _properties(node)
	for field: String in fields:
		if not data.has(field) or not properties.has(field):
			continue
		var current: Variant = node.get(field)
		if current is Array:
			# assign preserves Array[Dictionary] rather than setting an untyped JSON array.
			current.assign(data[field])
		elif typeof(current) == TYPE_INT:
			node.set(field, int(data[field]))
		else:
			node.set(field, data[field])


func _properties(node: Node) -> Dictionary:
	var result := {}
	for property: Dictionary in node.get_property_list():
		result[property.name] = true
	return result


func _read_slot() -> Dictionary:
	var data := _read_file(save_path)
	return data if not data.is_empty() else _read_file(save_path + ".bak")


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4 * 1024 * 1024:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not _valid_save(json.data):
		return {}
	return json.data


func _valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != SAVE_VERSION:
		return false
	if data.get("language") not in ["ru", "cz"] or not data.get("advanced_settings") is bool:
		return false
	for key: String in ["player", "globals", "npcs", "ship", "guide"]:
		if not data.get(key) is Dictionary:
			return false
	if not _valid_position(data.player.get("position")) or data.player.get("direction") not in ["down", "top", "left", "rigth"]:
		return false
	for field: String in GLOBAL_FIELDS:
		var default: Variant = Global.get(field)
		if not _same_type(data.globals.get(field), default):
			return false
	for field: String in ["helm_repaired", "sail_repaired", "planks_repaired"]:
		if not data.ship.get(field) is bool:
			return false
	if not _valid_position(data.guide.get("position")) or not data.guide.get("state") is Dictionary:
		return false
	for path: String in QUEST_ITEMS:
		if not data.npcs.get(path) is Dictionary:
			return false
		var script_path: String = "res://script/NPC.cz/bong_CZ.gd" if path == "bong" else "res://script/NPC.cz/npc_flycatcher_ollama_CZ.gd"
		if path == "panda":
			script_path = "res://script/NPC.cz/npc_panda_ollama_CZ.gd"
		if data.language == "ru":
			script_path = {"bong": "res://script/NPC.ru/bong.gd", "flycather": "res://script/NPC.ru/npc_flycatcher_ollama_ru.gd", "panda": "res://script/NPC.ru/npc_panda_ollama_ru.gd"}[path]
		if not _valid_fields(data.npcs[path], load(script_path), NPC_FIELDS):
			return false
		if int(data.npcs[path].get("current_phase", -1)) not in range(7):
			return false
		if int(data.npcs[path].get("quest_location_type", -1)) not in range(2 if path == "panda" else 3):
			return false
	return _valid_fields(data.guide.state, load("res://guide_npc.gd"), GUIDE_FIELDS)


func _valid_fields(data: Dictionary, script: Script, fields: Array) -> bool:
	for property: Dictionary in script.get_script_property_list():
		var field: String = property.name
		if field in fields:
			if not data.has(field) or not _matches_type(data[field], property.type):
				return false
	return true


func _same_type(value: Variant, default: Variant) -> bool:
	return _matches_type(value, typeof(default))


func _matches_type(value: Variant, expected_type: int) -> bool:
	if expected_type == TYPE_INT:
		return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))
	if typeof(value) != expected_type:
		return false
	if value is Array:
		for entry: Variant in value:
			if not entry is Dictionary:
				return false
	return true


func _valid_position(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)):
			return false
	return true


func _position(node: Node2D) -> Array:
	return [node.global_position.x, node.global_position.y]


func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _fail(message: String, announce: bool = true) -> bool:
	last_error = message
	if announce:
		status_changed.emit(message)
	return false


func _t(ru: String, cz: String) -> String:
	return cz if Global.language == "cz" else ru
