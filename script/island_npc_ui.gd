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


func _ready() -> void:
	add_to_group("island_npc_panels")
	$text_ui.visibility_changed.connect(_position_companion_hint)
	_localize.call_deferred()


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
	var labels := ["respect_text", "frindship_text", "irritation_text", "deal_text"]
	var keys := ["respect", "friendship", "irritation", "deal"]
	var captions := ["Respekt", "Přátelství", "Podráždění", "Ochota k dohodě"] if cz else ["Уважение", "Дружба", "Раздражение", "Сделка"]
	if $relationship.visible:
		for index in labels.size():
			var value: int = Global.get(npc_key + "_" + keys[index])
			$relationship.get_node(labels[index]).text = captions[index]
			$relationship.get_node(labels[index] + "_value").text = str(value)
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
