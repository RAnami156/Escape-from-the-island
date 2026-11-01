extends CanvasLayer
## Presentation only: layout lives in the scene; quest/AI scripts keep their nodes and signals.

@export_enum("bong", "panda", "flycatcher") var npc_key: String = "bong"

const PLACEHOLDERS_RU := {
	"Napiš Kongovi…": "Напиши Конгу…",
	"Vrať se ke Kongovi a napiš mu…": "Вернись к Конгу и напиши ему…",
	"Najdi whisky…": "Найди виски…",
	"Napiš Mucholapce…": "Напиши Мухоловке…",
	"Vrať se k Mucholapce a napiš jí…": "Вернись к Мухоловке и напиши ей…",
	"Chyť mouchu…": "Поймай муху…",
	"Napiš Pandě…": "Напиши Панде…",
	"Najdi knihu a vrať se k Pandě…": "Найди книгу и вернись к Панде…",
	"Panda odpovídá…": "Панда отвечает…",
	"Kniha nalezena! Napiš Pandě…": "Книга найдена! Напиши Панде…",
}

var _language := ""
const RELATIONSHIP_KEYS := ["respect", "friendship", "irritation", "deal"]
const RELATIONSHIP_LABELS := ["respect_text", "frindship_text", "irritation_text", "deal_text"]
const IMPROVED := Color("9acddb")
const WORSENED := Color("e3a18e")
var _last_values: Dictionary = {}
var _change_rows: Array[Control] = []
var _change_tweens: Dictionary = {}


func _ready() -> void:
	add_to_group("island_npc_panels")
	$text_ui.visibility_changed.connect(_position_companion_hint)
	_setup_relationship_changes()
	$relationship.visibility_changed.connect(_reset_relationship_changes)
	_localize.call_deferred()


func _setup_relationship_changes() -> void:
	$relationship/Background.offset_left = -516.0
	$relationship/Heading.offset_left = -492.0
	for index in RELATIONSHIP_KEYS.size():
		var caption: Label = $relationship.get_node(RELATIONSHIP_LABELS[index])
		var value: Label = $relationship.get_node(RELATIONSHIP_LABELS[index] + "_value")
		caption.offset_left = -492.0
		caption.offset_right = -232.0
		value.offset_left = -224.0
		value.offset_right = -144.0
		var change := Control.new()
		change.name = RELATIONSHIP_KEYS[index] + "_change"
		change.mouse_filter = Control.MOUSE_FILTER_IGNORE
		change.anchor_left = 1.0
		change.anchor_right = 1.0
		change.offset_left = -136.0
		change.offset_right = -44.0
		change.offset_top = caption.offset_top
		change.offset_bottom = caption.offset_bottom
		change.modulate.a = 0.0
		$relationship.add_child(change)
		var arrow := Control.new()
		arrow.set_script(preload("res://script/relationship_arrow.gd"))
		arrow.name = "Arrow"
		arrow.size = Vector2(24, 28)
		change.add_child(arrow)
		var amount := Label.new()
		amount.name = "Amount"
		amount.position = Vector2(30, 0)
		amount.size = Vector2(62, 32)
		amount.theme = value.theme
		amount.add_theme_font_size_override("font_size", 20)
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		change.add_child(amount)
		_change_rows.append(change)
	_reset_relationship_changes()


func _reset_relationship_changes() -> void:
	for index in RELATIONSHIP_KEYS.size():
		var key: String = RELATIONSHIP_KEYS[index]
		_last_values[key] = Global.get(npc_key + "_" + key)
		if _change_tweens.has(key):
			_change_tweens[key].kill()
		_change_rows[index].modulate.a = 0.0
		$relationship.get_node(RELATIONSHIP_LABELS[index] + "_value").modulate = Color.WHITE


func _show_relationship_change(index: int, difference: int) -> void:
	var key: String = RELATIONSHIP_KEYS[index]
	if _change_tweens.has(key):
		_change_tweens[key].kill()
	var change := _change_rows[index]
	var arrow := change.get_node("Arrow") as Control
	var amount := change.get_node("Amount") as Label
	var value := $relationship.get_node(RELATIONSHIP_LABELS[index] + "_value") as Label
	var positive := difference > 0 if key != "irritation" else difference < 0
	var tint := IMPROVED if positive else WORSENED
	arrow.set("direction", 1 if difference > 0 else -1)
	arrow.queue_redraw()
	amount.text = "%+d" % difference
	amount.add_theme_color_override("font_color", tint)
	arrow.modulate = tint
	value.modulate = tint
	change.modulate.a = 0.0
	arrow.position.y = 5.0 if difference > 0 else -5.0
	var animation := create_tween()
	_change_tweens[key] = animation
	animation.set_parallel(true)
	animation.tween_property(change, "modulate:a", 1.0, 0.14)
	animation.tween_property(arrow, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animation.tween_property(value, "modulate", Color.WHITE, 0.45).set_delay(0.75)
	animation.tween_property(change, "modulate:a", 0.0, 0.5).set_delay(2.6)


func _position_companion_hint() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var talk := scene.get_node_or_null("guide_npc/Dialogue/Talk") as Button
	if talk == null:
		return
	var dialogue_open := false
	for ui: Node in get_tree().get_nodes_in_group("island_npc_panels"):
		if ui.get_node("text_ui").is_visible_in_tree():
			dialogue_open = true
			break
	talk.offset_top = -338.0 if dialogue_open else -76.0
	talk.offset_bottom = -286.0 if dialogue_open else -24.0


func _process(_delta: float) -> void:
	if _language != Global.language:
		_localize()
	var cz := Global.language == "cz"
	var captions := ["Respekt", "Přátelství", "Podráždění", "Ochota k dohodě"] if cz else ["Уважение", "Дружба", "Раздражение", "Сделка"]
	for index in RELATIONSHIP_KEYS.size():
		var key: String = RELATIONSHIP_KEYS[index]
		var value: int = Global.get(npc_key + "_" + key)
		var previous: int = _last_values.get(key, value)
		_last_values[key] = value
		if $relationship.visible:
			$relationship.get_node(RELATIONSHIP_LABELS[index]).text = captions[index]
			$relationship.get_node(RELATIONSHIP_LABELS[index] + "_value").text = str(value)
			if value != previous:
				_show_relationship_change(index, value - previous)
	var input: LineEdit = $text_ui/LineEdit
	if not cz and PLACEHOLDERS_RU.has(input.placeholder_text):
		input.placeholder_text = PLACEHOLDERS_RU[input.placeholder_text]
	_update_response_time(cz)


func _update_response_time(czech: bool) -> void:
	var label := $text_ui/ResponseTime as Label
	var timing: Dictionary = get_parent().get_meta("response_timing", {})
	if timing.is_empty():
		label.text = "Odpověď: —" if czech else "Ответ: —"
		return
	var running: bool = timing.state == "running"
	var elapsed: int = Time.get_ticks_msec() - int(timing.started_ms) if running else int(timing.elapsed_ms)
	var caption := "Generování" if czech else "Генерация"
	if not running:
		caption = ("Chyba" if czech else "Ошибка") if timing.state == "error" else ("Odpověď" if czech else "Ответ")
	var seconds := ("%.2f" % (maxi(0, elapsed) / 1000.0)).replace(".", ",")
	label.text = "%s: %s %s" % [caption, seconds, "s" if czech else "с"]
	label.modulate.a = 1.0 if running else 0.72


func _localize() -> void:
	_language = Global.language
	var cz := _language == "cz"
	var names := {
		"bong": "Baron Kong" if cz else "Барон Конг",
		"panda": "Panda" if cz else "Панда",
		"flycatcher": "Mucholapka" if cz else "Мухоловка",
	}
	$text_ui/Name.text = names[npc_key]
	$text_ui/EnterHint.text = "Enter — odeslat" if cz else "Enter — отправить"
	$relationship/Heading.text = "Vztahy" if cz else "Отношения"
	$text_ui/button_next.tooltip_text = "Další replika" if cz else "Следующая реплика"
	$text_ui.get_node("button_>back").tooltip_text = "Předchozí replika" if cz else "Предыдущая реплика"
