extends Control
## Plain game UI, drawn with basic shapes and the project's existing font.

const TEXT := Color("eeeeee")
const MUTED := Color("b8b8b8")
const GREEN := Color("61965b")
const RED := Color("cc6252")

var font: Font
@onready var quest: Node2D = get_parent().get_parent()


func _ready() -> void:
	font = load("res://asets/1 Minecraft-Regular.otf")


func _draw() -> void:
	if font == null:
		return
	var scale_factor := minf(size.x / 1920.0, size.y / 1080.0)
	if scale_factor <= 0.0:
		return
	var extent := size / scale_factor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	if quest.active:
		_draw_lock(extent)
	else:
		if Global.compass_found:
			_draw_compass(extent)
		if quest.can_interact() and not Global.compass_found:
			var message := _t("E — Открыть ящик", "E — Otevřít bednu")
			if Global.compass_chest_opened:
				message = _t("E — Взять компас", "E — Vzít kompas") if quest.reveal_left <= 0.0 else _t("Внутри компас", "Uvnitř je kompas")
			_prompt(extent, message)
		if quest.toast_left > 0.0:
			_prompt(extent, _t("Иди по стрелке. Зелёная — приближаешься к Конгу.", "Jdi za šipkou. Zelená = blížíš se ke Kongovi."))


func _draw_lock(extent: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, extent), Color(0, 0, 0, 0.45))
	var origin := (extent - Vector2(700, 320)) / 2.0
	_box(Rect2(origin, Vector2(700, 320)))
	_text(origin + Vector2(24, 39), _t("Ящик", "Bedna"), 26)
	_text(origin + Vector2(24, 78), _t("Попади в зелёное поле два раза.", "Tref zelené pole dvakrát."), 22)
	_text(origin + Vector2(24, 111), _t("Защёлки: ", "Západky: ") + "%d / 2" % quest.hits, 20, MUTED)
	var bar := Rect2(origin + Vector2(25, 148), Vector2(650, 36))
	draw_rect(bar, Color("555555"))
	var zone := Rect2(bar.position + Vector2((quest.target_center - quest.TARGET_WIDTH / 2.0) * bar.size.x, 0), Vector2(quest.TARGET_WIDTH * bar.size.x, bar.size.y))
	draw_rect(zone, GREEN)
	draw_rect(bar, MUTED, false, 2)
	var cursor_x: float = bar.position.x + quest.cursor * bar.size.x
	var needle := TEXT
	if quest.feedback_left > 0.0 and quest.cooldown > 0.0:
		needle = GREEN if quest.feedback_good else RED
	draw_line(Vector2(cursor_x, bar.position.y - 11), Vector2(cursor_x, bar.end.y + 6), needle, 3)
	draw_line(Vector2(cursor_x - 6, bar.position.y - 16), Vector2(cursor_x, bar.position.y - 10), needle, 3)
	draw_line(Vector2(cursor_x + 6, bar.position.y - 16), Vector2(cursor_x, bar.position.y - 10), needle, 3)
	if quest.feedback_left > 0.0:
		var message := _t("Есть!", "Zásah!") if quest.feedback_good else _t("Мимо. Ещё раз.", "Vedle. Zkus znovu.")
		_text(origin + Vector2(24, 222), message, 21, TEXT if quest.feedback_good else RED)
	_text(origin + Vector2(24, 266), _t("E / Пробел — остановить", "E / Mezerník — zastavit"), 22)
	_text(origin + Vector2(24, 298), _t("Esc — закрыть", "Esc — zavřít"), 19, MUTED)


func _draw_compass(extent: Vector2) -> void:
	var origin := Vector2(extent.x - 202, 22)
	if quest.target_offset().length() < 110.0:
		# Leave the NPC relationship panel above this arrival message readable.
		origin.y = 310
		_box(Rect2(origin, Vector2(180, 106)))
		_text(origin + Vector2(16, 38), _t("Вы находитесь", "Nacházíte se"), 20)
		_text(origin + Vector2(16, 75), _t("у Конга", "u Konga"), 22)
		return
	_box(Rect2(origin, Vector2(180, 202)))
	_text(origin + Vector2(16, 30), _t("Компас", "Kompas"), 22)
	var center := origin + Vector2(90, 103)
	# Slightly uneven straight segments, rather than an instrument face.
	var rim := PackedVector2Array([
		Vector2(-3, -50), Vector2(28, -42), Vector2(47, -19),
		Vector2(49, 15), Vector2(30, 42), Vector2(-2, 49),
		Vector2(-34, 39), Vector2(-49, 10), Vector2(-46, -23),
		Vector2(-28, -44), Vector2(-3, -50),
	])
	for index in rim.size():
		rim[index] += center
	draw_polyline(rim, MUTED, 2)
	for cardinal: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + cardinal * 42, center + cardinal * 48, MUTED, 2)
	var axis := Vector2.from_angle(quest.compass_angle)
	var tip := center + axis * 37
	var approaching: bool = quest.moving_toward_kong()
	var needle := GREEN if approaching else RED
	draw_line(center - axis * 15, center, MUTED, 3)
	draw_line(center, tip, needle, 4)
	draw_line(tip, tip - axis * 12 + axis.orthogonal() * 6, needle, 3)
	draw_line(tip, tip - axis * 12 - axis.orthogonal() * 6, needle, 3)
	draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 4)), TEXT)
	var hint := _t("К Конгу", "Ke Kongovi") if approaching else _t("Иди по стрелке", "Jdi za šipkou")
	_text(origin + Vector2(16, 185), hint, 17, MUTED)


func _prompt(extent: Vector2, message: String) -> void:
	var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 30
	var origin := Vector2((extent.x - width) / 2.0, extent.y - 100)
	_box(Rect2(origin, Vector2(width, 46)))
	_text(origin + Vector2(15, 30), message, 22)


func _box(rect: Rect2) -> void:
	draw_rect(rect, Color(0.15, 0.15, 0.15, 0.96))
	draw_rect(rect, Color("929292"), false, 2)


func _text(at: Vector2, message: String, font_size: int, color: Color = TEXT) -> void:
	draw_string(font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _t(ru: String, cz: String) -> String:
	return cz if Global.language == "cz" else ru
