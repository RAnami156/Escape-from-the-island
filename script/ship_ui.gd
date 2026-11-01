extends CanvasLayer
## Display only: repair areas, inventory consumption and endings stay in ship_cz.gd.

const PARTS := ["helm", "sail", "planks"]
const INVENTORY := ["helm", "parus", "bamboo_boards"]
const MUTED := Color("929fA7")
const READY := Color("9acddb")
const SAND := Color("e3cea3")
const INK := Color("f3eee3")

@onready var ship: Node2D = get_parent()
@onready var panel: PanelContainer = $Panel
@onready var content: VBoxContainer = $Panel/Content
var _open := false
var _visibility_tween: Tween


func _ready() -> void:
	# Preserve the legacy nodes/visibility flags used by the gameplay script,
	# while their screen-space replacements stay readable at every camera zoom.
	for path: NodePath in [^"helm/helm_text", ^"sail/sail_text", ^"planks/planks_text", ^"final_text"]:
		ship.get_node(path).modulate.a = 0.0
	panel.hide()
	panel.modulate.a = 0.0
	_refresh()


func _process(_delta: float) -> void:
	_refresh()
	_set_open(ship.is_player_near_ship() and not ship.leaving)


func _set_open(value: bool) -> void:
	if value == _open:
		return
	_open = value
	if _visibility_tween != null:
		_visibility_tween.kill()
	_visibility_tween = create_tween()
	if value:
		panel.show()
		_visibility_tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	else:
		_visibility_tween.tween_property(panel, "modulate:a", 0.0, 0.12)
		_visibility_tween.tween_callback(panel.hide)


func _refresh() -> void:
	var repaired := int(ship.helm_repaired) + int(ship.sail_repaired) + int(ship.planks_repaired)
	content.get_node("Header/Title").text = _t("Ремонт лодки", "Oprava lodi")
	content.get_node("Header/Count").text = "%d / 3" % repaired
	var active := -1
	for index in PARTS.size():
		if active == -1 and ship.get(PARTS[index]) and not ship.get(PARTS[index] + "_repaired"):
			active = index # Match try_repair's exact priority, including a missing part.
	for index in PARTS.size():
		var row := content.get_node("Parts/" + PARTS[index])
		var done: bool = ship.get(PARTS[index] + "_repaired")
		var available: bool = Global.get(INVENTORY[index])
		row.get_node("Name").text = [_t("Штурвал", "Kormidlo"), _t("Парус", "Plachta"), _t("Корпус", "Trup")][index]
		row.get_node("Name").modulate = INK if active == index else MUTED
		row.get_node("Marker").color = SAND if active == index else Color.TRANSPARENT
		row.get_node("State").text = _t("Установлено", "Opraveno") if done else (_t("Есть деталь", "Připraveno") if available else _t("Нет детали", "Chybí díl"))
		row.get_node("State").modulate = SAND if done else (READY if available else MUTED)
		content.get_node("Progress/Step%d" % index).color = SAND if done else Color(1, 1, 1, 0.12)
	var action := content.get_node("Action/Text") as Label
	var key := content.get_node("Action/Key") as Label
	if ship.ship_ready:
		content.get_node("Subtitle").text = _t("Лодка готова к отплытию", "Loď je připravená vyplout")
		action.text = _t("Отплыть с острова", "Odplout z ostrova")
		key.modulate = SAND
	elif active >= 0:
		content.get_node("Subtitle").text = _t("Детали для выхода в море", "Díly potřebné k vyplutí")
		var available: bool = Global.get(INVENTORY[active])
		if available:
			action.text = [_t("Установить штурвал", "Nasadit kormidlo"), _t("Установить парус", "Nasadit plachtu"), _t("Починить корпус", "Opravit trup")][active]
		else:
			action.text = [_t("Нужен штурвал", "Chybí kormidlo"), _t("Нужен парус", "Chybí plachta"), _t("Нужны бамбуковые доски", "Chybí bambusová prkna")][active]
		key.modulate = SAND if available else MUTED
	else:
		content.get_node("Subtitle").text = _t("Детали для выхода в море", "Díly potřebné k vyplutí")
		action.text = _t("Подойди к нужной части лодки", "Přistup k části, kterou chceš opravit")
		key.modulate = MUTED


func _t(ru: String, cz: String) -> String:
	return cz if Global.language == "cz" else ru
